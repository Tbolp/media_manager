# 家庭影院系统 · Flutter 移动端技术设计方案（Android）

> 范围：仅覆盖 Android 端，不考虑 iOS 特有 API 与 Keychain。

---

## 1. 技术选型

| 层次 | 方案 | 版本/说明 |
|------|------|-----------|
| 框架 | Flutter | 3.x stable |
| 状态管理 | Riverpod | `flutter_riverpod ^2.x`，配合 `riverpod_annotation` 代码生成 |
| 路由 | go_router | `go_router ^13.x`，支持路由守卫（redirect）|
| 网络 | Dio | `dio ^5.x`，封装拦截器 |
| 本地存储（Token） | flutter_secure_storage | Android KeyStore 存储 JWT |
| 本地存储（设置） | shared_preferences | 服务器地址、视图偏好等非敏感数据 |
| 视频播放 | media_kit + media_kit_video | `media_kit ^1.x`，基于 libmpv，支持 HTTP Range、手势控制 |
| 图片预览 | photo_view | `photo_view ^0.15.x`，手势缩放、双击放大 |
| 图片缓存 | cached_network_image | HTTP 缓存，与 Dio 独立，直接走 `HttpClient` |
| 列表虚拟化 | Flutter 原生 `ListView.builder` / `GridView.builder` | 按需渲染 |
| 骨架屏 | shimmer | `shimmer ^3.x` |
| 权限（亮度） | screen_brightness | Android 尽力而为，降级处理 |
| 音量手势 | volume_controller | Android 系统音量 |
| 网络状态 | connectivity_plus | 监听网络断开/恢复 |

> **为何选 media_kit 而非 video_player/chewie？**
> `video_player` 底层 Android 使用 ExoPlayer，对部分 H.264 high profile 或大码率 MP4 兼容性一般；`media_kit` 基于 libmpv，解码能力更强，且内置手势控制扩展点更友好。

---

## 2. 项目结构

```
lib/
├── main.dart
├── app.dart                    # MaterialApp + ProviderScope
├── core/
│   ├── constants.dart          # 全局常量
│   ├── exceptions.dart         # 业务异常类型
│   ├── router/
│   │   ├── app_router.dart     # go_router 定义 + redirect 守卫
│   │   └── routes.dart         # 路由常量
│   ├── network/
│   │   ├── dio_client.dart     # Dio 单例 + 拦截器组装
│   │   ├── auth_interceptor.dart
│   │   └── error_interceptor.dart
│   └── storage/
│       ├── secure_storage.dart # Token 读写
│       └── prefs_storage.dart  # SharedPreferences 封装
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_api.dart
│   │   │   └── auth_repository.dart
│   │   ├── domain/
│   │   │   └── user_model.dart
│   │   └── presentation/
│   │       ├── server_page.dart
│   │       ├── login_page.dart
│   │       └── providers/auth_provider.dart
│   ├── library/
│   │   ├── data/
│   │   │   ├── library_api.dart
│   │   │   └── library_repository.dart
│   │   ├── domain/
│   │   │   ├── library_model.dart
│   │   │   └── file_model.dart
│   │   └── presentation/
│   │       ├── home_page.dart
│   │       ├── library_detail_page.dart
│   │       ├── widgets/
│   │       │   ├── library_card.dart
│   │       │   ├── file_list_tile.dart
│   │       │   ├── file_grid_tile.dart
│   │       │   └── refresh_banner.dart
│   │       └── providers/
│   │           ├── library_provider.dart
│   │           └── directory_provider.dart
│   ├── player/
│   │   ├── data/
│   │   │   └── progress_api.dart
│   │   └── presentation/
│   │       ├── video_player_page.dart
│   │       ├── image_preview_overlay.dart
│   │       └── providers/player_provider.dart
│   └── settings/
│       └── providers/settings_provider.dart
└── shared/
    ├── widgets/
    │   ├── app_bar.dart
    │   ├── skeleton_list.dart
    │   ├── skeleton_grid.dart
    │   ├── empty_state.dart
    │   └── network_banner.dart
    └── utils/
        ├── url_builder.dart    # 拼接缩略图/原图 URL
        └── duration_format.dart
```

---

## 3. 路由设计

### 3.1 路由表

```dart
// routes.dart
const kRouteServer  = '/server';
const kRouteLogin   = '/login';
const kRouteHome    = '/';
const kRouteLibrary = '/library/:id';
const kRoutePlayer  = '/library/:id/play/:fid';
```

### 3.2 redirect 守卫逻辑

```
App 启动
  └─ 未配置服务器地址          → /server
  └─ 已配置，Token 为空         → /login
  └─ 已配置，Token 有效         → /（或目标页）

访问任意需鉴权页（非 /server、/login）
  └─ Token 为空 / 已过期（本地判断）→ /login

访问 /login 时已有 Token
  └─ redirect → /
```

守卫通过 `go_router` 的 `redirect` 回调实现，依赖 `authNotifierProvider`（Riverpod）。

### 3.3 目录下钻导航

媒体库详情页内目录切换**不使用路由跳转**，而是在页面内维护 `currentPath` 状态（`CurrentPathNotifier`，Riverpod code gen），面包屑和文件列表均响应此状态，避免 Android 返回栈过深。

---

## 4. 网络层

### 4.1 Dio 初始化

```dart
// dio_client.dart
Dio createDio(String baseUrl, Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
  dio.interceptors.addAll([
    AuthInterceptor(ref),   // 动态读取 token，不持有快照
    ErrorInterceptor(),
    LogInterceptor(requestBody: false, responseBody: false), // debug only
  ]);
  return dio;
}
```

Dio 实例通过 Riverpod `Provider` 管理，仅在服务器地址变更时重建（Token 由拦截器动态读取，无需重建）：

```dart
@riverpod
Dio dioClient(DioClientRef ref) {
  final baseUrl = ref.watch(
    settingsNotifierProvider.select((s) => s.serverUrl),
  );
  return createDio(baseUrl, ref);
}
```

### 4.2 AuthInterceptor

- 每个请求 Header 注入 `Authorization: Bearer <token>`。
- 响应 401 时，解析 `error_code`：
  - 清除本地 Token。
  - 通知 `authNotifierProvider` 状态变为未登录。
  - `go_router` 通过 `refreshListenable` 监听到状态变化，自动重定向到 `/login`，并携带对应错误消息参数。

### 4.3 缩略图 URL 构造

缩略图接口需要 token 作为 query 参数（避免自定义 Header 与图片组件不兼容）：

```dart
// url_builder.dart
String thumbnailUrl(String baseUrl, String fileId, String token) =>
    '$baseUrl/api/files/$fileId/thumbnail?token=$token';

String videoUrl(String baseUrl, String fileId, String token) =>
    '$baseUrl/api/files/$fileId/stream?token=$token';

String rawImageUrl(String baseUrl, String fileId, String token) =>
    '$baseUrl/api/files/$fileId/raw?token=$token';
```

---

## 5. 状态管理

### 5.1 全局状态（auth）

```dart
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<UserModel?> build() => const AsyncValue.data(null);

  Future<void> login(String username, String password) async { ... }
  Future<void> logout() async { ... }
  void forceLogout(String errorCode) { ... } // 由 AuthInterceptor 调用
}
```

Token 持久化到 `flutter_secure_storage`（Android KeyStore）。

### 5.2 服务器地址与视图偏好（SettingsNotifier）

服务器地址与视图偏好统一由 `SettingsNotifier` 管理，底层均走 `SharedPreferences`。`saveServerUrl` 只负责存储，清除 Token 等副作用由调用方 `server_page.dart` 处理。

```dart
@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  SettingsState build() => SettingsState(
    serverUrl: ref.read(prefsStorageProvider).getServerUrl() ?? '',
    libraryViewMode: ref.read(prefsStorageProvider).getViewMode() ?? ViewMode.list,
  );

  Future<void> saveServerUrl(String url) async {
    await ref.read(prefsStorageProvider).setServerUrl(url);
    state = state.copyWith(serverUrl: url);
  }

  Future<void> saveViewMode(ViewMode mode) async {
    await ref.read(prefsStorageProvider).setViewMode(mode);
    state = state.copyWith(libraryViewMode: mode);
  }
}
```

`server_page.dart` 保存地址时：
```dart
await ref.read(settingsNotifierProvider.notifier).saveServerUrl(url);
await ref.read(secureStorageProvider).deleteToken(); // 副作用在调用方处理
context.go('/login');
```

### 5.3 媒体库列表

```dart
@riverpod
Future<List<LibraryModel>> libraries(LibrariesRef ref) async {
  final repo = ref.read(libraryRepositoryProvider);
  return repo.getLibraries();
}
```

下拉刷新调用 `ref.invalidate(librariesProvider)`。

### 5.4 目录浏览

```dart
// 当前目录路径（页面内状态）
@riverpod
class CurrentPath extends _$CurrentPath {
  @override
  String build(String libraryId) => '';   // 空字符串 = 根目录

  void navigate(String path) => state = path;
  void pop() => state = _parentOf(state);
}

// 当前目录的内容
@riverpod
Future<DirectoryContent> directoryContent(
  DirectoryContentRef ref,
  String libraryId,
  String path,
) async {
  final repo = ref.read(libraryRepositoryProvider);
  return repo.listDirectory(libraryId, path);
}
```

### 5.5 刷新任务轮询

```dart
@riverpod
Stream<RefreshStatus> refreshStatus(
  RefreshStatusRef ref,
  String libraryId,
) async* {
  while (true) {
    final status = await ref.read(libraryRepositoryProvider)
        .getRefreshStatus(libraryId);
    yield status;
    if (!status.inProgress) break;
    await Future.delayed(const Duration(seconds: 5));
  }
}
```

媒体库详情页监听此 Stream，进行中则展示顶部横幅；完成后调用 `ref.invalidate(directoryContentProvider(...))`。

---

## 6. 各页面实现要点

### 6.1 服务器配置页

- 使用 `TextFormField` + `Form` 校验。
- 校验规则：`RegExp(r'^https?://.+[^/]$')`，前端 trim 末尾 `/`。
- 保存调用 `ref.read(settingsNotifierProvider.notifier).saveServerUrl(url)`，清除 Token 后 `context.go('/login')`。

### 6.2 登录页

- 密码框 `obscureText` + 眼睛图标切换。
- 登录按钮 Loading 期间禁用，防重复提交（`isLoading` 状态）。
- 底部展示服务器地址 + "修改"链接（`context.go('/server')`）。
- 后端返回系统未初始化时，展示 `AlertDialog` 引导使用 Web 端，不跳转。

### 6.3 首页（媒体库列表）

- `RefreshIndicator` 包裹 `ListView.builder`，下拉触发 `ref.invalidate(librariesProvider)`。
- 每张 `LibraryCard`：
  - 封面使用 `CachedNetworkImage`，`errorWidget` 展示类型占位图标。
  - 刷新图标区域用 `GestureDetector` 阻断点击冒泡（`behavior: HitTestBehavior.opaque`）。
  - 刷新图标 Loading 状态用本地 `ValueNotifier<bool>` 管理（不必全局状态）。
- 空状态：根据 `user.isAdmin` 展示不同文案。

### 6.4 媒体库详情页

**面包屑**

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: pathSegments.mapIndexed((i, seg) => [
      TextButton(onPressed: () => currentPathNotifier.navigate(seg.fullPath), ...),
      if (i < pathSegments.length - 1) const Icon(Icons.chevron_right),
    ]).expand((e) => e).toList(),
  ),
)
```

**列表渲染**

- 目录项置顶，文件项在下（后端接口排序，前端直接渲染）。
- 视频文件使用 `ListTile`，左侧 `CachedNetworkImage` 缩略图，右下角进度条用 `LinearProgressIndicator`。
- 相机库网格模式：`GridView.builder(crossAxisCount: 3)`，图片直接 `CachedNetworkImage`，视频封面叠加播放图标（`Stack + Icon(Icons.play_circle_outline)`）。
- 视图切换按钮：AppBar actions 中 `IconButton`，状态存入 `settingsNotifierProvider`（`SharedPreferences`），本次会话内保持；首页固定卡片列表，无切换选项。

**搜索**

- AppBar 展开搜索栏（`SearchAnchor` 或自定义 AnimatedContainer）。
- 搜索 Provider：

```dart
@riverpod
Future<List<FileModel>> searchFiles(
  SearchFilesRef ref,
  String libraryId,
  String keyword,
) async {
  if (keyword.isEmpty) return [];
  return ref.read(libraryRepositoryProvider).searchFiles(libraryId, keyword);
}
```

- 使用手动 `Timer` 300ms 防抖（`ref.debounce` 非 Riverpod 内置 API）。

### 6.5 视频播放页

**播放器初始化**

```dart
final player = Player();
final controller = VideoController(player);

player.open(Media(
  videoUrl(baseUrl, fileId, token),  // token 通过 query 参数传递
));
// 续播
if (progress != null && progress < 0.9) {
  player.seek(Duration(seconds: (progress * duration).round()));
}
```

**手势控制**（`GestureDetector` 覆盖在 `Video` widget 上）

| 手势 | 实现 |
|------|------|
| 单击中央 | 切换控制栏显示/隐藏 + 播放/暂停 |
| 双击左侧 | `player.seek(position - 15s)` |
| 双击右侧 | `player.seek(position + 15s)` |
| 水平滑动 | 计算偏移量→seek，展示目标时间预览 Overlay |
| 左侧竖滑 | `screen_brightness` 调节亮度 |
| 右侧竖滑 | `volume_controller` 调节音量 |
| 长按 | `player.setRate(2.0)`，松开恢复 `1.0` |

**进度上报时机**

```dart
// WidgetsBindingObserver
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    _reportProgress(); // fire-and-forget
  }
}

// 页面 dispose（返回键）
@override
void dispose() {
  _reportProgress();
  player.dispose();
  super.dispose();
}
```

进度达到 90% 时，单独调用"标记已看完"接口（或上报进度时由后端判断）。

**横屏处理**

```dart
// 进入播放页
SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

// 离开播放页 dispose
SystemChrome.setPreferredOrientations(DeviceOrientation.values);
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
```

竖屏提示：监听 `MediaQuery.of(context).orientation`，首次进入竖屏时弹出 `SnackBar`。

### 6.6 图片预览

- 非独立路由，使用 `showGeneralDialog`（全屏覆盖层）或 Navigator `push` 一个透明路由。
- `PageView.builder` 实现左右翻页，仅渲染当前页及相邻页（`PageController.keepPage`）。
- 每页 `PhotoView`：`imageProvider: CachedNetworkImageProvider(originalUrl)`，加载中展示缩略图 `placeholderWidget`。
- 视频文件在翻页序列中过滤（仅图片参与 `PageView`）。
- 单击隐藏/显示信息栏：`AnimatedOpacity` 包裹顶部信息栏。

---

## 7. 全局公共能力

### 7.1 网络断开横幅

```dart
// network_banner.dart
// 监听 connectivity_plus，网络断开时在 Stack 顶部展示横幅
@riverpod
Stream<List<ConnectivityResult>> connectivity(ConnectivityRef ref) =>
    Connectivity().onConnectivityChanged;
```

在 `app.dart` 根部 `Stack` 中叠加 `NetworkBanner`，响应 `connectivityProvider`。

### 7.2 401 全局处理

`AuthInterceptor.onError` 捕获 401，调用 `ref.read(authNotifierProvider.notifier).forceLogout(errorCode)`；`authNotifierProvider` 状态变更触发 `go_router` redirect 到 `/login`，并通过 `extra` 参数传递错误消息。

### 7.3 403 媒体库无权限

`ErrorInterceptor` 捕获 403，抛出 `ForbiddenException`；媒体库详情页 `AsyncValue.error` 分支展示提示 Dialog，确认后 `context.go('/')`。

### 7.4 骨架屏

列表加载中（`AsyncValue.loading`）展示 `ShimmerList`：

```dart
class ShimmerList extends StatelessWidget {
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => const _SkeletonTile(),
    ),
  );
}
```

---

## 8. 数据模型（简要）

```dart
class LibraryModel {
  final String id;
  final String name;
  final String type;       // 'video' | 'camera'
  final String? coverFileId;
}

class FileModel {
  final String id;
  final String name;
  final String relativePath;
  final String type;       // 'directory' | 'video' | 'image'
  final int? durationSeconds;  // 仅视频
  final double? progress;      // 播放进度 0.0~1.0，null 表示未播放
  final bool? watched;         // 是否已看完
}

class DirectoryContent {
  final List<FileModel> directories;
  final List<FileModel> files;
}
```

---

## 9. 本地存储规划

| 数据 | 存储方式 | Key |
|------|----------|-----|
| JWT Token | flutter_secure_storage | `auth_token` |
| 服务器地址 | SharedPreferences | `server_url` |
| 媒体库视图偏好（列表/网格） | SharedPreferences | `library_view_mode` |

---

## 10. Android 特定配置

### 10.1 AndroidManifest.xml

```xml
<!-- 网络权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<!-- 允许 HTTP 明文（局域网 http:// 地址） -->
<application android:usesCleartextTraffic="true" ...>
```

`android:usesCleartextTraffic="true"` 支持用户配置 `http://` 局域网地址。

### 10.2 视频播放 media_kit 配置

`android/app/build.gradle`：

```groovy
android {
    defaultConfig {
        minSdkVersion 21   // media_kit 要求
    }
}
```

`pubspec.yaml`：

```yaml
dependencies:
  media_kit: ^1.1.11
  media_kit_video: ^1.2.5
  media_kit_libs_video: ^1.0.5   # 包含 libmpv Android 预编译库
```

### 10.3 屏幕方向

`AndroidManifest.xml` 的 Activity 声明中不锁定方向（`android:screenOrientation="unspecified"`），由代码动态控制，播放页进入/离开时通过 `SystemChrome.setPreferredOrientations` 切换。

### 10.4 安全区域

使用 Flutter `SafeArea` 处理 Android 异形屏（打孔屏、水滴屏）刘海区域，视频播放全屏时控制栏改用 `Padding(padding: MediaQuery.of(context).viewPadding)` 避开系统 UI 区域。

---

## 11. 关键流程图

### 启动流程

```
App launch
  ↓
读取 SharedPreferences.serverUrl
  ├─ 为空 → navigate('/server')
  └─ 非空
       ↓
     读取 SecureStorage.token
       ├─ 为空 → navigate('/login')
       └─ 非空 → navigate('/')
```

### 视频播放与进度上报

```
点击视频文件
  ↓
navigate('/library/:id/play/:fid')
  ↓
拉取播放进度 GET /api/progress/:fid
  ↓
初始化 media_kit Player
  ├─ 有进度且 < 90% → seek 到上次位置
  └─ 无进度 / ≥ 90% → 从头播放
  ↓
播放中…
  ├─ 进度达 90% → 上报已看完
  └─ 任意退出时机 → 上报当前进度 POST /api/progress/:fid
```

### 401 处理流程

```
任意 API 响应 401
  ↓
AuthInterceptor 解析 error_code
  ↓
清除本地 Token（SecureStorage）
  ↓
authNotifier.forceLogout(errorCode)
  ↓
go_router redirect 触发 → navigate('/login?error=<errorCode>')
  ↓
LoginPage 读取 error query param → 展示对应提示文案
```

---

## 12. 待确认事项

| # | 问题 | 影响 |
|---|------|------|
| 1 | 缩略图接口是否支持 `?token=<jwt>` query 参数，还是只接受 Authorization Header？ | 决定 `CachedNetworkImage` 是否需要自定义 `httpHeaders` |
| 2 | 播放进度接口：上报（POST）和查询（GET）的具体路径和字段格式？ | 影响 `progress_api.dart` 实现 |
| 3 | 刷新任务状态查询接口（用于轮询）的路径和响应格式？ | 影响 `refreshStatus` Stream |
| 4 | `GET /api/libraries` 响应是否直接包含 `cover_file_id`？ | 影响封面图拼接逻辑 |
