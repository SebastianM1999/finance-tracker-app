const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
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

// ── Wave label (batch scan — RSI proxied by ch21d) ────────────────────────────
// ch21d correlates tightly with RSI: >75 ≈ RSI>75, >=50 ≈ RSI>=60, <50 ≈ RSI<65

function _waveLabel(ch7d, ch21d) {
  if (ch21d > 75)                       return "extended";
  if (ch7d >= 20 && ch21d >= 50)        return "running";
  if (ch7d >= 20 && ch21d < 50)         return "early";
  if (ch7d < 20)                        return "watching";
  return null;
}

// ── Technical indicator helpers ───────────────────────────────────────────────

function _calcRSI14(closes) {
  if (closes.length < 15) return null;
  let avgGain = 0, avgLoss = 0;
  for (let i = 1; i <= 14; i++) {
    const d = closes[i] - closes[i - 1];
    if (d > 0) avgGain += d; else avgLoss += Math.abs(d);
  }
  avgGain /= 14; avgLoss /= 14;
  for (let i = 15; i < closes.length; i++) {
    const d = closes[i] - closes[i - 1];
    avgGain = (avgGain * 13 + (d > 0 ? d : 0)) / 14;
    avgLoss = (avgLoss * 13 + (d < 0 ? Math.abs(d) : 0)) / 14;
  }
  if (avgLoss === 0) return 100;
  return Math.round((100 - 100 / (1 + avgGain / avgLoss)) * 10) / 10;
}

// MACD(12,26,9): returns { macd, signal, histogram, histogramSeries (last 10) }
// Needs at least 34 closes (26 for EMA26 + 9 for signal EMA — offset = 14 between them)
function _calcMACD(closes) {
  if (closes.length < 34) return null;

  function ema(data, period) {
    const k = 2 / (period + 1);
    let val = data.slice(0, period).reduce((s, v) => s + v, 0) / period;
    const result = [val];
    for (let i = period; i < data.length; i++) {
      val = data[i] * k + val * (1 - k);
      result.push(val);
    }
    return result;
  }

  const ema12    = ema(closes, 12);           // length: closes.length - 11
  const ema26    = ema(closes, 26);           // length: closes.length - 25
  const macdLine = ema26.map((v, i) => ema12[i + 14] - v); // aligned at closes[25+]
  const signalLine = ema(macdLine, 9);        // length: macdLine.length - 8

  const r = (v) => Math.round(v * 1000) / 1000;

  // Build histogram series (last 10 bars)
  const seriesStart = Math.max(0, signalLine.length - 10);
  const histogramSeries = [];
  for (let i = seriesStart; i < signalLine.length; i++) {
    histogramSeries.push(r(macdLine[i + 8] - signalLine[i]));
  }

  const macd      = r(macdLine[macdLine.length - 1]);
  const signal    = r(signalLine[signalLine.length - 1]);
  const histogram = histogramSeries[histogramSeries.length - 1];

  return { macd, signal, histogram, histogramSeries };
}

// ── getStockDetail ────────────────────────────────────────────────────────────
// Returns 52w high/low, RSI(14), MACD(12,26,9), analyst consensus + target price.

exports.getStockDetail = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
    const ticker = (req.query.ticker ?? "").trim().toUpperCase();
    if (!ticker) return res.status(400).json({ error: "Missing ticker" });

    const [quoteResp, chartResp] = await Promise.all([
      axios.get(
        `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${ticker}`,
        { headers: YAHOO_HEADERS, timeout: 10000 }
      ).catch(() => null),
      // 90 days gives enough bars for MACD(26) + signal(9) with room to spare
      axios.get(
        `${YAHOO_CHART_BASE}/${ticker}?range=90d&interval=1d`,
        { headers: YAHOO_HEADERS, timeout: 10000 }
      ).catch(() => null),
    ]);

    const q = quoteResp?.data?.quoteResponse?.result?.[0];
    if (!q) return res.status(502).json({ error: `No data from Yahoo for ${ticker}` });

    const closes = chartResp?.data?.chart?.result?.[0]
      ?.indicators?.quote?.[0]?.close?.filter(v => v != null) ?? [];

    return res.json({
      ticker,
      week52High:         q.fiftyTwoWeekHigh        ?? null,
      week52Low:          q.fiftyTwoWeekLow         ?? null,
      targetMeanPrice:    q.targetMeanPrice         ?? null,
      numberOfAnalysts:   q.numberOfAnalystOpinions ?? null,
      recommendationKey:  q.recommendationKey       ?? null,
      recommendationMean: q.recommendationMean      ?? null,
      rsi14:              _calcRSI14(closes),
      macd:               _calcMACD(closes),
    });
  }
);

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
    timeoutSeconds: 540,  // 9 min — grouped endpoint: 5 calls + 4×13s delay + Firestore writes
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const messaging = getMessaging();
    const apiKey = process.env.POLYGON_API_KEY;
    if (!apiKey) { console.error("POLYGON_API_KEY not set"); return; }

    // ── 1. Collect FCM tokens (all users) ─────────────────────────────────────
    const usersSnap = await db.collection("users").get();
    const tokens = usersSnap.docs.map(d => d.data().fcmToken).filter(Boolean);

    // ── 2. Fetch 5 grouped bar snapshots (all ~8,000 US stocks each) ──────────
    // Calendar offsets padded to skip weekends:
    //   offset 2  ≈ 1 trading day ago
    //   offset 11 ≈ 7 trading days ago
    //   offset 21 ≈ 14 trading days ago
    //   offset 31 ≈ 21 trading days ago
    const daysAgo = (n) => {
      const d = new Date();
      d.setDate(d.getDate() - n);
      return d.toISOString().split("T")[0];
    };
    const today = new Date().toISOString().split("T")[0];

    const barsToday = await _fetchGroupedBars(today,       apiKey);
    await new Promise(r => setTimeout(r, 13000));
    const bars1d    = await _fetchGroupedBars(daysAgo(2),  apiKey);
    await new Promise(r => setTimeout(r, 13000));
    const bars7d    = await _fetchGroupedBars(daysAgo(11), apiKey);
    await new Promise(r => setTimeout(r, 13000));
    const bars14d   = await _fetchGroupedBars(daysAgo(21), apiKey);
    await new Promise(r => setTimeout(r, 13000));
    const bars21d   = await _fetchGroupedBars(daysAgo(31), apiKey);

    console.log(`Processing ${Object.keys(barsToday).length} stocks`);

    // ── 3. Process every stock — keep only interesting ones ───────────────────
    const scanEntries = [];  // written to Firestore in batch
    const newAlerts   = [];  // deduplicated, then FCM sent

    for (const [ticker, b0] of Object.entries(barsToday)) {
      // ── Pre-filter: price, liquidity ─────────────────────────────────────
      if (b0.c < 15) continue;         // under $15 → skip (penny / micro cap)

      const b1  = bars1d[ticker];
      const b7  = bars7d[ticker];
      const b14 = bars14d[ticker];
      const b21 = bars21d[ticker];

      if (!b7) continue; // need at least 7d history to be useful

      const ch1d  = b1  ? (b0.c - b1.c)  / b1.c  * 100 : null;
      const ch7d  =        (b0.c - b7.c)  / b7.c  * 100;
      const ch14d = b14 ? (b0.c - b14.c) / b14.c * 100 : null;
      const ch21d = b21 ? (b0.c - b21.c) / b21.c * 100 : null;

      // Volume ratio: today vs average of the 4 historical snapshots
      const historicalVols = [b1, b7, b14, b21].filter(Boolean).map(b => b.v);
      const avgVol = historicalVols.length > 0
        ? historicalVols.reduce((s, v) => s + v, 0) / historicalVols.length
        : 0;
      const volR = avgVol > 0 ? b0.v / avgVol : 0;

      if (avgVol < 500000) continue;   // avg daily volume under 500k → too illiquid / micro cap
      if (volR < 1.0) continue;        // below average volume → skip

      // Only keep stocks where at least one alert threshold is actually crossed
      const isInteresting =
        (ch1d  != null && ch1d  >= 10) ||
        ch7d              >= 20        ||
        (ch14d != null && ch14d >= 40) ||
        (ch21d != null && ch21d >= 60) ||
        volR              >= 2.0;

      if (isInteresting) {
        scanEntries.push({
          ticker,
          data: {
            ticker,
            price:        b0.c,
            change_1d:    ch1d  ?? 0,
            change_7d:    ch7d,
            change_14d:   ch14d ?? 0,
            change_21d:   ch21d ?? 0,
            volume_ratio: volR,
            wave_label:   _waveLabel(ch7d, ch21d ?? 0),
            last_updated: today,
          },
        });
      }

      // Evaluate alert triggers
      const triggers = [];
      if (ch1d  != null && ch1d  >= 10) triggers.push({ label: "📈 Daily spike",         val: ch1d,  win: "1d"   });
      if (ch7d              >= 20)       triggers.push({ label: "🔥 Weekly momentum",     val: ch7d,  win: "7d"   });
      if (ch7d              >= 35)       triggers.push({ label: "🚨 Strong weekly surge", val: ch7d,  win: "7d_s" });
      if (ch14d != null && ch14d >= 40)  triggers.push({ label: "🚨 2-week surge",        val: ch14d, win: "14d"  });
      if (ch21d != null && ch21d >= 60)  triggers.push({ label: "🆘 Major 3-week move",   val: ch21d, win: "21d"  });
      if (volR              >= 2)        triggers.push({ label: "📊 Unusual volume",      val: volR,  win: "vol"  });

      for (const t of triggers) {
        const alertKey = `${ticker}_${t.win}_${today}`;
        const sign = t.val >= 0 ? "+" : "";
        const body = t.win === "vol"
          ? `${ticker} Volumen ${t.val.toFixed(1)}× über dem Durchschnitt`
          : `${ticker} ${sign}${t.val.toFixed(1)}% (${t.win})`;

        newAlerts.push({
          key: alertKey,
          alertData: { ticker, label: t.label, window: t.win, value: t.val, price: b0.c, timestamp: FieldValue.serverTimestamp() },
          fcmTitle: `${t.label}: ${ticker}`,
          fcmBody: body,
          ticker,
        });
      }
    }

    // ── 5. Write scan results in batches of 499 ───────────────────────────────
    const freshTickers = new Set(scanEntries.map(e => e.ticker));

    // Delete any docs from previous runs that no longer meet thresholds
    const existingSnap = await db.collection("chip_radar_scanResults").get();
    const stale = existingSnap.docs.filter(d => !freshTickers.has(d.id));
    for (let i = 0; i < stale.length; i += 499) {
      const batch = db.batch();
      stale.slice(i, i + 499).forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
    console.log(`${stale.length} stale results deleted`);

    // Write fresh results
    for (let i = 0; i < scanEntries.length; i += 499) {
      const chunk = scanEntries.slice(i, i + 499);
      const batch = db.batch();
      for (const { ticker, data } of chunk) {
        batch.set(db.collection("chip_radar_scanResults").doc(ticker), data);
      }
      await batch.commit();
    }
    console.log(`${scanEntries.length} scan results written`);

    // ── 6. Deduplicate alerts and write to Firestore ──────────────────────────
    let alertsFired = 0;
    for (const alert of newAlerts) {
      const ref = db.collection("chip_radar_alertHistory").doc(alert.key);
      if ((await ref.get()).exists) continue; // already fired today
      await ref.set(alert.alertData);
      alertsFired++;
    }

    // ── 7. Send ONE summary push notification ─────────────────────────────────
    if (alertsFired > 0 && tokens.length > 0) {
      const uniqueTickers = [...new Set(newAlerts.map(a => a.ticker))];
      const tickerPreview = uniqueTickers.slice(0, 3).join(", ");
      const moreCount = uniqueTickers.length > 3 ? ` +${uniqueTickers.length - 3} more` : "";
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: `📡 Chip Radar — ${alertsFired} neue Signale`,
          body: `${tickerPreview}${moreCount} haben Schwellenwerte überschritten`,
        },
        data: { route: "/chip-radar" },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
      }).catch(e => console.error("FCM summary error:", e.message));
    }

    console.log(`dailyChipScan complete — ${scanEntries.length} tickers, ${alertsFired} alerts fired.`);
  }
);
