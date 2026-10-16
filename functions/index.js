const { onRequest } = require("firebase-functions/v2/https");
const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

const apiRouter = express.Router();

// 1. Health & Server-Time
apiRouter.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "Trading Game Core Backend",
    version: "1.3.0",
    serverTimeUtc: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
  });
});

apiRouter.get("/time", (req, res) => {
  res.json({
    serverTimeUtc: new Date().toISOString(),
    timestampMs: Date.now(),
  });
});

// In-Memory-Cache für Quotes (TTL: 15s)
const quoteCache = new Map();

// 2. Real Live Quote Proxy (CORS-frei für Flutter Web & Apps)
apiRouter.get("/quote", async (req, res) => {
  const symbol = req.query.symbol;
  if (!symbol) {
    return res.status(400).json({ error: "Query-Parameter 'symbol' erforderlich" });
  }

  const cached = quoteCache.get(symbol);
  if (cached && Date.now() - cached.timestamp < 15000) {
    return res.json(cached.data);
  }

  try {
    const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=5m&range=1d`;
    const resp = await fetch(yahooUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/json",
      },
    });

    if (!resp.ok) {
      return res.status(resp.status).json({ error: `Yahoo returned HTTP ${resp.status}` });
    }

    const json = await resp.json();
    const chart = json?.chart?.result?.[0];
    if (!chart) {
      return res.status(404).json({ error: "Symbol nicht gefunden" });
    }

    const meta = chart.meta || {};
    const price = meta.regularMarketPrice ?? meta.chartPreviousClose ?? 0;
    const previousClose = meta.chartPreviousClose ?? meta.previousClose ?? price;
    const high = meta.regularMarketDayHigh ?? null;
    const low = meta.regularMarketDayLow ?? null;
    const indicators = chart.indicators?.quote?.[0];
    const series = (indicators?.close || []).filter((v) => v !== null && typeof v === "number");

    const payload = {
      symbol,
      currentPrice: price,
      previousClose,
      high,
      low,
      series,
      timestamp: Date.now(),
      isLive: true,
    };

    quoteCache.set(symbol, { timestamp: Date.now(), data: payload });
    res.json(payload);
  } catch (err) {
    res.status(500).json({ error: err.message, symbol });
  }
});

// 2b. Real Historical Chart Series (1D, 1W, 1M, 1Y, 3Y, ALL)
apiRouter.get("/history", async (req, res) => {
  const symbol = req.query.symbol;
  const timeframe = req.query.timeframe || "1M";

  if (!symbol) {
    return res.status(400).json({ error: "Query-Parameter 'symbol' erforderlich" });
  }

  let range = "1mo";
  let interval = "1d";
  switch (timeframe) {
    case "1D": range = "1d"; interval = "5m"; break;
    case "1W": range = "5d"; interval = "15m"; break;
    case "1M": range = "1mo"; interval = "1d"; break;
    case "1Y": range = "1y"; interval = "1wk"; break;
    case "3Y": range = "3y"; interval = "1wk"; break;
    case "ALL": default: range = "max"; interval = "1mo"; break;
  }

  try {
    const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=${interval}&range=${range}`;
    const resp = await fetch(yahooUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)",
        "Accept": "application/json",
      },
    });

    if (!resp.ok) {
      return res.status(resp.status).json({ error: `Yahoo returned HTTP ${resp.status}` });
    }

    const json = await resp.json();
    const chart = json?.chart?.result?.[0];
    const indicators = chart?.indicators?.quote?.[0];
    const series = (indicators?.close || []).filter((v) => v !== null && typeof v === "number");

    res.json({ symbol, timeframe, series, count: series.length });
  } catch (err) {
    res.status(500).json({ error: err.message, symbol });
  }
});

// 3. Echte Live-Rangliste aus Firestore
apiRouter.get("/leaderboard", async (req, res) => {
  const timeframe = req.query.timeframe || "allTime";
  try {
    const snapshot = await admin.firestore().collection("leaderboard").orderBy("netWorth", "desc").limit(100).get();
    const entries = snapshot.docs.map((doc, idx) => ({
      rank: idx + 1,
      id: doc.id,
      ...doc.data(),
    }));
    res.json({ timeframe, count: entries.length, entries });
  } catch (err) {
    res.json({
      timeframe,
      count: 0,
      entries: [],
    });
  }
});

// 4. Server-Side Loan Validation & Credit Check
apiRouter.post("/loans/validate", (req, res) => {
  const { principal, durationDays, creditRatingScore, netWorth, totalDebt, lockoutUntil, isFirstLoan } = req.body;

  if (!principal || !durationDays) {
    return res.status(400).json({ error: "principal and durationDays are required" });
  }

  // 25.000 € Obergrenze für den Erstkredit
  if (isFirstLoan && principal > 25000) {
    return res.status(400).json({
      eligible: false,
      reason: "Der erste Bankkredit ist regulatorisch auf maximal 25.000 € begrenzt.",
      principal,
    });
  }

  // Check 5-day real calendar time lockout
  if (lockoutUntil) {
    const lockDate = new Date(lockoutUntil);
    if (lockDate > new Date()) {
      const remainingMs = lockDate.getTime() - Date.now();
      const remainingDays = Math.ceil(remainingMs / (1000 * 60 * 60 * 24));
      return res.status(403).json({
        eligible: false,
        reason: `5-Tage-Kreditsperre aktiv. Verbleibend: ${remainingDays} Tage.`,
        lockoutUntil,
      });
    }
  }

  // Base interest rate calculation
  let interestRate = 0.055; // AA default
  let grade = "AA Solid";

  if (creditRatingScore >= 90) {
    interestRate = 0.038;
    grade = "AAA Prime";
  } else if (creditRatingScore >= 75) {
    interestRate = 0.055;
    grade = "AA Solid";
  } else if (creditRatingScore >= 55) {
    interestRate = 0.085;
    grade = "BBB Investment";
  } else if (creditRatingScore >= 35) {
    interestRate = 0.145;
    grade = "BB Spekulativ";
  } else if (creditRatingScore >= 20) {
    interestRate = 0.220;
    grade = "CCC Hochrisiko";
  } else {
    interestRate = 0.360;
    grade = "D Kredithai-Sektor";
  }

  const interest = principal * interestRate * (durationDays / 365);
  const totalRepay = principal + interest;

  res.json({
    eligible: true,
    grade,
    interestRate,
    interest,
    totalRepay,
    durationDays,
    principal,
  });
});

// 5. Sanierungs-Notkredit bei Insolvenz (10.000 € @ 12%)
apiRouter.post("/loans/sanierung", (req, res) => {
  res.json({
    eligible: true,
    principal: 10000.0,
    interestRate: 0.12,
    durationDays: 30,
    note: "Sanierungs-Notkredit nach Insolvenz – 10.000 € Sofort-Liquidität",
  });
});

// Mount router on both "/api" and "/"
app.use("/api", apiRouter);
app.use("/", apiRouter);

// Export as Cloud Function v2
exports.api = onRequest({ region: "europe-west3" }, app);
