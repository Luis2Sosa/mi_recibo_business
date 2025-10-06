/**
 * Mi Recibo — Push por HORA LOCAL del usuario (multipaís) SIN plugins en app
 * - Tick: cada 5 min (UTC) → por usuario decide si es 08:00 ó 09:00 con utcOffsetMin
 * - 08:00 local: vencido > hoy > mañana > en 2 días (candado por usuario/slot)
 * - 09:00 local: diaria SOLO si no tuvo/ni tiene vencimientos (prioridad intacta)
 * - Zona por usuario: prestamistas/{uid}/meta.utcOffsetMin (ej: -240 = UTC-4)
 * - Plantillas: config/(default)/push_templates/{diarias|vencido}
 *   - "vencido": { vencido:[], venceHoy:[], venceManana:[], venceEn2Dias:[] }
 *   - "diarias": { mensajes:[] }
 */

const admin = require("firebase-admin");
try { admin.app(); } catch { admin.initializeApp(); }

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest }  = require("firebase-functions/v2/https");

const TICK_CRON = "*/5 * * * *"; // cada 5 min (UTC)
const DEFAULT_OFFSET_MIN = -240; // UTC-4 (RD) si el usuario aún no envía offset
const db = admin.firestore();

/* ====================== Helpers por OFFSET ====================== */

// Lee offset del usuario; si no hay, fallback
function getUserOffsetMin(meta) {
  const v = Number(meta?.utcOffsetMin);
  return Number.isFinite(v) ? v : DEFAULT_OFFSET_MIN;
}

// HH:mm local por offset (minutos; ej: -240)
function nowHHMMByOffset(offsetMin) {
  const now = new Date();
  const localMs = now.getTime() + offsetMin * 60_000;
  const d = new Date(localMs);
  const hh = String(d.getUTCHours()).padStart(2, "0");
  const mm = String(d.getUTCMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

// YYYYMMDD local por offset (+days opcional)
function ymdByOffset(offsetMin, plusDays = 0) {
  const now = new Date();
  const localMs = now.getTime() + offsetMin * 60_000 + plusDays * 86_400_000;
  const d = new Date(localMs);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return Number(`${y}${m}${day}`);
}

// YYYYMMDD de una fecha guardada (Firestore) según offset
function ymdOfDateByOffset(dateLike, offsetMin) {
  const d = dateLike?.toDate ? dateLike.toDate() : (dateLike instanceof Date ? dateLike : null);
  if (!d) return null;
  const ms = d.getTime() + offsetMin * 60_000;
  const x = new Date(ms);
  const y = x.getUTCFullYear();
  const m = String(x.getUTCMonth() + 1).padStart(2, "0");
  const day = String(x.getUTCDate()).padStart(2, "0");
  return Number(`${y}${m}${day}`);
}

// Dentro de ventana ±N minutos alrededor del target HH:mm
function isWithinSlot(hhmmNow, targetHHMM, windowMin = 2) {
  const toMin = (s) => { const [hh, mm] = s.split(":").map(Number); return hh * 60 + mm; };
  return Math.abs(toMin(hhmmNow) - toMin(targetHHMM)) <= windowMin;
}

/* ====================== Plantillas ====================== */

async function getDailyMessage(ymd) {
  const snap = await db.collection("config").doc("(default)")
    .collection("push_templates").doc("diarias").get();
  const mensajes = ((snap.data() || {}).mensajes || [])
    .filter(s => typeof s === "string" && s.trim());
  if (!mensajes.length) return null;
  const idx = ymd % mensajes.length;
  return (mensajes[idx] || "").toString().trim() || null;
}

async function getVencMessage(kind, ymd) {
  const snap = await db.collection("config").doc("(default)")
    .collection("push_templates").doc("vencido").get();
  const data = snap.data() || {};
  const arr = Array.isArray(data[kind]) ? data[kind] : [];
  if (!arr.length) return null;
  const idx = ymd % arr.length;
  return (arr[idx] || "").toString().trim() || null;
}

/* ====================== Usuarios / Tokens ====================== */

// Soporta meta.fcmToken (string) y meta.fcmTokens (array)
function extractTokens(meta) {
  const out = [];
  const t = typeof meta?.fcmToken === "string" ? meta.fcmToken.trim() : "";
  if (t) out.push(t);
  const arr = Array.isArray(meta?.fcmTokens) ? meta.fcmTokens : [];
  for (const x of arr) if (typeof x === "string" && x.trim()) out.push(x.trim());
  return [...new Set(out)];
}

async function getAllUsersMeta() {
  const qs = await db.collection("prestamistas").get();
  const out = [];
  qs.forEach(doc => {
    const data = doc.data() || {};
    const meta = data.meta || {};
    const tokens = extractTokens(meta);
    if (!tokens.length) return;
    const offsetMin = getUserOffsetMin(meta);
    out.push({ uid: doc.id, tokens, offsetMin });
  });
  return out;
}

/* ====================== Clasificación de vencimientos ====================== */

async function getUserDueCategory(uid, offsetMin) {
  const qs = await db.collection("prestamistas").doc(uid).collection("clientes").get();

  const today    = ymdByOffset(offsetMin, 0);
  const tomorrow = ymdByOffset(offsetMin, 1);
  const in2days  = ymdByOffset(offsetMin, 2);

  let hasVencido = false, hasHoy = false, hasManana = false, hasEn2 = false;

  qs.forEach(doc => {
    const data = doc.data() || {};
    const saldo = data.saldoActual;
    if (typeof saldo === "number" && saldo <= 0) return; // ignorar saldados

    const dueYMD = ymdOfDateByOffset(data.venceEl, offsetMin);
    if (!dueYMD) return;

    if (dueYMD <  today)   { hasVencido = true; return; }
    if (dueYMD === today)  { hasHoy = true;     return; }
    if (dueYMD === tomorrow){ hasManana = true; return; }
    if (dueYMD === in2days){ hasEn2 = true;     return; }
  });

  if (hasVencido) return "vencido";
  if (hasHoy)     return "venceHoy";
  if (hasManana)  return "venceManana";
  if (hasEn2)     return "venceEn2Dias";
  return null;
}

/* ====================== Candado ====================== */
// Doc: config/(default)/push_state_users/{uid}
async function getUserLock(uid) {
  const ref = db.collection("config").doc("(default)")
    .collection("push_state_users").doc(uid);
  const s = await ref.get();
  return s.exists ? (s.data() || {}) : null;
}
async function setUserLock(uid, offsetMin, source, slotHHMM) {
  const ref = db.collection("config").doc("(default)")
    .collection("push_state_users").doc(uid);
  const ymd = String(ymdByOffset(offsetMin, 0));
  await ref.set({
    yyyymmdd: ymd,
    lastSource: source,         // "vencimiento" | "diaria"
    lastSlot: slotHHMM,         // "08:00" | "09:00"
    ts: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

/* ====================== Envío ====================== */

async function sendToTokens(tokens, payload) {
  if (!Array.isArray(tokens) || !tokens.length) return { sent: 0, failed: 0 };
  const res = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
  return { sent: res.successCount, failed: res.failureCount };
}

/* ====================== TICK (cada 5 min UTC) ====================== */

exports.pushTick = onSchedule(
  { schedule: TICK_CRON, timeZone: "UTC" },
  async () => {
    const users = await getAllUsersMeta();

    for (const { uid, tokens, offsetMin } of users) {
      const nowHHMM = nowHHMMByOffset(offsetMin);
      const lock = await getUserLock(uid);

      // 08:00 — vencimientos
      if (isWithinSlot(nowHHMM, "08:00", 2)) {
        if (!(lock?.lastSlot === "08:00" && lock?.yyyymmdd === String(ymdByOffset(offsetMin, 0)))) {
          const ymd = ymdByOffset(offsetMin, 0);
          const kind = await getUserDueCategory(uid, offsetMin);
          if (kind) {
            const body = await getVencMessage(kind, ymd);
            if (body) {
              const payload = { notification: { title: "Mi Recibo", body }, data: { type: "vencimiento", kind } };
              const r = await sendToTokens(tokens, payload);
              if (r.sent > 0) await setUserLock(uid, offsetMin, "vencimiento", "08:00");
            }
          }
        }
      }

      // 09:00 — diaria (solo si no tiene due)
      if (isWithinSlot(nowHHMM, "09:00", 2)) {
        if (!(lock?.lastSlot === "09:00" && lock?.yyyymmdd === String(ymdByOffset(offsetMin, 0)))) {
          const ymd = ymdByOffset(offsetMin, 0);
          const kind = await getUserDueCategory(uid, offsetMin); // prioridad
          if (!kind) {
            const body = await getDailyMessage(ymd);
            if (body) {
              const payload = { notification: { title: "Mi Recibo", body }, data: { type: "daily" } };
              const r = await sendToTokens(tokens, payload);
              if (r.sent > 0) await setUserLock(uid, offsetMin, "diaria", "09:00");
            }
          }
        }
      }
    }
  }
);

/* ====================== TEST local ====================== */
/**
 * GET /testLocal?uid=...&hhmm=08:00|09:00&dry=1
 * Usa utcOffsetMin del usuario para simular un tick en esa hora local.
 */
exports.testLocal = onRequest(async (req, res) => {
  try {
    const uid = (req.query.uid || "").toString().trim();
    const hhmm = (req.query.hhmm || "08:00").toString().trim();
    const dry  = !!req.query.dry;

    if (!uid) return res.status(400).json({ ok:false, error:"uid requerido" });

    const doc = await db.collection("prestamistas").doc(uid).get();
    if (!doc.exists) return res.status(404).json({ ok:false, error:"usuario no existe" });

    const data = doc.data() || {};
    const meta = data.meta || {};
    const offsetMin = getUserOffsetMin(meta);
    const tokens = extractTokens(meta);
    const ymd = ymdByOffset(offsetMin, 0);

    const out = { uid, offsetMin, hhmm, ymd, dry, actions: [] };

    if (hhmm === "08:00") {
      const kind = await getUserDueCategory(uid, offsetMin);
      if (kind) {
        const body = await getVencMessage(kind, ymd);
        if (body) {
          if (!dry) {
            const r = await sendToTokens(tokens, { notification: { title: "Mi Recibo", body }, data: { type: "vencimiento", kind } });
            if (r.sent > 0) await setUserLock(uid, offsetMin, "vencimiento", "08:00");
          }
          out.actions.push({ type:"vencimiento", kind, sent: !dry });
        } else out.actions.push({ type:"vencimiento", reason:"no-template" });
      } else out.actions.push({ type:"vencimiento", reason:"no-due" });
    } else if (hhmm === "09:00") {
      const kind = await getUserDueCategory(uid, offsetMin);
      if (kind) {
        out.actions.push({ type:"daily", reason:"has-due", kind });
      } else {
        const body = await getDailyMessage(ymd);
        if (body) {
          if (!dry) {
            const r = await sendToTokens(tokens, { notification: { title: "Mi Recibo", body }, data: { type:"daily" } });
            if (r.sent > 0) await setUserLock(uid, offsetMin, "diaria", "09:00");
          }
          out.actions.push({ type:"daily", sent: !dry });
        } else out.actions.push({ type:"daily", reason:"no-template" });
      }
    } else {
      out.actions.push({ reason: "hhmm inválido (usa 08:00 o 09:00)" });
    }

    res.status(200).json({ ok:true, ...out });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok:false, error: String(e) });
  }
});

exports.ping = onRequest((_, res) => res.send("OK"));
