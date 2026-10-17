const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeQuote, fxSymbolFor } = require('./market_quotes');

const now = 1792152000000;
const chart = (currency, price = 120) => ({
  meta: {currency, regularMarketPrice: price, chartPreviousClose: 100,
    regularMarketTime: now / 1000 - 900, regularMarketDayHigh: 125, regularMarketDayLow: 95},
  indicators: {quote: [{close: [null, 100, 120]}]},
});

test('EUR quotes preserve provider time and never claim licensed realtime', () => {
  const result = normalizeQuote('SAP.DE', chart('EUR'), null, now);
  assert.equal(result.currentPrice, 120);
  assert.equal(result.timestamp, now - 900000);
  assert.equal(result.fetchedAt, now);
  assert.equal(result.isLive, false);
  assert.deepEqual(result.series, [100, 120]);
});

test('USD and JPY prices divide by units per EUR and withhold unaligned charts/extrema', () => {
  for (const [currency, price, rate, expected] of [['USD', 120, 1.2, 100], ['JPY', 18000, 180, 100]]) {
    const fx = chart(currency, rate);
    const result = normalizeQuote('TEST', chart(currency, price), fx, now);
    assert.equal(result.currentPrice, expected);
    assert.equal(result.currency, 'EUR');
    assert.equal(result.nativeCurrency, currency);
    assert.equal(result.fxRate, rate);
    assert.equal(result.high, null);
    assert.deepEqual(result.series, []);
    assert.equal(result.conversionMethod, 'current-fx-snapshot');
  }
});

test('missing, nonfinite, unsupported and stale FX fail closed', () => {
  assert.throws(() => normalizeQuote('X', chart(undefined), null, now));
  assert.throws(() => normalizeQuote('X', chart('GBP'), null, now));
  assert.throws(() => normalizeQuote('X', chart('USD'), null, now));
  assert.throws(() => normalizeQuote('X', chart('EUR', Infinity), null, now));
  const fx = chart('USD', 1.2);
  fx.meta.regularMarketTime = now / 1000 - 5 * 86400;
  assert.throws(() => normalizeQuote('X', chart('USD'), fx, now));
  assert.equal(fxSymbolFor('USD'), 'EURUSD=X');
  assert.equal(fxSymbolFor('JPY'), 'EURJPY=X');
});
