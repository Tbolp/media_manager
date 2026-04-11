// lib/features/cast/presentation/widgets/device_picker_sheet.dart
// DLNA 设备选择弹窗

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dlna_service.dart';
import '../providers/cast_provider.dart';

class DevicePickerSheet extends ConsumerStatefulWidget {
  const DevicePickerSheet({super.key});

  @override
  ConsumerState<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends ConsumerState<DevicePickerSheet> {
  late final DlnaService _dlna;
  StreamSubscription? _sub;
  Map<String, DlnaDevice> _devices = {};

  @override
  void initState() {
    super.initState();
    _dlna = ref.read(dlnaServiceProvider);
    _sub = _dlna.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    _dlna.startDiscovery();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dlna.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final castState = ref.watch(castNotifierProvider);
    final renderers =
        _devices.values.where((d) => d.isRenderer).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 拖拽手柄
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.cast),
                  const SizedBox(width: 12),
                  const Text(
                    '选择投屏设备',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_dlna.isDiscovering)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 已连接设备
            if (castState.isConnected) ...[
              ListTile(
                leading: Icon(Icons.cast_connected, color: Theme.of(context).colorScheme.primary),
                title: Text(castState.device!.friendlyName),
                subtitle: const Text('已连接'),
                trailing: TextButton(
                  onPressed: () {
                    ref.read(castNotifierProvider.notifier).disconnect();
                    Navigator.pop(context);
                  },
                  child: const Text('断开'),
                ),
              ),
              const Divider(height: 1),
            ],
            // 设备列表
            Expanded(
              child: renderers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cast,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '正在搜索设备...',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请确保手机和投屏设备在同一局域网',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: renderers.length,
                      itemBuilder: (context, index) {
                        final device = renderers[index];
                        final isConnected =
                            castState.device?.urlBase == device.urlBase;
                        return ListTile(
                          leading: Icon(
                            isConnected
                                ? Icons.cast_connected
                                : Icons.tv_outlined,
                            color: isConnected ? Theme.of(context).colorScheme.primary : null,
                          ),
                          title: Text(device.friendlyName),
                          subtitle: Text(
                            isConnected ? '已连接' : device.urlBase,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            ref
                                .read(castNotifierProvider.notifier)
                                .connectDevice(device);
                            Navigator.pop(context, device);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 显示设备选择弹窗，返回选中的设备（或 null）
Future<DlnaDevice?> showDevicePicker(BuildContext context) {
  return showModalBottomSheet<DlnaDevice>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const DevicePickerSheet(),
  );
}
