/**
 * Mi Recibo — Notificaciones per-user (prioridad vencimientos, FIX TZ)
 * - 8:00 AM: vencido > venceHoy > venceManana > venceEn2Dias (por usuario)
 * - 9:00 AM: diaria SOLO si ese usuario no tiene nada por vencer (ni recibió a las 8)
 * - Candado por usuario (1 push por usuario/día)
 * - /test respeta la prioridad (no cruza diaria si hay vencidos)
 * - TZ: America/Santo_Domingo | dryRun NO bloquea
 * - FIX: clasificación de fechas por YYYYMMDD en la TZ (sin cálculos de medianoche erróneos)
 */

const admin = require("firebase-admin");
try { admin.app(); } catch { admin.initializeApp(); }

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest }  = require("firebase-functions/v2/https");

const TZ = "America/Santo_Domingo";
const VENC_CRON  = "0 8 * * *"; // 8:00 AM
const DAILY_CRON = "0 9 * * *"; // 9:00 AM

const db = admin.firestore();

// ===== Ajusta si tu esquema difiere =====
const CLIENTS_SUBCOL = "clientes";
const CLIENT_DUE_FIELD = "venceEl"; // <— si tu campo se llama distinto, cambia esta línea

// ===== Helpers robustos de fecha por zona (YYYYMMDD) =====
function ymdNumberInTZ(date, tz = TZ) {
  // 'en-CA' => 'YYYY-MM-DD'
  const s = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(date); // "YYYY-MM-DD"
  return Number(s.replaceAll("-", "")); // YYYYMMDD como número
}

function todayYMD(tz = TZ) {
  return ymdNumberInTZ(new Date(), tz);
}
function plusDaysYMD(days, tz = TZ) {
  const now = new Date();
  return ymdNumberInTZ(new Date(now.getTime() + days * 86400000), tz);
}

// ===== Templates =====
function pickFromArrayByYMD(arr, ymd) {
  if (!Array.isArray(arr) || arr.length === 0) return null;
  const idx = ymd % arr.length;
  return (arr[idx] || "").toString().trim() || null;
}

async function getDailyMessage() {
  const snap = await db.collection("config").doc("(default)")
    .collection("push_templates").doc("diarias").get();
  const mensajes = ((snap.data() || {}).mensajes || [])
    .filter(s => typeof s === "string" && s.trim());
  return pickFromArrayByYMD(mensajes, todayYMD());
}

async function getVencMessage(kind /* vencido | venceHoy | venceManana | venceEn2Dias */) {
  // Alineado a tu Firestore: doc = "vencido"
  const snap = await db.collection("config").doc("(default)")
    .collection("push_templates").doc("vencido").get();
  const data = snap.data() || {};
  const arr = Array.isArray(data[kind]) ? data[kind] : [];
  return pickFromArrayByYMD(arr, todayYMD());
}

// ===== Candado por usuario =====
async function getUserLock(uid) {
  const ref = db.collection("config").doc("(default)")
    .collection("push_state_users").doc(uid);
  const s = await ref.get();
  return s.exists ? (s.data() || {}) : null;
}
async function setUserLock(uid, source) {
  const ref = db.collection("config").doc("(default)")
    .collection("push_state_users").doc(uid);
  await ref.set({
    yyyymmdd: String(todayYMD()),
    source,
    ts: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

// ===== Tokens =====
async function getAllUsersWithToken() {
  const qs = await db.collection("prestamistas").get();
  const out = [];
  qs.forEach(doc => {
    const meta = (doc.data() || {}).meta || {};
    const t = typeof meta.fcmToken === "string" ? meta.fcmToken.trim() : "";
    if (t) out.push({ uid: doc.id, token: t });
  });
  return out;
}

// ===== Clasificación de vencimientos por usuario (por YYYYMMDD TZ) =====
function toJSDate(v) { return v?.toDate ? v.toDate() : (v instanceof Date ? v : null); }

async function getUserDueCategory(uid) {
  const qs = await db.collection("prestamistas").doc(uid).collection(CLIENTS_SUBCOL).get();

  const today = todayYMD();            // YYYYMMDD hoy en TZ
  const tomorrow = plusDaysYMD(1);     // YYYYMMDD mañana en TZ
  const in2days  = plusDaysYMD(2);     // YYYYMMDD en 2 días en TZ

  let hasVencido = false, hasHoy = false, hasManana = false, hasEn2 = false;

  qs.forEach(doc => {
    const raw = (doc.data() || {})[CLIENT_DUE_FIELD];
    const d = toJSDate(raw);
    if (!d) return; // ignora faltantes o formatos no fecha

    const dueYMD = ymdNumberInTZ(d, TZ);

    if (dueYMD < today) { hasVencido = true; return; }
    if (dueYMD === today) { hasHoy = true; return; }
    if (dueYMD === tomorrow) { hasManana = true; return; }
    if (dueYMD === in2days) { hasEn2 = true; return; }
  });

  if (hasVencido) return "vencido";
  if (hasHoy)     return "venceHoy";
  if (hasManana)  return "venceManana";
  if (hasEn2)     return "venceEn2Dias";
  return null;
}

// ===== Envío =====
async function sendToToken(token, payload) {
  const res = await admin.messaging().sendEachForMulticast({ tokens: [token], ...payload });
  return { sent: res.successCount, failed: res.failureCount };
}

// ===== CRON JOBS =====

// 8:00 — VENCIMIENTOS (por usuario)
exports.enviarNotificacionesVencimiento = onSchedule(
  { schedule: VENC_CRON, timeZone: TZ },
  async () => {
    const users = await getAllUsersWithToken();
    for (const { uid, token } of users) {
      const lock = await getUserLock(uid);
      if (lock && lock.yyyymmdd === String(todayYMD())) continue;

      const kind = await getUserDueCategory(uid);
      if (!kind) continue;

      const body = await getVencMessage(kind);
      if (!body) continue;

      const payload = { notification: { title: "Mi Recibo", body }, data: { type: "vencimiento", kind } };
      const r = await sendToToken(token, payload);
      if (r.sent > 0) await setUserLock(uid, "vencimiento");
    }
  }
);

// 9:00 — DIARIA (solo si NO tuvo vencimientos ni tiene due hoy/mañana/en 2 días)
exports.enviarNotificacionesDiarias = onSchedule(
  { schedule: DAILY_CRON, timeZone: TZ },
  async () => {
    const users = await getAllUsersWithToken();
    const body = await getDailyMessage();
    if (!body) return;

    const payload = { notification: { title: "Mi Recibo", body }, data: { type: "daily" } };

    for (const { uid, token } of users) {
      const lock = await getUserLock(uid);
      if (lock && lock.yyyymmdd === String(todayYMD())) continue; // ya recibió algo hoy

      // Evita cruce: si hoy tiene algo por vencer (hoy/mañana/en 2d o vencido), NO mandar diaria
      const kind = await getUserDueCategory(uid);
      if (kind) continue;

      const r = await sendToToken(token, payload);
      if (r.sent > 0) await setUserLock(uid, "diaria");
    }
  }
);

// ===== Endpoint de prueba =====
// GET /test?mode=diaria|vencimiento[&uid=...][&dry=1]
exports.test = onRequest(async (req, res) => {
  try {
    const mode = (req.query.mode || "diaria").toString();
    const dry  = !!req.query.dry;
    const onlyUid = req.query.uid ? req.query.uid.toString() : null;

    const all = await getAllUsersWithToken();
    const users = onlyUid ? all.filter(u => u.uid === onlyUid) : all;
    const out = [];

    if (mode === "vencimiento") {
      for (const { uid, token } of users) {
        const lock = await getUserLock(uid);
        if (lock && lock.yyyymmdd === String(todayYMD())) { out.push({ uid, sent: 0, failed: 0, reason: "locked" }); continue; }

        const kind = await getUserDueCategory(uid);
        if (!kind) { out.push({ uid, sent: 0, failed: 0, reason: "no-due" }); continue; }

        const body = await getVencMessage(kind);
        if (!body) { out.push({ uid, sent: 0, failed: 0, reason: "no-template" }); continue; }

        if (dry) { out.push({ uid, sent: 0, failed: 0, reason: "dryrun", kind }); continue; }

        const payload = { notification: { title: "Mi Recibo", body }, data: { type: "vencimiento", kind } };
        const r = await sendToToken(token, payload);
        if (r.sent > 0) await setUserLock(uid, "vencimiento");
        out.push({ uid, ...r, kind });
      }
    } else {
      const body = await getDailyMessage();
      if (!body) { res.status(200).json({ ok: true, mode, reason: "no-template" }); return; }

      for (const { uid, token } of users) {
        const lock = await getUserLock(uid);
        if (lock && lock.yyyymmdd === String(todayYMD())) { out.push({ uid, sent: 0, failed: 0, reason: "locked" }); continue; }

        // Evita cruce también en pruebas: si tiene due (vencido/hoy/mañana/2d), NO mandar diaria
        const kind = await getUserDueCategory(uid);
        if (kind) { out.push({ uid, sent: 0, failed: 0, reason: "has-due", kind }); continue; }

        if (dry) { out.push({ uid, sent: 0, failed: 0, reason: "dryrun" }); continue; }

        const payload = { notification: { title: "Mi Recibo", body }, data: { type: "daily" } };
        const r = await sendToToken(token, payload);
        if (r.sent > 0) await setUserLock(uid, "diaria");
        out.push({ uid, ...r });
      }
    }

    res.status(200).json({ ok: true, mode, results: out });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: String(e) });
  }
});

exports.ping = onRequest((_, res) => res.send("OK"));
