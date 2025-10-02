/**
 * Mi Recibo — Notificaciones (v2)
 * - Vencimientos: 8:00 AM
 * - Diaria:       9:00 AM
 * - Candados separados por tipo (diaria | vencimiento)
 * - dryRun NO coloca candados
 * - Se bloquea solo después de confirmar plantilla y tokens
 */

const admin = require("firebase-admin");
try { admin.app(); } catch { admin.initializeApp(); }

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest }  = require("firebase-functions/v2/https");

const TZ = "America/Santo_Domingo";
const VENC_CRON  = "0 8 * * *"; // 8:00 AM
const DAILY_CRON = "0 9 * * *"; // 9:00 AM

// ---------- Utils ----------
const db = admin.firestore();

function todayKeyTZ(tz = TZ) {
  const f = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit",
  });
  const parts = f.formatToParts(new Date());
  const y = parts.find(p => p.type === "year").value;
  const m = parts.find(p => p.type === "month").value;
  const d = parts.find(p => p.type === "day").value;
  return `${y}${m}${d}`; // yyyymmdd
}

const chunk = (arr, n = 500) => {
  const out = [];
  for (let i = 0; i < arr.length; i += n) out.push(arr.slice(i, i + n));
  return out;
};

async function getAllTokens() {
  const qs = await db.collection("prestamistas").get();
  const tokens = [];
  qs.forEach((doc) => {
    const meta = (doc.data() || {}).meta || {};
    const t = meta.fcmToken;
    if (typeof t === "string" && t.trim()) tokens.push(t.trim());
  });
  return tokens;
}

function pickFromArrayTZ(arr, tz = TZ) {
  if (!Array.isArray(arr) || arr.length === 0) return null;
  const day = Number(todayKeyTZ(tz));
  const idx = day % arr.length;
  return (arr[idx] || "").toString().trim() || null;
}

async function getDailyMessage() {
  const snap = await db
    .collection("config").doc("(default)")
    .collection("push_templates").doc("diarias")
    .get();

  const mensajes = ((snap.data() || {}).mensajes || [])
    .filter((s) => typeof s === "string" && s.trim().length > 0);

  return pickFromArrayTZ(mensajes);
}

async function getVencMessage(kind /* "vencido" | "venceHoy" | "venceManana" | "venceEn2Dias" */) {
  // En tu Firestore el doc se llama "vencido"
  const snap = await db
    .collection("config").doc("(default)")
    .collection("push_templates").doc("vencido")
    .get();

  const data = snap.data() || {};
  const arr = Array.isArray(data[kind]) ? data[kind] : [];
  return pickFromArrayTZ(arr);
}

/**
 * Candado por tipo:
 *   config/(default)/push_state/<tipo>  (tipo: "diaria" | "vencimiento")
 *   { yyyymmdd: "20251002", source: "<tipo>", ts: serverTimestamp() }
 */
async function tryAcquireLockByType(tipo) {
  const ref = db.collection("config").doc("(default)")
               .collection("push_state").doc(tipo);

  const ymd = todayKeyTZ();

  return await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? (snap.data() || {}) : {};
    if (snap.exists && data.yyyymmdd === ymd) return false;
    tx.set(ref, {
      yyyymmdd: ymd,
      source: tipo,
      ts: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
}

async function sendMulticast(tokens, payload) {
  let sent = 0, failed = 0;
  for (const part of chunk(tokens, 500)) {
    const res = await admin.messaging().sendEachForMulticast({
      tokens: part,
      ...payload,
    });
    sent += res.successCount;
    failed += res.failureCount;
  }
  return { sent, failed };
}

// ---------- Envíos concretos ----------
async function sendVencimientos({ kind = "vencido", dryRun = false } = {}) {
  // 1) Preparar (NO candado aún)
  const body = await getVencMessage(kind);
  if (!body) return { sent: 0, failed: 0, reason: "no-template" };

  const tokens = await getAllTokens();
  if (tokens.length === 0) return { sent: 0, failed: 0, reason: "no-tokens" };

  if (dryRun) {
    console.log(`[DRYRUN VENC] ${tokens.length} tokens, msg="${body}"`);
    return { sent: 0, failed: 0, reason: "dryrun" };
  }

  // 2) Tomar candado por tipo
  const locked = await tryAcquireLockByType("vencimiento");
  if (!locked) return { sent: 0, failed: 0, reason: "locked" };

  // 3) Enviar
  const payload = {
    notification: { title: "Mi Recibo", body },
    data: { type: "vencimiento", kind },
  };
  const res = await sendMulticast(tokens, payload);
  console.log(`[VENC] Enviadas: ${res.sent}, Fallidas: ${res.failed}`);
  return res;
}

async function sendDiaria({ dryRun = false } = {}) {
  // 1) Preparar (NO candado aún)
  const body = await getDailyMessage();
  if (!body) return { sent: 0, failed: 0, reason: "no-template" };

  const tokens = await getAllTokens();
  if (tokens.length === 0) return { sent: 0, failed: 0, reason: "no-tokens" };

  if (dryRun) {
    console.log(`[DRYRUN DIARIA] ${tokens.length} tokens, msg="${body}"`);
    return { sent: 0, failed: 0, reason: "dryrun" };
  }

  // 2) Tomar candado por tipo
  const locked = await tryAcquireLockByType("diaria");
  if (!locked) return { sent: 0, failed: 0, reason: "locked" };

  // 3) Enviar
  const payload = {
    notification: { title: "Mi Recibo", body },
    data: { type: "daily" },
  };
  const res = await sendMulticast(tokens, payload);
  console.log(`[DIARIA] Enviadas: ${res.sent}, Fallidas: ${res.failed}`);
  return res;
}

// ---------- CRON (API v2) ----------
exports.enviarNotificacionesVencimiento = onSchedule(
  { schedule: VENC_CRON, timeZone: TZ },
  async () => sendVencimientos({ kind: "vencido", dryRun: false })
);

exports.enviarNotificacionesDiarias = onSchedule(
  { schedule: DAILY_CRON, timeZone: TZ },
  async () => sendDiaria({ dryRun: false })
);

// ---------- Endpoint de prueba ----------
/**
 * GET /test?mode=diaria[&dry=1]
 * GET /test?mode=vencimiento&kind=vencido|venceHoy|venceManana|venceEn2Dias[&dry=1]
 */
exports.test = onRequest(async (req, res) => {
  try {
    const mode = (req.query.mode || "diaria").toString();
    const kind = req.query.kind ? req.query.kind.toString() : "vencido";
    const dry  = !!req.query.dry;

    const out = mode === "vencimiento"
      ? await sendVencimientos({ kind, dryRun: dry })
      : await sendDiaria({ dryRun: dry });

    res.status(200).json({ ok: true, mode, kind, ...out });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: String(e) });
  }
});

exports.ping = onRequest((_, res) => res.send("OK"));
