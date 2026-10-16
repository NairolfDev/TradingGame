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
    version: "1.0.0",
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

// 2. Market Quotes Feed
apiRouter.get("/markets", (req, res) => {
  const quotes = [
    { symbol: "XAU/EUR", name: "Gold (Feinunze)", price: 2450.0, type: "commodity", category: "Edelmetalle" },
    { symbol: "XAG/EUR", name: "Silber (Feinunze)", price: 28.8, type: "commodity", category: "Edelmetalle" },
    { symbol: "XPT/EUR", name: "Platin (Feinunze)", price: 940.0, type: "commodity", category: "Edelmetalle" },
    { symbol: "BRENT/OIL", name: "Brent Crude Rohöl", price: 78.5, type: "commodity", category: "Energie" },
    { symbol: "EBS.VI", name: "Erste Group Bank AG", price: 49.2, type: "stock", category: "ATX" },
    { symbol: "OMV.VI", name: "OMV AG Wien", price: 41.8, type: "stock", category: "ATX" },
    { symbol: "BTC", name: "Bitcoin", price: 68500.0, type: "crypto", category: "Krypto 24/7" },
    { symbol: "ETH", name: "Ethereum", price: 3550.0, type: "crypto", category: "Krypto 24/7" },
    { symbol: "BUND-10Y", name: "Deutschland 10Y Bundesanleihe", price: 99.8, type: "bond", coupon: 0.026 },
    { symbol: "RAGB-10Y", name: "Republik Österreich 10Y Bund", price: 101.2, type: "bond", coupon: 0.032 },
  ];
  res.json({ count: quotes.length, quotes });
});

// 3. Leaderboard Aggregate
apiRouter.get("/leaderboard", async (req, res) => {
  const timeframe = req.query.timeframe || "allTime";
  try {
    const snapshot = await admin.firestore().collection("leaderboard").orderBy("netWorth", "desc").limit(50).get();
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
      entries: [
        { rank: 1, name: "Maximilian Rothschild", netWorth: 4850000.0, title: "Finanz-Oligarch", badge: "👑" },
        { rank: 2, name: "Sophia von Wall Street", netWorth: 1820000.0, title: "Hedgefonds-Titan", badge: "💎" },
        { rank: 3, name: "Lukas (Krypto-Whale)", netWorth: 740000.0, title: "Market Maker", badge: "⚡" },
      ],
    });
  }
});

// 4. Server-Side Loan Validation & Credit Check
apiRouter.post("/loans/validate", (req, res) => {
  const { principal, durationDays, creditRatingScore, netWorth, totalDebt, lockoutUntil } = req.body;

  if (!principal || !durationDays) {
    return res.status(400).json({ error: "principal and durationDays are required" });
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

// Mount router on both "/api" and "/"
app.use("/api", apiRouter);
app.use("/", apiRouter);

// Export as Cloud Function v2
exports.api = onRequest({ region: "europe-west3" }, app);
