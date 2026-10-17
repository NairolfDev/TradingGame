// Shared Yahoo chart access (15s cache, de-duplicated in-flight requests).
const chartCache = new Map();
const chartRequests = new Map();
async function fetchQuoteChart(symbol) {
  const cached = chartCache.get(symbol);
  if (cached && Date.now() - cached.timestamp < 15000) return cached.chart;
  if (chartRequests.has(symbol)) return chartRequests.get(symbol);
  const request = (async () => {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=5m&range=1d`;
    const response = await fetch(url, {
      headers: {'User-Agent': 'Mozilla/5.0', Accept: 'application/json'},
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error(`Quote provider HTTP ${response.status}`);
    const chart = (await response.json())?.chart?.result?.[0];
    if (!chart) throw new Error('Symbol unavailable');
    if (chartCache.size >= 1000) chartCache.delete(chartCache.keys().next().value);
    chartCache.set(symbol, {timestamp: Date.now(), chart});
    return chart;
  })();
  chartRequests.set(symbol, request);
  try { return await request; } finally { chartRequests.delete(symbol); }
}

module.exports = {fetchQuoteChart};
