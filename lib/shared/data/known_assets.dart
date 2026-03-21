class KnownCrypto {
  final String name;
  final String symbol;
  final String? imageUrl;
  const KnownCrypto(this.name, this.symbol, {this.imageUrl});
}

class KnownEtf {
  final String name;
  final String ticker;
  final String type; // 'ETF' or 'Aktie'
  final String exchange;
  const KnownEtf(this.name, this.ticker, this.type, this.exchange);
}

class KnownCommodity {
  final String name;
  final String yahooTicker;
  final String emoji;
  const KnownCommodity(this.name, this.yahooTicker, this.emoji);
}

abstract class KnownAssets {
  static const List<KnownCrypto> cryptos = [
    KnownCrypto('Bitcoin', 'BTC'),
    KnownCrypto('Ethereum', 'ETH'),
    KnownCrypto('BNB', 'BNB'),
    KnownCrypto('Solana', 'SOL'),
    KnownCrypto('XRP', 'XRP'),
    KnownCrypto('Cardano', 'ADA'),
    KnownCrypto('Avalanche', 'AVAX'),
    KnownCrypto('Dogecoin', 'DOGE'),
    KnownCrypto('Polkadot', 'DOT'),
    KnownCrypto('Chainlink', 'LINK'),
    KnownCrypto('Polygon', 'MATIC'),
    KnownCrypto('Shiba Inu', 'SHIB'),
    KnownCrypto('Litecoin', 'LTC'),
    KnownCrypto('Bitcoin Cash', 'BCH'),
    KnownCrypto('Cosmos', 'ATOM'),
    KnownCrypto('Stellar', 'XLM'),
    KnownCrypto('NEAR Protocol', 'NEAR'),
    KnownCrypto('Uniswap', 'UNI'),
    KnownCrypto('Aave', 'AAVE'),
    KnownCrypto('Ethereum Classic', 'ETC'),
    KnownCrypto('VeChain', 'VET'),
    KnownCrypto('Filecoin', 'FIL'),
    KnownCrypto('Internet Computer', 'ICP'),
    KnownCrypto('Hedera', 'HBAR'),
    KnownCrypto('TRON', 'TRX'),
    KnownCrypto('Aptos', 'APT'),
    KnownCrypto('Algorand', 'ALGO'),
    KnownCrypto('Injective', 'INJ'),
    KnownCrypto('Sei', 'SEI'),
    KnownCrypto('Render', 'RNDR'),
  ];

  static const List<KnownEtf> etfsAndStocks = [
    // ── European ETFs (XETRA) ────────────────────────────────────────────────
    KnownEtf('Vanguard FTSE All-World Acc', 'VWCE.DE', 'ETF', 'XETRA'),
    KnownEtf('Vanguard FTSE All-World Dist', 'VGWL.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares Core MSCI World', 'EUNL.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares Core S&P 500', 'SXR8.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MSCI EM IMI Acc', 'IS3N.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MSCI EM (Dist)', 'IEMA.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares NASDAQ-100 Acc', 'IQQQ.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares Core MSCI ACWI', 'ISAC.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MSCI World Small Cap', 'IUSN.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MSCI World SRI', 'IQQW.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares STOXX Europe 600', 'EXV1.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares Core DAX', 'EXS1.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares TecDAX', 'EXXT.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MDAX', 'EXX1.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares Core Euro Stoxx 50', 'EXW1.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares Global Clean Energy', 'IQQH.DE', 'ETF', 'XETRA'),
    KnownEtf('Xtrackers MSCI World', 'XDWD.DE', 'ETF', 'XETRA'),
    KnownEtf('Xtrackers DAX', 'DBXD.DE', 'ETF', 'XETRA'),
    KnownEtf('Xtrackers MSCI EM Swap', 'XMEM.DE', 'ETF', 'XETRA'),
    KnownEtf('Xtrackers MSCI World Swap', 'DBXW.DE', 'ETF', 'XETRA'),
    KnownEtf('Xtrackers MSCI World Momentum', 'XDEM.DE', 'ETF', 'XETRA'),
    KnownEtf('Amundi MSCI World', 'LCUW.DE', 'ETF', 'XETRA'),
    KnownEtf('Amundi MSCI EM', 'AEEM.DE', 'ETF', 'XETRA'),
    KnownEtf('Amundi S&P 500', 'AMUN.DE', 'ETF', 'XETRA'),
    KnownEtf('Amundi MSCI World II', 'MWRD.DE', 'ETF', 'XETRA'),
    KnownEtf('Invesco NASDAQ 100 Acc', 'EQQQ.DE', 'ETF', 'XETRA'),
    KnownEtf('SPDR MSCI ACWI', 'SPYY.DE', 'ETF', 'XETRA'),
    KnownEtf('SPDR S&P 500 EUR Hdg', 'SPY5.DE', 'ETF', 'XETRA'),
    KnownEtf('WisdomTree Physical Gold', 'WGLD.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MSCI World Quality', 'IS3S.DE', 'ETF', 'XETRA'),
    KnownEtf('iShares MSCI World Value', 'IWVL.DE', 'ETF', 'XETRA'),
    KnownEtf('Lyxor MSCI World', 'LCWD.DE', 'ETF', 'XETRA'),
    // ── US ETFs ───────────────────────────────────────────────────────────────
    KnownEtf('Vanguard Total Stock Market', 'VTI', 'ETF', 'NYSE'),
    KnownEtf('Vanguard Total World', 'VT', 'ETF', 'NYSE'),
    KnownEtf('ARK Innovation', 'ARKK', 'ETF', 'NYSE'),
    // ── German Stocks ─────────────────────────────────────────────────────────
    KnownEtf('SAP', 'SAP.DE', 'Aktie', 'XETRA'),
    KnownEtf('Siemens', 'SIE.DE', 'Aktie', 'XETRA'),
    KnownEtf('Allianz', 'ALV.DE', 'Aktie', 'XETRA'),
    KnownEtf('BMW', 'BMW.DE', 'Aktie', 'XETRA'),
    KnownEtf('Mercedes-Benz', 'MBG.DE', 'Aktie', 'XETRA'),
    KnownEtf('Deutsche Telekom', 'DTE.DE', 'Aktie', 'XETRA'),
    KnownEtf('Adidas', 'ADS.DE', 'Aktie', 'XETRA'),
    KnownEtf('BASF', 'BAS.DE', 'Aktie', 'XETRA'),
    KnownEtf('Bayer', 'BAYN.DE', 'Aktie', 'XETRA'),
    KnownEtf('Volkswagen', 'VOW3.DE', 'Aktie', 'XETRA'),
    KnownEtf('Munich Re', 'MUV2.DE', 'Aktie', 'XETRA'),
    // ── US Stocks ─────────────────────────────────────────────────────────────
    KnownEtf('Apple', 'AAPL', 'Aktie', 'NASDAQ'),
    KnownEtf('Microsoft', 'MSFT', 'Aktie', 'NASDAQ'),
    KnownEtf('NVIDIA', 'NVDA', 'Aktie', 'NASDAQ'),
    KnownEtf('Alphabet (Google)', 'GOOGL', 'Aktie', 'NASDAQ'),
    KnownEtf('Amazon', 'AMZN', 'Aktie', 'NASDAQ'),
    KnownEtf('Meta', 'META', 'Aktie', 'NASDAQ'),
    KnownEtf('Tesla', 'TSLA', 'Aktie', 'NASDAQ'),
    KnownEtf('Netflix', 'NFLX', 'Aktie', 'NASDAQ'),
    KnownEtf('Berkshire Hathaway B', 'BRK-B', 'Aktie', 'NYSE'),
  ];

  static const List<KnownCommodity> commodities = [
    KnownCommodity('Gold', 'GC=F', '🥇'),
    KnownCommodity('Silber', 'SI=F', '🥈'),
    KnownCommodity('Platin', 'PL=F', '🔘'),
    KnownCommodity('Brent Crude Oil', 'BZ=F', '🛢️'),
  ];
}
