const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const axios = require("axios");

if (getApps().length === 0) initializeApp();

const FRANKFURTER_URL = "https://api.frankfurter.app/latest?from=USD&to=EUR";
const BINANCE_BASE = "https://api.binance.com/api/v3/ticker/price";
const YAHOO_BASE = "https://query1.finance.yahoo.com/v8/finance/chart";
const YAHOO2_BASE = "https://query2.finance.yahoo.com/v8/finance/chart";
const YAHOO_SEARCH_BASE = "https://query1.finance.yahoo.com/v1/finance/search";
const YAHOO_SCREENER_BASE = "https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved";
const YAHOO_CHART_BASE = "https://query1.finance.yahoo.com/v8/finance/chart";
const STOOQ_BASE = "https://stooq.com/q/l/";
const STOCKPRICES_BASE = "https://stockprices.dev/api";
const COINGECKO_SEARCH = "https://api.coingecko.com/api/v3/search";
const COINGECKO_PRICE = "https://api.coingecko.com/api/v3/simple/price";

const COINGECKO_IDS_BY_SYMBOL = {
  BTC: "bitcoin",
  ETH: "ethereum",
  BNB: "binancecoin",
  SOL: "solana",
  XRP: "ripple",
  ADA: "cardano",
  AVAX: "avalanche-2",
  DOGE: "dogecoin",
  DOT: "polkadot",
  LINK: "chainlink",
  MATIC: "matic-network",
  SHIB: "shiba-inu",
  LTC: "litecoin",
  BCH: "bitcoin-cash",
  ATOM: "cosmos",
  XLM: "stellar",
  NEAR: "near",
  UNI: "uniswap",
  AAVE: "aave",
  ETC: "ethereum-classic",
  VET: "vechain",
  FIL: "filecoin",
  ICP: "internet-computer",
  HBAR: "hedera-hashgraph",
  TRX: "tron",
  APT: "aptos",
  ALGO: "algorand",
  INJ: "injective-protocol",
  SEI: "sei-network",
  RNDR: "render-token",
  CRO: "cronos",
};

function noPrice(res, error = "Price not found") {
  return res.json({ price: null, source: null, error });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

// Cache EUR rate within a single function invocation to avoid redundant calls
let _cachedEurRate = null;
async function usdToEur() {
  if (_cachedEurRate) return _cachedEurRate;
  try {
    const res = await axios.get(FRANKFURTER_URL, { timeout: 8000 });
    _cachedEurRate = res.data?.rates?.EUR ?? null;
    return _cachedEurRate;
  } catch { return null; }
}

async function coingeckoPriceById(id) {
  try {
    const priceRes = await axios.get(`${COINGECKO_PRICE}?ids=${id}&vs_currencies=eur`, {
      headers: { Accept: "application/json" }, timeout: 8000,
    });
    const price = priceRes.data?.[id]?.eur;
    return price != null ? { price, source: "CoinGecko" } : null;
  } catch { return null; }
}

// CoinGecko fallback: prefer stable IDs to avoid search throttling/ambiguity.
async function coingeckoPrice(symbol) {
  try {
    const mappedId = COINGECKO_IDS_BY_SYMBOL[symbol.toUpperCase()];
    if (mappedId) {
      const mappedResult = await coingeckoPriceById(mappedId);
      if (mappedResult) return mappedResult;
    }

    const searchRes = await axios.get(`${COINGECKO_SEARCH}?query=${encodeURIComponent(symbol)}`, {
      headers: { Accept: "application/json" }, timeout: 8000,
    });
    const coins = searchRes.data?.coins ?? [];
    // Pick the coin whose symbol exactly matches (case-insensitive)
    const coin = coins.find((c) => c.symbol?.toUpperCase() === symbol.toUpperCase());
    if (!coin?.id) return null;

    return coingeckoPriceById(coin.id);
  } catch { return null; }
}

async function yahooCryptoPrice(symbol) {
  return yahooPrice(`${symbol}-EUR`);
}

async function binancePrice(symbol) {
  try {
    const res = await axios.get(`${BINANCE_BASE}?symbol=${symbol}`, { timeout: 8000 });
    return parseFloat(res.data?.price) || null;
  } catch { return null; }
}

async function yahooPrice(ticker, base = YAHOO_BASE) {
  try {
    const res = await axios.get(`${base}/${ticker}?interval=1d&range=1d`, {
      headers: { Accept: "application/json", "User-Agent": "Mozilla/5.0" },
      timeout: 8000,
    });
    const meta = res.data?.chart?.result?.[0]?.meta;
    const price = meta?.regularMarketPrice;
    if (!price) return null;
    const currency = (meta?.currency ?? "USD").toUpperCase();
    if (currency === "USD") {
      const rate = await usdToEur();
      if (!rate) return null;
      return { price: price * rate, source: "Yahoo Finance" };
    }
    return { price, source: "Yahoo Finance" };
  } catch { return null; }
}

async function stooqPrice(ticker) {
  try {
    const t = ticker.trim().toUpperCase();
    let stooqTicker, isEur;
    if (t.endsWith(".DE")) {
      stooqTicker = t.toLowerCase(); isEur = true;
    } else if (t.endsWith(".AS") || t.endsWith(".PA")) {
      stooqTicker = t.toLowerCase(); isEur = true;
    } else if (t.endsWith(".L")) {
      return null;
    } else {
      stooqTicker = (t.endsWith(".US") ? t : `${t}.US`).toLowerCase();
      isEur = false;
    }
    const res = await axios.get(
      `${STOOQ_BASE}?s=${stooqTicker}&f=sd2t2ohlcv&h&e=csv`,
      { headers: { "User-Agent": "Mozilla/5.0" }, timeout: 8000 }
    );
    const lines = res.data.trim().split("\n");
    if (lines.length < 2) return null;
    const cols = lines[1].split(",");
    if (cols.length < 7) return null;
    const close = parseFloat(cols[6].trim());
    if (!close || close <= 0) return null;
    if (isEur) return { price: close, source: "Stooq" };
    const rate = await usdToEur();
    if (!rate) return null;
    return { price: close * rate, source: "Stooq" };
  } catch { return null; }
}

async function stockpricesPrice(ticker, isEtf) {
  try {
    const segment = isEtf ? "etfs" : "stocks";
    const res = await axios.get(`${STOCKPRICES_BASE}/${segment}/${ticker}`, {
      headers: { Accept: "application/json" },
      timeout: 8000,
    });
    const usdPrice = res.data?.Price;
    if (!usdPrice) return null;
    const rate = await usdToEur();
    if (!rate) return null;
    return { price: usdPrice * rate, source: "stockprices.dev" };
  } catch { return null; }
}

// ── Market movers helpers ─────────────────────────────────────────────────────

const YAHOO_HEADERS = { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", Accept: "application/json" };
const YAHOO_QUOTE_BASE = "https://query1.finance.yahoo.com/v7/finance/quote";
const YAHOO_TRENDING_BASE = "https://query1.finance.yahoo.com/v1/finance/trending";

const INDEX_SYMBOLS = ["^GDAXI", "^GSPC", "^IXIC", "^DJI", "^STOXX50E"];
const INDEX_NAMES = {
  "^GDAXI": "DAX", "^GSPC": "S&P 500", "^IXIC": "Nasdaq",
  "^DJI": "Dow Jones", "^STOXX50E": "STOXX 50",
};

// Single batch call for many symbols → much lighter than individual chart calls
async function batchQuote(symbols) {
  try {
    const res = await axios.get(
      `${YAHOO_QUOTE_BASE}?symbols=${symbols.join(",")}`,
      { headers: YAHOO_HEADERS, timeout: 12000 }
    );
    return res.data?.quoteResponse?.result ?? [];
  } catch { return []; }
}

function quoteToMover(q) {
  return {
    symbol: q.symbol,
    name: q.shortName || q.longName || q.symbol,
    price: parseFloat((q.regularMarketPrice ?? 0).toFixed(2)),
    changePct: parseFloat((q.regularMarketChangePercent ?? 0).toFixed(2)),
    change: parseFloat((q.regularMarketChange ?? 0).toFixed(4)),
    currency: q.currency ?? "USD",
    exchange: q.fullExchangeName || q.exchange || "",
    quoteType: q.quoteType || "EQUITY",
  };
}

// Curated universe of major global stocks for weekly performance tracking
const STOCK_UNIVERSE = [
  // US mega caps
  "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "META", "TSLA", "AVGO", "JPM", "V",
  // US large caps
  "MA", "UNH", "HD", "XOM", "COST", "NFLX", "AMD", "CRM", "NOW", "ADBE",
  // Growth / trending
  "PLTR", "HOOD", "COIN", "MSTR", "MU", "QCOM", "INTC", "UBER", "SHOP", "SQ",
  // European stocks (XETRA)
  "SAP.DE", "SIE.DE", "BMW.DE", "MBG.DE", "ALV.DE", "DTE.DE", "BAS.DE", "ADS.DE",
  // Global
  "ASML", "NVO", "TSM",
];

// Curated universe of major global ETFs for weekly performance tracking
const ETF_UNIVERSE = [
  // US broad market
  "SPY", "QQQ", "IWM", "DIA", "VTI", "VT",
  // US sectors
  "XLK", "XLF", "XLV", "XLE", "XLI", "SOXX", "ARKK", "VGT",
  // Bonds & commodities
  "GLD", "IAU", "TLT", "LQD", "HYG", "SLV",
  // Europe-listed (XETRA / Euronext)
  "VWCE.DE", "IWDA.AS", "EUNL.DE", "EXXT.DE", "XDWI.DE", "DBXD.DE", "IQQW.DE",
  // London
  "CSPX.L", "SWRD.L", "VUSA.L", "VUAA.L", "IUSA.L",
  // EM / international
  "EEM", "EFA", "VWO", "IEMG",
];

// Generic 5-day weekly mover — works for both stocks and ETFs.
// USD prices are converted to EUR so the app always displays in €.
async function weeklyMover(ticker, quoteType) {
  try {
    const res = await axios.get(
      `${YAHOO_CHART_BASE}/${encodeURIComponent(ticker)}?range=5d&interval=1d`,
      { headers: YAHOO_HEADERS, timeout: 8000 }
    );
    const result = res.data?.chart?.result?.[0];
    if (!result) return null;
    const closes = result.indicators?.quote?.[0]?.close?.filter((v) => v != null);
    if (!closes || closes.length < 2) return null;
    const first = closes[0];
    const last = closes[closes.length - 1];
    const changePct = ((last - first) / first) * 100;
    const meta = result.meta;
    const rawCurrency = (meta.currency ?? "USD").toUpperCase();

    let price = last;
    let currency = rawCurrency;
    if (rawCurrency === "USD") {
      const rate = await usdToEur();
      if (rate) { price = last * rate; currency = "EUR"; }
    }

    return {
      symbol: meta.symbol ?? ticker,
      name: meta.longName || meta.shortName || ticker,
      price: parseFloat(price.toFixed(2)),
      changePct: parseFloat(changePct.toFixed(2)),
      change: parseFloat((last - first).toFixed(4)),
      currency,
      exchange: meta.exchangeName ?? "",
      quoteType,
    };
  } catch { return null; }
}

// Daily quote for indices — uses today's regularMarketChangePercent from chart
// meta so the % matches what users see on Google Finance / news.
async function dailyIndex(ticker) {
  try {
    const res = await axios.get(
      `${YAHOO_CHART_BASE}/${encodeURIComponent(ticker)}?range=1d&interval=1d`,
      { headers: YAHOO_HEADERS, timeout: 8000 }
    );
    const meta = res.data?.chart?.result?.[0]?.meta;
    if (!meta?.regularMarketPrice) return null;
    return {
      symbol: meta.symbol ?? ticker,
      name: INDEX_NAMES[meta.symbol ?? ticker] || meta.shortName || ticker,
      value: parseFloat((meta.regularMarketPrice ?? 0).toFixed(2)),
      changePct: parseFloat((meta.regularMarketChangePercent ?? 0).toFixed(2)),
      change: parseFloat((meta.regularMarketChange ?? 0).toFixed(2)),
    };
  } catch { return null; }
}

// ── Chip Radar helpers ────────────────────────────────────────────────────────

function daysBetween(dateStr1, dateStr2) {
  const d1 = new Date(dateStr1 + "T12:00:00Z");
  const d2 = new Date(dateStr2 + "T12:00:00Z");
  return Math.round(Math.abs(d2 - d1) / (1000 * 60 * 60 * 24));
}

function median(arr) {
  if (!arr.length) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}

async function loadState() {
  try {
    const file = getStorage().bucket().file("radar/ohlcv_state.json");
    const [exists] = await file.exists();
    if (!exists) return { lastUpdatedDate: null, tickers: {} };
    const [contents] = await file.download();
    return JSON.parse(contents.toString());
  } catch (e) {
    console.error("loadState error:", e.message);
    return { lastUpdatedDate: null, tickers: {} };
  }
}

async function saveState(state) {
  const file = getStorage().bucket().file("radar/ohlcv_state.json");
  await file.save(JSON.stringify(state), { contentType: "application/json" });
}

function computeVolumeMetrics(bars) {
  if (bars.length < 2) return null;

  const todayBar = bars[bars.length - 1];
  const todayVol = todayBar.v;
  const todayDollarVol = todayBar.c * todayBar.v;

  const prev = bars.slice(0, -1);
  const prev20vols      = prev.slice(-20).map(b => b.v);
  const prev50vols      = prev.slice(-50).map(b => b.v);
  const prev20dollarVols = prev.slice(-20).map(b => b.c * b.v);

  const medVol20       = median(prev20vols);
  const medVol50       = prev50vols.length >= 20 ? median(prev50vols) : null;
  const medDollarVol20 = median(prev20dollarVols);

  const volRatio20 = medVol20 > 0 ? todayVol / medVol20 : 0;
  const volRatio50 = medVol50 && medVol50 > 0 ? todayVol / medVol50 : null;

  return { todayVol, todayDollarVol, medVol20, medDollarVol20, volRatio20, volRatio50 };
}

function computeStructureMetrics(bars) {
  if (bars.length < 21) return null;

  const closes   = bars.map(b => b.c);
  const highs    = bars.map(b => b.h);
  const todayClose = closes[closes.length - 1];

  const smaFn = (n) => {
    const slice = closes.slice(-n);
    return slice.reduce((s, v) => s + v, 0) / slice.length;
  };

  const sma20  = closes.length >= 20  ? smaFn(20)  : null;
  const sma50  = closes.length >= 50  ? smaFn(50)  : null;
  const sma200 = closes.length >= 200 ? smaFn(200) : null;

  let sma20Slope = null;
  if (closes.length >= 25) {
    const sma20now = smaFn(20);
    const older    = closes.slice(0, -5);
    const sma20ago = older.slice(-20).reduce((s, v) => s + v, 0) / 20;
    sma20Slope = sma20now - sma20ago;
  }

  const high20  = highs.length >= 20  ? Math.max(...highs.slice(-20))  : null;
  const high55  = highs.length >= 55  ? Math.max(...highs.slice(-55))  : null;
  const high252 = highs.length >= 252 ? Math.max(...highs.slice(-252)) : null;
  const low252  = bars.length  >= 252 ? Math.min(...bars.slice(-252).map(b => b.l)) : null;

  const newHigh20  = high20  != null && todayClose >= high20  * 0.99;
  const newHigh55  = high55  != null && todayClose >= high55  * 0.99;
  const newHigh252 = high252 != null && todayClose >= high252 * 0.99;

  const rangePosition252 = (high252 && low252 && high252 !== low252)
    ? (todayClose - low252) / (high252 - low252) : null;
  const distFromHigh252 = high252 ? todayClose / high252 : null;

  const todayBar     = bars[bars.length - 1];
  const closeLocation = (todayBar.h !== todayBar.l)
    ? (todayBar.c - todayBar.l) / (todayBar.h - todayBar.l) : 0.5;

  const n     = closes.length;
  const ch1d  = n >= 2  ? (closes[n-1] - closes[n-2])  / closes[n-2]  * 100 : null;
  const ch7d  = n >= 8  ? (closes[n-1] - closes[n-8])  / closes[n-8]  * 100 : null;
  const ch14d = n >= 15 ? (closes[n-1] - closes[n-15]) / closes[n-15] * 100 : null;
  const ch21d = n >= 22 ? (closes[n-1] - closes[n-22]) / closes[n-22] * 100 : null;
  const ch63d  = n >= 64  ? (closes[n-1] - closes[n-64])  / closes[n-64]  * 100 : null;
  const ch126d = n >= 127 ? (closes[n-1] - closes[n-127]) / closes[n-127] * 100 : null;

  return {
    todayClose, sma20, sma50, sma200, sma20Slope,
    newHigh20, newHigh55, newHigh252,
    rangePosition252, distFromHigh252, closeLocation,
    ch1d, ch7d, ch14d, ch21d, ch63d, ch126d,
  };
}

function classifyWave(s, vol) {
  if (s.ch21d > 75 || (s.sma20 && s.todayClose > s.sma20 * 1.25)) return "extended";

  if (
    s.ch7d >= 8 &&
    s.ch21d != null && s.ch21d < 50 &&
    (s.newHigh20 || s.newHigh55) &&
    vol.volRatio20 >= 1.5 &&
    s.closeLocation >= 0.65
  ) return "early";

  if (
    s.ch7d >= 20 &&
    s.ch21d != null && s.ch21d >= 35 && s.ch21d <= 75 &&
    (s.newHigh55 || s.newHigh252) &&
    vol.volRatio20 >= 1.2
  ) return "running";

  if (
    s.ch21d != null && s.ch21d >= 5 && s.ch21d <= 20 &&
    s.ch63d != null && s.ch63d >= 20 &&
    s.sma20 && s.sma50 && s.sma20 > s.sma50 &&
    vol.volRatio20 >= 1.0
  ) return "accumulating";

  if (s.ch7d >= 10 || (s.ch21d != null && s.ch21d >= 15)) return "watching";

  return null;
}

// ── Phase 4: Relative strength percentile ranking ─────────────────────────────
//
// Called after the hard-filter pass with the full allMetrics array.
// Mutates each metric object in-place: adds rs21Rank, rs63Rank, rs126Rank (0–100).
// A rank of 95 means "top 5% of all stocks in today's scan".

function assignAllRanks(allMetrics) {
  // rs21Rank — percentile of 21-day return
  const with21 = allMetrics.filter(m => m.s.ch21d != null);
  with21.sort((a, b) => a.s.ch21d - b.s.ch21d);
  with21.forEach((m, i) => {
    m.rs21Rank = Math.round((i / Math.max(with21.length - 1, 1)) * 100);
  });

  // rs63Rank — percentile of 63-day (quarter) return
  const with63 = allMetrics.filter(m => m.s.ch63d != null);
  with63.sort((a, b) => a.s.ch63d - b.s.ch63d);
  with63.forEach((m, i) => {
    m.rs63Rank = Math.round((i / Math.max(with63.length - 1, 1)) * 100);
  });

  // rs126Rank — percentile of 126-day (half-year) return
  // Null for most stocks until ~6 months of history exist — handled gracefully.
  const with126 = allMetrics.filter(m => m.s.ch126d != null);
  with126.sort((a, b) => a.s.ch126d - b.s.ch126d);
  with126.forEach((m, i) => {
    m.rs126Rank = Math.round((i / Math.max(with126.length - 1, 1)) * 100);
  });
}

// ── Phase 5: Composite score (0–100) ──────────────────────────────────────────
//
// Five components (max 25 + 25 + 20 + 15 + 10 = 95 pts) plus penalties.
// Designed so early-stage breakouts outscore extended/overheated stocks.

function computeSurgeScore(s, vol, m) {
  let score = 0;

  // ── Component 1: Relative Strength (0–25 pts) ─────────────────────────────
  if (m.rs21Rank != null) {
    if      (m.rs21Rank >= 95) score += 25;
    else if (m.rs21Rank >= 90) score += 20;
    else if (m.rs21Rank >= 80) score += 14;
    else if (m.rs21Rank >= 70) score += 8;
    else                       score += 3;
  }

  // ── Component 2: Breakout quality (0–25 pts) ──────────────────────────────
  if      (s.newHigh252) score += 25;
  else if (s.newHigh55)  score += 18;
  else if (s.newHigh20)  score += 10;

  // ── Component 3: Volume expansion (0–20 pts) ──────────────────────────────
  if      (vol.volRatio20 >= 4.0) score += 20;
  else if (vol.volRatio20 >= 3.0) score += 16;
  else if (vol.volRatio20 >= 2.0) score += 12;
  else if (vol.volRatio20 >= 1.5) score += 7;
  else                            score += 2;

  // ── Component 4: Trend quality (0–15 pts) ─────────────────────────────────
  if (s.sma20 && s.sma50 && s.sma200) {
    if      (s.sma20 > s.sma50 && s.sma50 > s.sma200) score += 15;
    else if (s.sma20 > s.sma50)                        score += 9;
    else                                                score += 3;
  } else if (s.sma20 && s.sma50 && s.sma20 > s.sma50) {
    score += 9;
  }

  // ── Component 5: Close quality (0–10 pts) ─────────────────────────────────
  if      (s.closeLocation >= 0.85) score += 10;
  else if (s.closeLocation >= 0.70) score += 6;
  else if (s.closeLocation >= 0.50) score += 3;

  // ── Penalties ─────────────────────────────────────────────────────────────
  // Extension: severely overextended stocks score lower than early movers
  if (s.ch21d != null) {
    if      (s.ch21d > 150) score -= 20;
    else if (s.ch21d > 100) score -= 12;
    else if (s.ch21d > 75)  score -= 6;
  }

  // Rebound penalty: deep 126d loss suggests dead-cat rather than breakout
  if      (s.ch126d != null && s.ch126d < -30) score -= 15;
  else if (s.ch126d != null && s.ch126d < -15) score -= 7;

  // Still far from 52-week high despite recent move
  if (s.distFromHigh252 != null) {
    if      (s.distFromHigh252 < 0.80) score -= 10;
    else if (s.distFromHigh252 < 0.90) score -= 4;
  }

  return Math.max(0, Math.min(100, Math.round(score)));
}

// ── Cloud Function ────────────────────────────────────────────────────────────

exports.fetchPrice = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
    _cachedEurRate = null; // reset per-request cache
    const { type, symbol, ticker, isEtf, q } = req.query;

      // ── Crypto ──────────────────────────────────────────────────────────────
      if (type === "crypto") {
        const sym = (symbol ?? "").trim().toUpperCase();
        if (!sym) return res.status(400).json({ error: "Missing symbol" });

        const eurPrice = await binancePrice(`${sym}EUR`);
        if (eurPrice !== null) return res.json({ price: eurPrice, source: "Binance" });

        const usdtPrice = await binancePrice(`${sym}USDT`);
        if (usdtPrice !== null) {
          const rate = await usdToEur();
          if (rate) return res.json({ price: usdtPrice * rate, source: "Binance" });
        }

        const yahooResult = await yahooCryptoPrice(sym);
        if (yahooResult) return res.json(yahooResult);

        // Fallback: CoinGecko (covers coins not listed on Binance)
        const cgResult = await coingeckoPrice(sym);
        if (cgResult) return res.json(cgResult);

        return noPrice(res);
      }

      // ── Stock / ETF / Commodity ──────────────────────────────────────────────
      if (type === "stock" || type === "etf" || type === "commodity") {
        if (!ticker) return res.status(400).json({ error: "Missing ticker" });
        const isEtfBool = isEtf === "true";

        let result = await yahooPrice(ticker);
        if (result) return res.json(result);

        result = await yahooPrice(ticker, YAHOO2_BASE);
        if (result) return res.json(result);

        if (type !== "commodity") {
          result = await stooqPrice(ticker);
          if (result) return res.json(result);

          const base = ticker.trim().split(".")[0].toUpperCase();
          if (base !== ticker.trim().toUpperCase()) {
            result = await yahooPrice(base);
            if (result) return res.json(result);
          }

          result = await stockpricesPrice(base, isEtfBool);
          if (result) return res.json(result);
        }

        return noPrice(res);
      }

      // ── Batch prices ─────────────────────────────────────────────────────────
      // tickers param: "EXXT.DE:etf,AAPL:stock,VWCE.DE:etf"
      if (type === "batch") {
        const tickersParam = req.query.tickers;
        if (!tickersParam) return res.status(400).json({ error: "Missing tickers" });

        const items = tickersParam.split(",").map((t) => {
          const parts = t.trim().split(":");
          return { ticker: parts[0], isEtf: parts[1] === "etf" };
        }).filter((t) => t.ticker);

        async function fetchOneTicker({ ticker, isEtf }) {
          let result = await yahooPrice(ticker);
          if (!result) result = await yahooPrice(ticker, YAHOO2_BASE);
          if (!result) result = await stooqPrice(ticker);
          if (!result) {
            const base = ticker.trim().split(".")[0].toUpperCase();
            if (base !== ticker.trim().toUpperCase()) result = await yahooPrice(base);
          }
          if (!result) {
            result = await stockpricesPrice(ticker.trim().split(".")[0].toUpperCase(), isEtf);
          }
          return { ticker, price: result?.price ?? null };
        }

        const results = await Promise.all(items.map(fetchOneTicker));
        const prices = {};
        results.forEach(({ ticker, price }) => { if (price != null) prices[ticker] = price; });
        return res.json({ prices });
      }

      // ── Search ───────────────────────────────────────────────────────────────
      if (type === "search") {
        if (!q) return res.status(400).json({ error: "Missing q" });
        try {
          const encoded = encodeURIComponent(q.trim());
          const r = await axios.get(
            `${YAHOO_SEARCH_BASE}?q=${encoded}&lang=en-US&region=DE&quotesCount=15&newsCount=0&enableFuzzyQuery=false`,
            { headers: { "User-Agent": "Mozilla/5.0", Accept: "application/json" }, timeout: 8000 }
          );
          const results = (r.data?.quotes ?? [])
            .filter((item) => item.quoteType === "ETF" || item.quoteType === "EQUITY")
            .map((item) => ({
              symbol: (item.symbol ?? "").trim(),
              name: item.shortname ?? item.longname ?? item.symbol ?? "",
              type: item.quoteType === "ETF" ? "ETF" : "Aktie",
              exchange: item.exchDisp ?? item.exchange ?? "",
            }))
            .filter((r) => r.symbol && r.name);
          return res.json({ results });
        } catch {
          return res.json({ results: [] });
        }
      }

      res.status(400).json({ error: "Invalid type" });
  }
);

// ── getMarketMovers ───────────────────────────────────────────────────────────
// Returns indices, weekly top stocks/ETFs, trending tickers, most actives.
//
// Strategy: use the chart API (/v8/finance/chart) for everything except the
// screener. The /v7/finance/quote batch endpoint has been rate-limited by
// Yahoo Finance and returns empty results — skip it entirely.
//   Phase 1 — curated stock/ETF/index lists + trending/actives in parallel (37 calls)
//   Phase 2 — weeklyMover for trending symbols (12 calls)

// Smaller curated lists fed directly into weeklyMover (chart API, reliably works)
const STOCK_LIST = [
  "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "META", "TSLA", "NFLX",
  "AMD", "PLTR", "COIN", "JPM", "SAP.DE", "ASML", "NVO",
];
const ETF_LIST = [
  "SPY", "QQQ", "SOXX", "ARKK", "GLD", "VGT", "XLK", "TLT",
  "VWCE.DE", "IWDA.AS", "EUNL.DE", "XDWI.DE", "EEM", "CSPX.L", "VTI",
];

exports.getMarketMovers = onRequest(
  { region: "us-central1", cors: true, timeoutSeconds: 60 },
  async (req, res) => {
    try {
      _cachedEurRate = null;

      // ── Phase 1: all calls in parallel ───────────────────────────────────
      const [indexWeekly, stockWeekly, etfWeekly, trendingRaw, activesRaw] = await Promise.all([
        // Indices: daily % (today's change — matches Google Finance / news)
        Promise.all(INDEX_SYMBOLS.map((s) => dailyIndex(s))),
        // Stocks: direct weeklyMover on curated list
        Promise.all(STOCK_LIST.map((s) => weeklyMover(s, "EQUITY"))),
        // ETFs: direct weeklyMover on curated list
        Promise.all(ETF_LIST.map((s) => weeklyMover(s, "ETF"))),
        // Trending tickers (symbols only, prices fetched in Phase 2)
        axios.get(`${YAHOO_TRENDING_BASE}/US`, { headers: YAHOO_HEADERS, timeout: 8000 })
          .then((r) => r.data?.finance?.result?.[0]?.quotes ?? [])
          .catch(() => []),
        // Most actives screener (working endpoint)
        axios.get(YAHOO_SCREENER_BASE, {
          params: { scrIds: "most_actives", count: 10, formatted: false },
          headers: YAHOO_HEADERS, timeout: 10000,
        }).then((r) => r.data?.finance?.result?.[0]?.quotes ?? []).catch(() => []),
      ]);

      // ── Indices (dailyIndex already returns the right shape) ─────────────
      const indices = indexWeekly.filter(Boolean);

      const stocks = stockWeekly.filter(Boolean)
        .sort((a, b) => b.changePct - a.changePct).slice(0, 10);
      const etfs = etfWeekly.filter(Boolean)
        .sort((a, b) => b.changePct - a.changePct).slice(0, 10);

      // ── Trending: use chart API for prices (same as stocks/ETFs) ─────────
      const trendingSymbols = trendingRaw.slice(0, 12).map((q) => q.symbol);
      const trendingResults = trendingSymbols.length
        ? await Promise.all(trendingSymbols.map((s) => weeklyMover(s, "EQUITY")))
        : [];
      const trending = trendingResults.filter(Boolean).slice(0, 10);

      // ── Most actives ──────────────────────────────────────────────────────
      const actives = activesRaw
        .filter((q) => q.regularMarketPrice)
        .slice(0, 10).map(quoteToMover);

      res.json({ indices, stocks, etfs, trending, actives, updatedAt: new Date().toISOString() });
    } catch (e) {
      res.status(500).json({ error: e.message });
    }
  }
);

// ── watchlistAlerts ───────────────────────────────────────────────────────────
// Runs every 15 minutes. Checks all PRO users' watchlist targets, fetches
// deduplicated prices, sends FCM push when a target is reached.

async function _fetchSymbolPrice(symbol, type) {
  try {
    if (type === "crypto") {
      const eurPrice = await binancePrice(`${symbol}EUR`);
      if (eurPrice !== null) return eurPrice;
      const usdtPrice = await binancePrice(`${symbol}USDT`);
      if (usdtPrice !== null) {
        const rate = await usdToEur();
        if (rate) return usdtPrice * rate;
      }
      const yahoo = await yahooCryptoPrice(symbol);
      if (yahoo) return yahoo.price;
      const cg = await coingeckoPrice(symbol);
      return cg?.price ?? null;
    } else {
      // stock or etf — try Yahoo query1, then query2
      let result = await yahooPrice(symbol);
      if (result) return result.price;
      result = await yahooPrice(symbol, YAHOO2_BASE);
      return result?.price ?? null;
    }
  } catch { return null; }
}

function _fmtPrice(p) {
  if (p >= 1000) return `${(p / 1000).toFixed(1)}k€`;
  if (p >= 1) return `${p.toFixed(2)}€`;
  return `${p.toFixed(4)}€`;
}

exports.watchlistAlerts = onSchedule(
  { schedule: "every 60 minutes", region: "us-central1", timeoutSeconds: 300 },
  async () => {
    _cachedEurRate = null; // reset per-run cache
    const db = getFirestore();
    const messaging = getMessaging();

    // ── 1. Collect watchlist items for all PRO users that have unnotified targets
    const usersSnap = await db.collection("users").get();
    const allItems = [];

    await Promise.all(usersSnap.docs.map(async (userDoc) => {
      const userData = userDoc.data();
      if (!userData.isPro || !userData.fcmToken) return;

      const watchSnap = await db
        .collection("users").doc(userDoc.id)
        .collection("watchlist")
        .where("targetPrice", "!=", null)
        .get();

      for (const itemDoc of watchSnap.docs) {
        const d = itemDoc.data();
        // Skip if already notified for this target
        if (d.notifiedAt) continue;
        if (!d.targetPrice) continue;
        allItems.push({
          uid: userDoc.id,
          itemId: itemDoc.id,
          symbol: d.symbol,
          name: d.name || d.symbol,
          type: d.type || "stock",
          targetPrice: d.targetPrice,
          fcmToken: userData.fcmToken,
        });
      }
    }));

    if (allItems.length === 0) return;

    // ── 2. Fetch each unique symbol's price once (deduplication)
    const uniqueSymbols = [...new Set(allItems.map((i) => i.symbol))];
    const prices = {};

    await Promise.all(uniqueSymbols.map(async (symbol) => {
      const item = allItems.find((i) => i.symbol === symbol);
      const price = await _fetchSymbolPrice(symbol, item.type);
      if (price !== null) prices[symbol] = price;
    }));

    // ── 3. Check targets, send FCM, mark notifiedAt in batch
    const batch = db.batch();
    const sends = [];

    for (const item of allItems) {
      const price = prices[item.symbol];
      if (price == null || price < item.targetPrice) continue;

      // Send FCM push notification
      sends.push(
        messaging.send({
          token: item.fcmToken,
          notification: {
            title: `Kursziel erreicht: ${item.symbol}`,
            body: `${item.name} hat dein Ziel von ${_fmtPrice(item.targetPrice)} erreicht!`,
          },
          data: { type: "watchlist_alert", symbol: item.symbol },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
        }).catch(() => { /* ignore bad/expired tokens */ })
      );

      // Mark as notified so we don't fire again
      const ref = db
        .collection("users").doc(item.uid)
        .collection("watchlist").doc(item.itemId);
      batch.update(ref, { notifiedAt: FieldValue.serverTimestamp() });
    }

    await Promise.all([...sends, batch.commit()]);
  }
);

// ── Surge Radar ───────────────────────────────────────────────────────────────
//
// Scans ALL ~8,000 US-listed stocks daily using Polygon grouped daily bars.
// No sector filter — catches semiconductors, quantum computing, AI hardware,
// biotech, or any other field that suddenly surges.
// Cost: 5 API calls/day regardless of market size.
//
// Only stocks where at least one indicator is approaching or past a threshold
// are written to Firestore, keeping the collection to ~100–300 docs.

// Fetch grouped daily bars for a given date string "YYYY-MM-DD".
// Retries up to 4 prior calendar days to skip weekends/holidays.
async function _fetchGroupedBars(dateStr, apiKey) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const d = new Date(dateStr + "T12:00:00Z");
    d.setUTCDate(d.getUTCDate() - attempt);
    const ds = d.toISOString().split("T")[0];
    try {
      const resp = await axios.get(
        `https://api.polygon.io/v2/aggs/grouped/locale/us/market/stocks/${ds}`,
        { params: { adjusted: true, apiKey }, timeout: 30000 }
      );
      if ((resp.data.resultsCount ?? 0) > 0) {
        const map = {};
        for (const bar of resp.data.results) map[bar.T] = bar;
        console.log(`Grouped bars ${ds}: ${Object.keys(map).length} stocks`);
        return map;
      }
    } catch (e) {
      console.warn(`Grouped bars attempt ${attempt + 1} for ${ds}: ${e.message}`);
    }
    if (attempt < 4) await new Promise(r => setTimeout(r, 13000));
  }
  return {};
}

// ── Daily scan (Mon–Fri 17:00 ET) ─────────────────────────────────────────────

exports.dailyChipScan = onSchedule(
  {
    schedule: "0 17 * * 1-5",
    timeZone: "America/New_York",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "2GiB",
  },
  async () => {
    const db = getFirestore();
    const messaging = getMessaging();
    const apiKey = process.env.POLYGON_API_KEY;
    if (!apiKey) { console.error("POLYGON_API_KEY not set"); return; }

    const today = new Date().toISOString().split("T")[0];

    // ── 1. Collect FCM tokens (all users) ─────────────────────────────────────
    const usersSnap = await db.collection("users").get();
    const tokens = usersSnap.docs.map(d => d.data().fcmToken).filter(Boolean);

    // ── 2. Load persisted OHLCV state ─────────────────────────────────────────
    const state = await loadState();

    // ── 2b. Prune alertHistory docs older than 7 days ─────────────────────────
    // Runs on every daily scan, so old pre-Phase-5 entries are cleaned up on
    // the next scheduled run. Uses batched deletes to stay within Firestore limits.
    try {
      const sevenDaysAgo = new Date(today + 'T00:00:00Z');
      sevenDaysAgo.setUTCDate(sevenDaysAgo.getUTCDate() - 7);
      const oldAlertsSnap = await db.collection('chip_radar_alertHistory')
        .where('timestamp', '<', sevenDaysAgo)
        .get();
      if (oldAlertsSnap.docs.length > 0) {
        for (let i = 0; i < oldAlertsSnap.docs.length; i += 499) {
          const pruneBatch = db.batch();
          oldAlertsSnap.docs.slice(i, i + 499).forEach(d => pruneBatch.delete(d.ref));
          await pruneBatch.commit();
        }
        console.log(`Pruned ${oldAlertsSnap.docs.length} old alertHistory docs`);
      }
    } catch (e) {
      console.warn('alertHistory pruning failed (non-fatal):', e.message);
    }

    // ── 3. Fetch today's grouped bars (one API call) ───────────────────────────
    const todayBars = await _fetchGroupedBars(today, apiKey);
    if (Object.keys(todayBars).length === 0) {
      console.error("No bars returned for today — aborting");
      return;
    }
    console.log(`Fetched ${Object.keys(todayBars).length} bars for ${today}`);

    // ── 4. Append today's bars into state, trim to 260 days ───────────────────
    for (const [ticker, bar] of Object.entries(todayBars)) {
      if (!state.tickers[ticker]) state.tickers[ticker] = { bars: [] };
      const tickerBars = state.tickers[ticker].bars;
      if (tickerBars.length > 0 && tickerBars[tickerBars.length - 1].d === today) {
        // Overwrite if re-running the same day
        tickerBars[tickerBars.length - 1] = { d: today, o: bar.o, h: bar.h, l: bar.l, c: bar.c, v: bar.v };
      } else {
        tickerBars.push({ d: today, o: bar.o, h: bar.h, l: bar.l, c: bar.c, v: bar.v });
        if (tickerBars.length > 260) state.tickers[ticker].bars = tickerBars.slice(-260);
      }
    }

    // ── 5. Remove tickers not seen in last 10 days (delisted / dead) ──────────
    for (const ticker of Object.keys(state.tickers)) {
      if (!todayBars[ticker]) {
        const bars = state.tickers[ticker].bars;
        const lastBar = bars[bars.length - 1];
        if (daysBetween(lastBar.d, today) > 10) delete state.tickers[ticker];
      }
    }

    // ── 6. Pass 1 — hard-filter loop: collect allMetrics ─────────────────────
    // Same structural filters as before; no isInteresting check here.
    // Ranking (Pass 2) and scoring (Pass 3) happen after the full universe
    // has been assembled so each stock is ranked relative to all others.
    const allMetrics = [];

    for (const [ticker, { bars }] of Object.entries(state.tickers)) {
      if (!todayBars[ticker]) continue;
      if (bars.length < 2) continue;

      const todayClose = bars[bars.length - 1].c;
      if (todayClose < 15) continue;

      const vol = computeVolumeMetrics(bars);
      if (!vol) continue;
      if (vol.medDollarVol20 < 20_000_000) continue;
      if (vol.todayDollarVol  < 10_000_000) continue;
      if (vol.volRatio20 < 1.0) continue;

      const s = computeStructureMetrics(bars);
      if (!s) continue;

      if (s.ch7d == null || s.ch21d == null) continue;
      if (s.ch7d <= 0 || s.ch21d <= 0) continue;
      if (s.ch14d != null && s.ch14d <= 0) continue;

      if (s.sma20 && todayClose < s.sma20) continue;
      if (s.sma50 && todayClose < s.sma50) continue;
      if (bars.length >= 60 && s.sma20 && s.sma50 && s.sma20 < s.sma50) continue;
      if (s.sma20Slope != null && s.sma20Slope <= 0) continue;

      if (s.rangePosition252 != null && s.rangePosition252 < 0.60) continue;
      if (s.distFromHigh252  != null && s.distFromHigh252  < 0.75) continue;

      allMetrics.push({ ticker, s, vol, barsLength: bars.length, todayClose });
    }
    console.log(`Pass 1 survivors: ${allMetrics.length} tickers`);

    // ── 7. Pass 2 — assign relative-strength percentile ranks ─────────────────
    assignAllRanks(allMetrics);

    // ── 8. Pass 3 — score, wave-classify, cap output at 50 ────────────────────
    const MIN_LIST_SCORE  = 40;  // minimum to appear in Firestore list
    const MIN_ALERT_SCORE = 60;  // minimum to fire a push notification

    // Compute score and wave for every survivor, drop low-scorers
    const scoredMetrics = [];
    for (const m of allMetrics) {
      m.wave  = classifyWave(m.s, m.vol);
      m.score = computeSurgeScore(m.s, m.vol, m);
      if (m.score < MIN_LIST_SCORE) continue;
      scoredMetrics.push(m);
    }

    // Split by wave, sort by score desc within each group, cap each bucket
    const earlyBreakouts = scoredMetrics.filter(m => m.wave === "early")
      .sort((a, b) => b.score - a.score).slice(0, 15);
    const accumulating = scoredMetrics.filter(m => m.wave === "accumulating")
      .sort((a, b) => b.score - a.score).slice(0, 10);
    const running = scoredMetrics.filter(m => m.wave === "running")
      .sort((a, b) => b.score - a.score).slice(0, 15);
    const watching = scoredMetrics.filter(m => m.wave === "watching")
      .sort((a, b) => b.score - a.score).slice(0, 5);
    const extended = scoredMetrics.filter(m => m.wave === "extended")
      .sort((a, b) => b.score - a.score).slice(0, 5);

    // Final ordered list: max 50 stocks total
    const finalList = [...earlyBreakouts, ...accumulating, ...running, ...watching, ...extended];
    console.log(`Pass 3 — ${scoredMetrics.length} scored, ${finalList.length} in finalList (cap 50, score ≥ ${MIN_LIST_SCORE})`);

    // ── 9. Build scan entries and collect alert triggers ───────────────────────
    const scanEntries = [];
    const newAlerts   = [];

    finalList.forEach((m, idx) => {
      const { ticker, s, vol, todayClose, wave, score } = m;

      scanEntries.push({
        ticker,
        data: {
          ticker,
          price:             todayClose,
          change_1d:         s.ch1d    ?? 0,
          change_7d:         s.ch7d    ?? 0,
          change_14d:        s.ch14d   ?? 0,
          change_21d:        s.ch21d   ?? 0,
          change_63d:        s.ch63d   ?? 0,
          change_126d:       s.ch126d  ?? null,
          last_updated:      today,
          volume_ratio:      vol.volRatio20,
          volume_ratio_50:   vol.volRatio50  ?? null,
          median_dollar_vol: vol.medDollarVol20,
          today_dollar_vol:  vol.todayDollarVol,
          sma20:             s.sma20   ?? null,
          sma50:             s.sma50   ?? null,
          new_high_20:       s.newHigh20,
          new_high_55:       s.newHigh55,
          new_high_252:      s.newHigh252,
          range_position:    s.rangePosition252 ?? null,
          dist_from_high:    s.distFromHigh252  ?? null,
          close_location:    s.closeLocation,
          wave_label:        wave,
          score,
          score_rank:        idx + 1,
          rs21_rank:         m.rs21Rank  ?? null,
          rs63_rank:         m.rs63Rank  ?? null,
          rs126_rank:        m.rs126Rank ?? null,
        },
      });

      // Only collect alert triggers for high-conviction setups
      if (score < MIN_ALERT_SCORE) return;

      const triggers = [];
      if (s.ch1d != null && s.ch1d >= 10 && s.newHigh20)
        triggers.push({ label: "📈 Daily spike",         val: s.ch1d,         win: "1d"   });
      if (s.ch7d >= 20 && vol.volRatio20 >= 1.5)
        triggers.push({ label: "🔥 Weekly momentum",     val: s.ch7d,         win: "7d"   });
      if (s.ch7d >= 35 && s.newHigh55)
        triggers.push({ label: "🚨 Strong weekly surge", val: s.ch7d,         win: "7d_s" });
      if (s.ch14d != null && s.ch14d >= 40 && s.sma50 && todayClose > s.sma50)
        triggers.push({ label: "🚨 2-week surge",        val: s.ch14d,        win: "14d"  });
      if (s.ch21d != null && s.ch21d >= 60 && s.newHigh55)
        triggers.push({ label: "🆘 Major 3-week move",   val: s.ch21d,        win: "21d"  });
      if (vol.volRatio20 >= 2.5 && s.newHigh20)
        triggers.push({ label: "📊 Unusual volume",      val: vol.volRatio20, win: "vol"  });

      for (const t of triggers) {
        const alertKey = `${ticker}_${t.win}_${today}`;
        const sign = t.val >= 0 ? "+" : "";
        const body = t.win === "vol"
          ? `${ticker} Volumen ${t.val.toFixed(1)}× über dem 20-Tage-Median`
          : `${ticker} ${sign}${t.val.toFixed(1)}% (${t.win})`;

        newAlerts.push({
          key: alertKey,
          alertData: { ticker, label: t.label, window: t.win, value: t.val, price: todayClose, timestamp: FieldValue.serverTimestamp() },
          fcmTitle: `${t.label}: ${ticker}`,
          fcmBody:  body,
          ticker,
        });
      }
    });

    // ── 10. Write scan results — delete stale, write finalList ────────────────
    const freshTickers = new Set(finalList.map(m => m.ticker));

    const existingSnap = await db.collection("chip_radar_scanResults").get();
    const stale = existingSnap.docs.filter(d => !freshTickers.has(d.id));
    for (let i = 0; i < stale.length; i += 499) {
      const batch = db.batch();
      stale.slice(i, i + 499).forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
    console.log(`${stale.length} stale results deleted`);

    for (let i = 0; i < scanEntries.length; i += 499) {
      const chunk = scanEntries.slice(i, i + 499);
      const batch = db.batch();
      for (const { ticker, data } of chunk) {
        batch.set(db.collection("chip_radar_scanResults").doc(ticker), data);
      }
      await batch.commit();
    }
    console.log(`${scanEntries.length} scan results written`);

    // ── 11. Deduplicate alerts and write to Firestore ─────────────────────────
    let alertsFired = 0;
    for (const alert of newAlerts) {
      const ref = db.collection("chip_radar_alertHistory").doc(alert.key);
      if ((await ref.get()).exists) continue;
      await ref.set(alert.alertData);
      alertsFired++;
    }

    // ── 12. Send ONE summary push notification ────────────────────────────────
    if (alertsFired > 0 && tokens.length > 0) {
      const uniqueTickers = [...new Set(newAlerts.map(a => a.ticker))];
      const tickerPreview = uniqueTickers.slice(0, 3).join(", ");
      const moreCount = uniqueTickers.length > 3 ? ` +${uniqueTickers.length - 3} more` : "";
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: `📡 Chip Radar — ${alertsFired} neue Signale`,
          body:  `${tickerPreview}${moreCount} haben Schwellenwerte überschritten`,
        },
        data:    { route: "/chip-radar" },
        android: { priority: "high" },
        apns:    { payload: { aps: { sound: "default" } } },
      }).catch(e => console.error("FCM summary error:", e.message));
    }

    // ── 10. Persist updated state to Cloud Storage ────────────────────────────
    state.lastUpdatedDate = today;
    await saveState(state);

    console.log(`dailyChipScan complete — ${scanEntries.length} tickers, ${alertsFired} alerts fired.`);
  }
);
