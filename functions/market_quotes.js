const FX_SYMBOLS = {USD: 'EURUSD=X', JPY: 'EURJPY=X'};
const positive = (value) => typeof value === 'number' && Number.isFinite(value) && value > 0;
const fxSymbolFor = (currency) => FX_SYMBOLS[currency] || null;

function normalizeQuote(symbol, chart, fxChart, now = Date.now()) {
  const meta = chart?.meta || {};
  const currency = meta.currency;
  const price = meta.regularMarketPrice;
  const sourceTime = meta.regularMarketTime * 1000;
  if (!positive(price) || !positive(sourceTime) || sourceTime > now + 60000) {
    throw new Error('No valid provider price/timestamp');
  }
  if (currency !== 'EUR' && !fxSymbolFor(currency)) {
    throw new Error('Unsupported or missing quote currency');
  }
  let rate = 1;
  let fxTimestamp = null;
  if (currency !== 'EUR') {
    rate = fxChart?.meta?.regularMarketPrice;
    fxTimestamp = fxChart?.meta?.regularMarketTime * 1000;
    // Permit weekends, but never silently use indefinitely stale conversion rates.
    if (!positive(rate) || !positive(fxTimestamp) || fxTimestamp > now + 60000 ||
        now - fxTimestamp > 4 * 86400000 || fxChart.meta.currency !== currency) {
      throw new Error('No valid recent EUR exchange rate');
    }
  }
  const previous = meta.chartPreviousClose ?? meta.previousClose;
  if (!positive(previous)) throw new Error('No valid previous close');
  const convert = (value) => positive(value) ? value / rate : null;
  return {
    symbol, currency: 'EUR', nativeCurrency: currency,
    nativePrice: price, currentPrice: price / rate, previousClose: previous / rate,
    // Native-currency extrema and historical points are not EUR extrema/history.
    high: currency === 'EUR' ? convert(meta.regularMarketDayHigh) : null,
    low: currency === 'EUR' ? convert(meta.regularMarketDayLow) : null,
    series: currency === 'EUR'
      ? (chart.indicators?.quote?.[0]?.close || []).filter(positive) : [],
    timestamp: sourceTime, fetchedAt: now, source: 'Yahoo Finance', isLive: false,
    quoteStatus: 'delayed-or-end-of-day',
    fxSymbol: fxSymbolFor(currency), fxRate: rate, fxTimestamp,
    conversionMethod: currency === 'EUR' ? 'none' : 'current-fx-snapshot',
  };
}

module.exports = {normalizeQuote, fxSymbolFor};
