const {onSchedule} = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const {normalizeQuote, fxSymbolFor} = require('./market_quotes');
const {fetchQuoteChart} = require('./yahoo');
const {processAlerts} = require('./price_alerts');

if (!admin.apps.length) admin.initializeApp();

async function eurPrice(symbol) {
  const chart = await fetchQuoteChart(symbol);
  const fx = fxSymbolFor(chart.meta?.currency);
  const fxChart = fx ? await fetchQuoteChart(fx) : null;
  return normalizeQuote(symbol, chart, fxChart).currentPrice;
}

exports.checkPriceAlerts = onSchedule(
  {schedule: 'every 1 minutes', region: 'europe-west3', timeoutSeconds: 120, memory: '256MiB'},
  async () => {
    const stats = await processAlerts({
      db: admin.firestore(),
      messaging: admin.messaging(),
      getPrice: eurPrice,
    });
    if (stats.triggered > 0) console.log('price alerts', JSON.stringify(stats));
  },
);
