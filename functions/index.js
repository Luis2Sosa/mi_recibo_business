// index.js (Firebase Functions v2 + Scheduler)

const admin = require('firebase-admin');
admin.initializeApp();

const { logger } = require('firebase-functions');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest }  = require('firebase-functions/v2/https');

// ---------- Helpers ----------
const CHUNK = 500; // FCM permite hasta 500 tokens por envío

function arrayChunks(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

async function getDailyMessage(db) {
  // Lee /config/(default)/push_templates/diarias  ->  { mensajes: [ ... ] }
  const snap = await db
    .collection('config').doc('(default)')
    .collection('push_templates').doc('diarias')
    .get();

  let mensajes = [];
  if (snap.exists) {
    const data = snap.data() || {};
    if (Array.isArray(data.mensajes)) {
      mensajes = data.mensajes
        .filter((s) => typeof s === 'string' && s.trim().length > 0);
    }
  }

  if (mensajes.length === 0) return null;

  // Índice del día (rota automáticamente)
  const MS_PER_DAY = 24 * 60 * 60 * 1000;
  const daysSinceEpoch = Math.floor(Date.now() / MS_PER_DAY);
  const idx = daysSinceEpoch % mensajes.length;
  return mensajes[idx];
}

async function getAllTokens(db) {
  // prestamistas/{uid}.meta.fcmToken
  const qs = await db.collection('prestamistas').get();
  const tokens = [];
  qs.forEach((doc) => {
    const data = doc.data() || {};
    const t = data?.meta?.fcmToken;
    if (typeof t === 'string' && t.trim()) tokens.push(t.trim());
  });
  return tokens;
}

async function enviarDiarias() {
  const db = admin.firestore();

  // 1) Mensaje del día
  const mensaje = await getDailyMessage(db);
  if (!mensaje) {
    logger.warn('No hay mensajes diarios configurados en /config/(default)/push_templates/diarias.mensajes');
    return;
  }

  // 2) Tokens
  const tokens = await getAllTokens(db);
  if (tokens.length === 0) {
    logger.warn('No hay tokens FCM en prestamistas/*');
    return;
  }

  const notif = {
    notification: { title: 'Mi Recibo', body: mensaje },
    data: { type: 'daily' }, // para que la app sepa que es diario
  };

  // 3) Enviar en bloques de 500
  let sent = 0; let failed = 0;
  for (const chunk of arrayChunks(tokens, CHUNK)) {
    const res = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      ...notif,
    });
    sent  += res.successCount;
    failed += res.failureCount;
  }

  logger.info(`✅ Notificaciones diarias: Enviadas=${sent}  Fallidas=${failed}`);
}

// ---------- CRON: 9:00 AM todos los días (zona RD) ----------
exports.enviarNotificacionesDiarias = onSchedule(
  { schedule: '0 9 * * *', timeZone: 'America/Santo_Domingo' }, // 9:00 AM diario
  async () => { await enviarDiarias(); }
);

// ---------- Endpoint HTTP para pruebas locales ----------
exports['run-enviarNotificacionesDiarias'] = onRequest(async (_req, res) => {
  try {
    await enviarDiarias();
    res.status(200).send('OK ✅');
  } catch (e) {
    logger.error(e);
    res.status(500).send('Error');
  }
});