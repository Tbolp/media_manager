// lib/features/player/presentation/providers/player_provider.dart
// 播放器相关状态（进度 API provider）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/progress_api.dart';

part 'player_provider.g.dart';

@riverpod
ProgressApi progressApi(ProgressApiRef ref) =>
    ProgressApi(ref.watch(dioClientProvider));
