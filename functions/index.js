const { onRequest } = require("firebase-functions/v2/https");
const axios = require("axios");

const FRANKFURTER_URL = "https://api.frankfurter.app/latest?from=USD&to=EUR";
const BINANCE_BASE = "https://api.binance.com/api/v3/ticker/price";
const YAHOO_BASE = "https://query1.finance.yahoo.com/v8/finance/chart";
const YAHOO2_BASE = "https://query2.finance.yahoo.com/v8/finance/chart";
const YAHOO_SEARCH_BASE = "https://query1.finance.yahoo.com/v1/finance/search";
const STOOQ_BASE = "https://stooq.com/q/l/";
const STOCKPRICES_BASE = "https://stockprices.dev/api";
const COINGECKO_SEARCH = "https://api.coingecko.com/api/v3/search";
const COINGECKO_PRICE = "https://api.coingecko.com/api/v3/simple/price";

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

// CoinGecko fallback: search for coin by symbol, then fetch EUR price
async function coingeckoPrice(symbol) {
  try {
    const searchRes = await axios.get(`${COINGECKO_SEARCH}?query=${encodeURIComponent(symbol)}`, {
      headers: { Accept: "application/json" }, timeout: 8000,
    });
    const coins = searchRes.data?.coins ?? [];
    // Pick the coin whose symbol exactly matches (case-insensitive)
    const coin = coins.find((c) => c.symbol?.toUpperCase() === symbol.toUpperCase());
    if (!coin?.id) return null;

    const priceRes = await axios.get(`${COINGECKO_PRICE}?ids=${coin.id}&vs_currencies=eur`, {
      headers: { Accept: "application/json" }, timeout: 8000,
    });
    const price = priceRes.data?.[coin.id]?.eur;
    return price != null ? { price, source: "CoinGecko" } : null;
  } catch { return null; }
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

        // Fallback: CoinGecko (covers coins not listed on Binance)
        const cgResult = await coingeckoPrice(sym);
        if (cgResult) return res.json(cgResult);

        return res.status(404).json({ error: "Price not found" });
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

        return res.status(404).json({ error: "Price not found" });
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
