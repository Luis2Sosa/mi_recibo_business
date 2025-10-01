// functions/index.js
const functions = require("firebase-functions/v1"); // ← v1 para .pubsub.schedule(...)
const admin = require("firebase-admin");
admin.initializeApp();

// ---------- Utilidades ----------
const CHUNK = 500;
const arrayChunks = (arr, size) =>
  arr.reduce((acc, _, i) => (i % size ? acc : [...acc, arr.slice(i, i + size)]), []);

function today00() {
  const n = new Date();
  return new Date(n.getFullYear(), n.getMonth(), n.getDate());
}
function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}
function pickRandom(arr) {
  if (!arr || arr.length === 0) return null;
  return arr[Math.floor(Math.random() * arr.length)];
}

async function getPrestamistasConToken(db) {
  const qs = await db.collection("prestamistas").get();
  const list = [];
  qs.forEach((doc) => {
    const data = doc.data() || {};
    const meta = data.meta || {};
    const token = (meta.fcmToken || data.fcmToken || "").toString().trim();
    if (token) list.push({ uid: doc.id, token });
  });
  return list;
}
async function getTodosTokens(db) {
  const pres = await getPrestamistasConToken(db);
  return pres.map((p) => p.token);
}

// ---------- LECTURAS DE CONFIG ----------
async function getDailyMessage(db) {
  const snap = await db
    .collection("config").doc("(default)")
    .collection("push_templates").doc("diarias")
    .get();

  if (!snap.exists) return null;
  const mensajes = (snap.data().mensajes || [])
    .filter((s) => typeof s === "string" && s.trim());
  if (mensajes.length === 0) return null;

  const MS_PER_DAY = 86400000;
  const idx = Math.floor(Date.now() / MS_PER_DAY) % mensajes.length;
  return mensajes[idx];
}

async function getVencTemplates(db) {
  const snap = await db
    .collection("config").doc("(default)")
    .collection("push_templates").doc("vencimiento")
    .get();
  const data = snap.exists ? (snap.data() || {}) : {};
  const clean = (x) => (Array.isArray(x) ? x.filter((s) => typeof s === "string" && s.trim()) : []);
  return {
    vencido: clean(data.vencido),
    venceHoy: clean(data.venceHoy),
    venceManana: clean(data.venceManana),
    venceEn2Dias: clean(data.venceEn2Dias),
  };
}

// ---------- CÁLCULO DE ESTADOS ----------
async function contarEstadosCliente(db, uid) {
  const base = today00();        // hoy 00:00
  const man  = addDays(base, 1); // mañana 00:00
  const dos  = addDays(base, 2); // pasado mañana 00:00
  const tres = addDays(base, 3); // +2 días (exclusivo)

  const qs = await db
    .collection("prestamistas").doc(uid)
    .collection("clientes")
    .where("saldoActual", ">", 0)
    .get();

  let vencidos = 0, hoy = 0, manana = 0, en2 = 0;
  qs.forEach((doc) => {
    const d = doc.data() || {};
    const t = d.proximaFecha;
    const f = t?.toDate ? t.toDate() : null;
    if (!f) return;
    if (f < base) vencidos++;
    else if (f >= base && f < man) hoy++;
    else if (f >= man && f < dos) manana++;
    else if (f >= dos && f < tres) en2++;
  });
  return { vencidos, hoy, manana, en2 };
}

// =====================================================
// ===============   LÓGICA EJECUTABLE   ===============
// =====================================================
async function runDiarias() {
  const db = admin.firestore();
  const mensaje = await getDailyMessage(db);
  if (!mensaje) return { sent: 0, failed: 0, note: "Sin mensajes diarios" };

  const tokens = await getTodosTokens(db);
  if (tokens.length === 0) return { sent: 0, failed: 0, note: "Sin tokens" };

  const notif = {
    notification: { title: "Mi Recibo", body: mensaje },
    data: { type: "daily" },
  };

  let sent = 0, failed = 0;
  for (const chunk of arrayChunks(tokens, CHUNK)) {
    const res = await admin.messaging().sendEachForMulticast({ tokens: chunk, ...notif });
    sent += res.successCount;
    failed += res.failureCount;
  }
  return { sent, failed };
}

async function runVencimientos() {
  const db = admin.firestore();
  const tpl = await getVencTemplates(db);
  const prestamistas = await getPrestamistasConToken(db);
  if (prestamistas.length === 0) return { sent: 0, skipped: 0, note: "Sin prestamistas/token" };

  let sent = 0, skipped = 0;
  for (const p of prestamistas) {
    const { vencidos, hoy, manana, en2 } = await contarEstadosCliente(db, p.uid);
    let body = null;
    if (vencidos > 0) body = pickRandom(tpl.vencido);
    else if (hoy > 0) body = pickRandom(tpl.venceHoy);
    else if (manana > 0) body = pickRandom(tpl.venceManana);
    else if (en2 > 0) body = pickRandom(tpl.venceEn2Dias);

    if (!body) { skipped++; continue; }

    await admin.messaging().send({
      token: p.token,
      notification: { title: "Mi Recibo", body },
      data: {
        type: "due",
        vencidos: String(vencidos),
        hoy: String(hoy),
        manana: String(manana),
        en2: String(en2),
      },
    });
    sent++;
  }
  return { sent, skipped };
}

// =====================================================
// ==============    CRON (PRODUCCIÓN)    ==============
// =====================================================
exports.enviarNotificacionesDiarias = functions.pubsub
  .schedule("0 9 * * *").timeZone("America/Santo_Domingo")
  .onRun(async () => {
    const r = await runDiarias();
    console.log("Diarias →", r);
    return null;
  });

exports.enviarNotificacionesVencimiento = functions.pubsub
  .schedule("30 8 * * *").timeZone("America/Santo_Domingo")
  .onRun(async () => {
    const r = await runVencimientos();
    console.log("Vencimientos →", r);
    return null;
  });

// =====================================================
// ==============   HTTP TEST (EMULADOR)   =============
// =====================================================
exports.testDiarias = functions.https.onRequest(async (_req, res) => {
  const r = await runDiarias();
  res.json({ ok: true, ...r });
});

exports.testVencimientos = functions.https.onRequest(async (_req, res) => {
  const r = await runVencimientos();
  res.json({ ok: true, ...r });
});

// Ping simple
exports.ping = functions.https.onRequest((_req, res) => res.send("OK"));