// lib/shared/widgets/network_banner.dart
// 网络状态横幅（断网时展示）

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_banner.g.dart';

@riverpod
Stream<bool> networkConnected(NetworkConnectedRef ref) {
  return Connectivity().onConnectivityChanged.map(
        (results) => results.any(
          (r) => r != ConnectivityResult.none,
        ),
      );
}

class NetworkBanner extends ConsumerWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(networkConnectedProvider);
    final isOffline = connected.valueOrNull == false;

    if (!isOffline) return const SizedBox.shrink();

    return Material(
      color: Colors.red[700],
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                '网络连接已断开',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
