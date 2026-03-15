import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';

/// A single shimmer card placeholder — matches the height of a list card.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 80});
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final highlight = isDark ? const Color(0xFF2E3648) : AppColors.lightBorder;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Full-screen shimmer list — shows N placeholder cards while data loads.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4, this.cardHeight = 80});
  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => ShimmerCard(height: cardHeight),
    );
  }
}

/// Shimmer banner — matches the gradient total banner at the top of screens.
class ShimmerBanner extends StatelessWidget {
  const ShimmerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final highlight = isDark ? const Color(0xFF2E3648) : AppColors.lightBorder;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        height: 72,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
