// lib/shared/widgets/skeleton_grid.dart
// 网格骨架屏

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.crossAxisCount = 3, this.itemCount = 12});

  final int crossAxisCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => Container(
          color: Colors.white,
        ),
      ),
    );
  }
}
