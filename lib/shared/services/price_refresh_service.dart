import '../../features/crypto/data/crypto_repository.dart';
import '../../features/crypto/models/crypto_position.dart';
import '../../features/etf_stocks/data/etf_repository.dart';
import '../../features/etf_stocks/models/etf_position.dart';
import '../../features/physical_assets/data/assets_repository.dart';
import '../../features/physical_assets/models/physical_asset.dart';
import 'price_service.dart';

class PriceRefreshService {
  const PriceRefreshService({
    required this.cryptoRepo,
    required this.etfRepo,
    required this.assetsRepo,
  });

  final CryptoRepository cryptoRepo;
  final EtfRepository etfRepo;
  final AssetsRepository assetsRepo;

  static const _commodityTickers = {
    'Gold': 'GC=F',
    'Silber': 'SI=F',
    'Platin': 'PL=F',
  };

  Future<int> refreshAll({
    required List<CryptoPosition> cryptoList,
    required List<EtfPosition> etfList,
    required List<PhysicalAsset> assetsList,
  }) async {
    int updated = 0;

    for (final pos in cryptoList) {
      final result =
          await PriceService.fetchCryptoPrice(pos.coinSymbol, pos.coinName);
      if (result != null) {
        await cryptoRepo.update(CryptoPosition(
          id: pos.id,
          exchange: pos.exchange,
          coinName: pos.coinName,
          coinSymbol: pos.coinSymbol,
          amount: pos.amount,
          buyPrice: pos.buyPrice,
          currentPrice: result.price,
          notes: pos.notes,
          createdAt: pos.createdAt,
        ));
        updated++;
      }
    }

    for (final pos in etfList) {
      if (pos.ticker == null) continue;
      final result = await PriceService.fetchStockOrEtfPrice(
        pos.ticker!,
        isEtf: pos.assetType == 'ETF',
      );
      if (result != null) {
        await etfRepo.update(EtfPosition(
          id: pos.id,
          broker: pos.broker,
          name: pos.name,
          ticker: pos.ticker,
          shares: pos.shares,
          buyPrice: pos.buyPrice,
          currentPrice: result.price,
          currency: pos.currency,
          assetType: pos.assetType,
          lastPriceUpdate: DateTime.now(),
          notes: pos.notes,
          createdAt: pos.createdAt,
        ));
        updated++;
      }
    }

    for (final asset in assetsList) {
      final ticker = _commodityTickers[asset.assetType];
      if (ticker == null) continue;
      final result = await PriceService.fetchCommodityPrice(ticker);
      if (result == null) continue;
      // quantity is stored in troy oz, result.price is per troy oz
      final double newValue = result.price * asset.quantity;
      await assetsRepo.update(PhysicalAsset(
        id: asset.id,
        assetType: asset.assetType,
        description: asset.description,
        quantity: asset.quantity,
        weightPerUnit: asset.weightPerUnit,
        buyPrice: asset.buyPrice,
        currentValue: newValue,
        notes: asset.notes,
        createdAt: asset.createdAt,
      ));
      updated++;
    }

    return updated;
  }
}
