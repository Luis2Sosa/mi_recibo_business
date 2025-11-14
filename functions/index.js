/**
 * Mi Recibo — Push diaria a las 09:00 hora local
 * - Tick: cada 5 min (UTC)
 * - Solo se envía 1 notificación diaria por usuario
 */

const admin = require("firebase-admin");
try { admin.app(); } catch { admin.initializeApp(); }

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");

const TICK_CRON = "*/5 * * * *";
const DEFAULT_OFFSET_MIN = -240;
const db = admin.firestore();

/* ====================== Helpers ====================== */

function getUserOffsetMin(meta) {
  const v = Number(meta?.utcOffsetMin);
  return Number.isFinite(v) ? v : DEFAULT_OFFSET_MIN;
}

function nowHHMMByOffset(offsetMin) {
  const now = new Date();
  const localMs = now.getTime() + offsetMin * 60_000;
  const d = new Date(localMs);
  const hh = String(d.getUTCHours()).padStart(2, "0");
  const mm = String(d.getUTCMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

function ymdByOffset(offsetMin) {
  const now = new Date();
  const localMs = now.getTime() + offsetMin * 60_000;
  const d = new Date(localMs);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return Number(`${y}${m}${day}`);
}

function isWithinSlot(hhmmNow, targetHHMM, windowMin = 2) {
  const toMin = (s) => {
    const [hh, mm] = s.split(":").map(Number);
    return hh * 60 + mm;
  };
  return Math.abs(toMin(hhmmNow) - toMin(targetHHMM)) <= windowMin;
}

/* ====================== Plantillas ====================== */

async function getDailyMessage(ymd) {
  const snap = await db
    .collection("config")
    .doc("(default)")
    .collection("push_templates")
    .doc("diarias")
    .get();

  const mensajes = ((snap.data() || {}).mensajes || [])
    .filter((s) => typeof s === "string" && s.trim());

  if (!mensajes.length) return null;

  const idx = ymd % mensajes.length;
  return mensajes[idx] || null;
}

/* ====================== Tokens ====================== */

function extractTokens(meta) {
  const out = [];
  const t = typeof meta?.fcmToken === "string" ? meta.fcmToken.trim() : "";
  if (t) out.push(t);

  const arr = Array.isArray(meta?.fcmTokens) ? meta.fcmTokens : [];
  for (const x of arr) {
    if (typeof x === "string" && x.trim()) out.push(x.trim());
  }

  return [...new Set(out)];
}

async function getAllUsersMeta() {
  const qs = await db.collection("prestamistas").get();
  const out = [];

  qs.forEach((doc) => {
    const data = doc.data() || {};
    const meta = data.meta || {};
    const tokens = extractTokens(meta);

    if (!tokens.length) return;

    const offsetMin = getUserOffsetMin(meta);
    out.push({ uid: doc.id, tokens, offsetMin });
  });

  return out;
}

/* ====================== Candado diario ====================== */

async function getUserLock(uid) {
  const ref = db.collection("config")
    .doc("(default)")
    .collection("push_state_users")
    .doc(uid);

  const s = await ref.get();
  return s.exists ? s.data() : null;
}

async function setUserLock(uid, offsetMin, slot) {
  const ref = db.collection("config")
    .doc("(default)")
    .collection("push_state_users")
    .doc(uid);

  const ymd = String(ymdByOffset(offsetMin));

  await ref.set(
    {
      yyyymmdd: ymd,
      lastSlot: slot,
      ts: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/* ====================== Envío ====================== */

async function sendToTokens(tokens, payload) {
  if (!tokens.length) return { sent: 0, failed: 0 };
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    ...payload,
  });
  return { sent: res.successCount, failed: res.failureCount };
}

/* ====================== TICK ====================== */

exports.pushTick = onSchedule(
  { schedule: TICK_CRON, timeZone: "UTC" },
  async () => {
    const users = await getAllUsersMeta();

    for (const { uid, tokens, offsetMin } of users) {
      const nowHHMM = nowHHMMByOffset(offsetMin);
      const todayYMD = ymdByOffset(offsetMin);

      // ======= SOLO 09:00 DIARIA =======
      if (isWithinSlot(nowHHMM, "09:00", 2)) {

        // --- LOCK DEL DÍA ---
        const lock = await getUserLock(uid);

        // Si ya se envió hoy → continuar
        if (lock?.yyyymmdd == String(todayYMD)) {
          continue;
        }

        // --- Obtener mensaje ---
        const body = await getDailyMessage(todayYMD);
        if (!body) continue;

        const payload = {
          notification: {
            title: "Mi Recibo",
            body,
          },
          data: { type: "daily" },
        };

        const r = await sendToTokens(tokens, payload);

        // Si se envió al menos a 1 token → guardar lock del día
        if (r.sent > 0) {
          await setUserLock(uid, offsetMin, todayYMD);
        }
      }
    }
  }
);


/* ====================== ENDPOINT DE TEST ====================== */

exports.testLocal = onRequest(async (req, res) => {
  try {
    const uid = (req.query.uid || "").toString().trim();
    const dry = req.query.dry === "true";

    if (!uid) return res.status(400).json({ ok: false, error: "uid requerido" });

    const doc = await db.collection("prestamistas").doc(uid).get();
    if (!doc.exists)
      return res.status(404).json({ ok: false, error: "usuario no existe" });

    const meta = doc.data().meta || {};
    const offsetMin = getUserOffsetMin(meta);
    const tokens = extractTokens(meta);
    const ymd = ymdByOffset(offsetMin);

    const body = await getDailyMessage(ymd);

    if (!body)
      return res.status(200).json({ ok: true, reason: "no-template" });

    if (!dry) {
      await sendToTokens(tokens, {
        notification: { title: "Mi Recibo", body },
        data: { type: "daily" },
      });
    }

    res.status(200).json({
      ok: true,
      sent: !dry,
      ymd,
      message: body,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: String(e) });
  }
});

exports.ping = onRequest((_, res) => res.send("OK"));
