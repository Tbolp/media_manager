// lib/features/library/presentation/widgets/refresh_banner.dart
// 刷新进行中顶部横幅

import 'package:flutter/material.dart';

class RefreshBanner extends StatelessWidget {
  const RefreshBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            '正在刷新索引，文件列表可能未完整',
            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
