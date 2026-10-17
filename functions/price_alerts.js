// Price alert evaluation + delivery. Pure of Firebase specifics: db, messaging
// and the price source are injected so it can be unit-tested.

const MAX_ALERTS_PER_USER = 50;
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

const positive = (v) => typeof v === 'number' && Number.isFinite(v) && v > 0;

/**
 * Decides what happens to an alert at the current price.
 * A recurring alert fires once, then re-arms only after the price has crossed
 * back, so it cannot spam while the price hovers around the threshold.
 * @returns {{trigger: boolean, armed: boolean}}
 */
function evaluateAlert(alert, price) {
  const armed = alert.armed !== false;
  const hit = alert.direction === 'above' ? price >= alert.price : price <= alert.price;
  if (armed) return {trigger: hit, armed: !hit};
  return {trigger: false, armed: !hit};
}

const fmtEur = (v) => new Intl.NumberFormat('de-AT', {style: 'currency', currency: 'EUR'}).format(v);

function buildMessage(alert, price) {
  const word = alert.direction === 'above' ? 'über' : 'unter';
  return {
    title: `${alert.name || alert.symbol}: Kursalarm`,
    body: `${alert.symbol} liegt jetzt bei ${fmtEur(price)} (${word} ${fmtEur(alert.price)}).`,
  };
}

/**
 * @param {object} deps {db, messaging, getPrice(yahooSymbol)->Promise<number|null>, now}
 * @returns {Promise<{checked:number, triggered:number, sent:number}>}
 */
async function processAlerts({db, messaging, getPrice, now = () => Date.now()}) {
  const snap = await db.collection('priceAlerts').where('active', '==', true).get();
  const perUser = new Map();
  const bySymbol = new Map();
  for (const doc of snap.docs) {
    const a = doc.data();
    if (!a.uid || !positive(a.price) || typeof a.yahooSymbol !== 'string') continue;
    const n = (perUser.get(a.uid) || 0) + 1;
    perUser.set(a.uid, n);
    if (n > MAX_ALERTS_PER_USER) continue;
    if (!bySymbol.has(a.yahooSymbol)) bySymbol.set(a.yahooSymbol, []);
    bySymbol.get(a.yahooSymbol).push({ref: doc.ref, ...a});
  }

  const prices = new Map();
  await Promise.all([...bySymbol.keys()].map(async (symbol) => {
    try {
      const price = await getPrice(symbol);
      if (positive(price)) prices.set(symbol, price);
    } catch (_) { /* provider hiccup: try again next minute */ }
  }));

  const stats = {checked: 0, triggered: 0, sent: 0};
  const notifications = [];
  const writes = [];
  for (const [symbol, alerts] of bySymbol) {
    const price = prices.get(symbol);
    if (price === undefined) continue;
    for (const alert of alerts) {
      stats.checked++;
      const result = evaluateAlert(alert, price);
      if (result.trigger) {
        stats.triggered++;
        notifications.push({uid: alert.uid, alertId: alert.ref.id, ...buildMessage(alert, price)});
        writes.push([alert.ref, alert.recurring
          ? {armed: false, lastTriggeredAt: now()}
          : {active: false, armed: false, lastTriggeredAt: now()}]);
      } else if (result.armed !== (alert.armed !== false)) {
        writes.push([alert.ref, {armed: result.armed}]);
      }
    }
  }

  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const [ref, data] of writes.slice(i, i + 400)) batch.update(ref, data);
    await batch.commit();
  }

  const tokenCache = new Map();
  for (const n of notifications) {
    if (!tokenCache.has(n.uid)) {
      const t = await db.collection('deviceTokens').where('uid', '==', n.uid).get();
      tokenCache.set(n.uid, t.docs.map((d) => d.id));
    }
    const tokens = tokenCache.get(n.uid);
    if (tokens.length === 0) continue;
    const res = await messaging.sendEachForMulticast({
      tokens,
      notification: {title: n.title, body: n.body},
      data: {type: 'price_alert', alertId: n.alertId},
      android: {priority: 'high', notification: {channelId: 'price_alerts'}},
    });
    stats.sent += res.successCount;
    const dead = [];
    res.responses.forEach((r, idx) => {
      if (!r.success && INVALID_TOKEN_CODES.has(r.error?.code)) dead.push(tokens[idx]);
    });
    if (dead.length) {
      const batch = db.batch();
      for (const t of dead) batch.delete(db.collection('deviceTokens').doc(t));
      await batch.commit();
    }
  }
  return stats;
}

module.exports = {evaluateAlert, buildMessage, processAlerts, MAX_ALERTS_PER_USER};
