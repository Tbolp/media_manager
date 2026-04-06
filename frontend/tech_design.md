# 家庭影院系统 · 前端技术方案文档

## 1. 技术选型

| 层次 | 选型 | 说明 |
|------|------|------|
| 框架 | React 18 + TypeScript | 生态成熟，TS 保障接口类型安全 |
| 构建工具 | Vite 5 | 极快的开发体验，开箱即用的 TS/React 支持 |
| 路由 | React Router v6 | 嵌套路由 + loader 模式，与 React 生态深度集成 |
| 状态管理 | Zustand | 轻量（<1KB），API 简洁，无 Provider 嵌套，适合小团队 |
| UI 组件库 | Ant Design 5 | 中文友好，组件覆盖全面（Table/Form/Modal/Tabs/Breadcrumb/Upload/Skeleton），开箱即用 |
| HTTP 客户端 | Axios | 拦截器机制成熟，上传进度回调原生支持 |
| 视频播放器 | xgplayer（西瓜播放器） | 字节跳动开源，中文文档完善，原生支持进度回调/自定义 UI/移动端适配 |
| 图片灯箱 | yet-another-react-lightbox | 轻量，支持缩放/滑动，React 组件化 |
| CSS 方案 | Ant Design 内置 Token + CSS Modules | 全局主题由 antd ConfigProvider 控制，业务样式用 CSS Modules 隔离 |
| 国际化 | 不引入 i18n 库 | 产品面向中文用户，文案直接硬编码中文字符串常量 |

### 选型理由

- **React 而非 Vue**：团队已有 React 经验；TypeScript 在 React 生态中类型推导更完整（Props/Hooks 泛型）；Ant Design for React 组件比 Ant Design Vue 更新更及时。
- **Zustand 而非 Redux**：本项目全局状态仅 auth + 少量 UI 状态，Zustand 的极简 API 避免了 Redux 的模板代码开销。
- **xgplayer 而非 video.js**：xgplayer 对国内网络环境优化更好，文档中文，包体更小，API 更简洁；原生支持移动端手势和进度回调。

---

## 2. 目录结构

```
frontend/
├── index.html
├── package.json
├── tsconfig.json
├── tsconfig.node.json
├── vite.config.ts
├── .env.development          # VITE_API_BASE=/api (dev proxy)
├── .env.production           # VITE_API_BASE=/api
├── public/
│   └── favicon.ico
└── src/
    ├── main.tsx              # React 入口，挂载 App
    ├── App.tsx               # 路由配置 + 全局 Layout
    ├── vite-env.d.ts
    │
    ├── api/                  # API 层
    │   ├── client.ts         # Axios 实例 + 请求/响应拦截器
    │   ├── types.ts          # 所有 API 请求/响应的 TypeScript 类型定义
    │   ├── auth.ts           # init / login / logout
    │   ├── users.ts          # 用户 CRUD + 权限
    │   ├── libraries.ts      # 媒体库 CRUD + 文件列表 + 刷新 + 上传
    │   ├── playback.ts       # 视频流 URL 构造 + 进度上报
    │   └── system.ts         # dashboard / tasks / logs
    │
    ├── stores/               # Zustand 状态管理
    │   ├── auth.ts           # token / user info / login status
    │   └── upload.ts         # 上传进度状态（per library）
    │
    ├── hooks/                # 自定义 Hooks
    │   ├── useAuth.ts        # 从 store 取 auth 状态的便捷 hook
    │   ├── usePolling.ts     # 通用轮询 hook（interval + cleanup）
    │   └── useProgress.ts    # 视频进度上报 hook
    │
    ├── components/           # 通用 UI 组件
    │   ├── AppLayout.tsx     # 全局布局（顶部导航栏 + 侧边栏 + 内容区）
    │   ├── AuthGuard.tsx     # 路由守卫组件（检查登录态）
    │   ├── AdminGuard.tsx    # 管理员路由守卫
    │   ├── RefreshStatus.tsx # 刷新状态条（可复用于首页卡片和详情页）
    │   └── FileIcon.tsx      # 文件类型图标
    │
    ├── pages/                # 页面组件
    │   ├── Init/
    │   │   └── index.tsx     # 系统初始化页
    │   ├── Login/
    │   │   └── index.tsx     # 登录页
    │   ├── Home/
    │   │   ├── index.tsx     # 首页（媒体库列表）
    │   │   ├── LibraryCard.tsx
    │   │   └── CreateLibraryModal.tsx
    │   ├── Library/
    │   │   ├── index.tsx     # 媒体库详情（目录浏览）
    │   │   ├── FileList.tsx  # 文件/目录列表
    │   │   ├── DirBreadcrumb.tsx
    │   │   ├── SearchBar.tsx
    │   │   ├── UploadButton.tsx
    │   │   └── ImageLightbox.tsx
    │   ├── Player/
    │   │   └── index.tsx     # 视频播放页
    │   └── Admin/
    │       ├── Users/
    │       │   ├── index.tsx       # 用户管理
    │       │   ├── CreateUserModal.tsx
    │       │   ├── ResetPasswordModal.tsx
    │       │   └── PermissionPanel.tsx
    │       └── System/
    │           ├── index.tsx       # 系统运维（Tab 容器）
    │           ├── Dashboard.tsx
    │           ├── TaskCenter.tsx
    │           └── Logs.tsx
    │
    └── utils/
        ├── constants.ts      # 错误码映射、分页默认值等
        ├── format.ts         # 时长格式化、文件大小格式化
        └── path.ts           # 路径拼接/解析辅助函数
```

---

## 3. 核心架构设计

### 3.1 API 客户端层（`api/client.ts`）

创建 Axios 实例，配置请求/响应拦截器：

```typescript
// api/client.ts
import axios from 'axios';
import { useAuthStore } from '@/stores/auth';

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE, // "/api"
  timeout: 30000,
});

// 请求拦截器：注入 Authorization header
client.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 响应拦截器：统一错误处理
client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const errorCode = error.response.data?.error_code;
      useAuthStore.getState().handleUnauthorized(errorCode);
    }
    return Promise.reject(error);
  }
);

export default client;
```

**错误处理策略**：
- `401` → 清除 token，跳转 `/login`，根据 `error_code` 显示不同提示
- `403` → 页面级或操作级提示"无权访问"
- `409` → 上传并发冲突，提示"当前有上传任务进行中"
- `5xx` → 全局提示"服务异常，请稍后再试"
- 网络断开 → 全局提示"网络已断开"

### 3.2 Auth Store（`stores/auth.ts`）

```typescript
// stores/auth.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface User {
  id: string;
  username: string;
  role: 'admin' | 'user';
}

interface AuthState {
  token: string | null;
  user: User | null;
  isLoggedIn: boolean;
  isAdmin: boolean;

  setAuth: (token: string, user: User) => void;
  clearAuth: () => void;
  handleUnauthorized: (errorCode?: string) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      user: null,
      isLoggedIn: false,
      isAdmin: false,

      setAuth: (token, user) =>
        set({ token, user, isLoggedIn: true, isAdmin: user.role === 'admin' }),

      clearAuth: () =>
        set({ token: null, user: null, isLoggedIn: false, isAdmin: false }),

      handleUnauthorized: (errorCode) => {
        get().clearAuth();
        // 跳转逻辑由 AuthGuard 组件负责
        // 通过 event 或 zustand subscribe 触发
        const messages: Record<string, string> = {
          token_expired: '登录已过期，请重新登录',
          user_disabled: '账号已被停用，请联系管理员',
          user_deleted: '账号不存在，请联系管理员',
        };
        const msg = messages[errorCode ?? ''] ?? '登录已失效，请重新登录';
        // 使用 antd message 全局提示
        window.__AUTH_ERROR_MESSAGE__ = msg;
      },
    }),
    {
      name: 'auth-storage', // localStorage key
      partialize: (state) => ({ token: state.token, user: state.user }),
    }
  )
);
```

**Token 存储策略**：
- 使用 Zustand `persist` 中间件将 `token` 和 `user` 持久化到 `localStorage`。
- 不使用 `httpOnly cookie`（后端签发方式为 response body 返回 JWT）。
- 页面加载时从 `localStorage` 恢复，由 `AuthGuard` 验证是否有效。

### 3.3 路由配置与守卫

```typescript
// App.tsx
import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';

const router = createBrowserRouter([
  {
    path: '/init',
    element: <InitPage />,
    // 无守卫，页面内部自行检查是否有用户
  },
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    // 需登录的路由
    element: <AuthGuard><AppLayout /></AuthGuard>,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'library/:id', element: <LibraryPage /> },
      { path: 'library/:id/play/:fid', element: <PlayerPage /> },
      {
        // 需管理员的路由
        path: 'admin',
        element: <AdminGuard />,
        children: [
          { path: 'users', element: <UsersPage /> },
          { path: 'system', element: <SystemPage /> },
        ],
      },
    ],
  },
  {
    path: '*',
    element: <Navigate to="/" replace />,
  },
]);
```

**路由守卫逻辑**：

```typescript
// components/AuthGuard.tsx
function AuthGuard({ children }: { children: React.ReactNode }) {
  const { isLoggedIn } = useAuthStore();
  const location = useLocation();

  if (!isLoggedIn) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <>{children}</>;
}

// components/AdminGuard.tsx
function AdminGuard() {
  const { isAdmin } = useAuthStore();
  if (!isAdmin) {
    message.warning('无权访问');
    return <Navigate to="/" replace />;
  }
  return <Outlet />;
}
```

**`/init` 页面访问控制**：
- `/init` 页面在 mount 时调用一个轻量接口（如 `POST /api/init` 本身会返回 403/409 当已有用户时），或专用检查接口。
- 若系统已有用户 → 自动跳转 `/login`。
- 实现方式：页面 mount 时尝试调用后端，由返回状态码决定是否渲染表单。

### 3.4 通用轮询 Hook

```typescript
// hooks/usePolling.ts
import { useEffect, useRef } from 'react';

export function usePolling(
  callback: () => Promise<boolean>, // 返回 true 表示继续轮询
  intervalMs: number,
  enabled: boolean = true,
) {
  const savedCallback = useRef(callback);
  savedCallback.current = callback;

  useEffect(() => {
    if (!enabled) return;

    let timeoutId: ReturnType<typeof setTimeout>;
    let cancelled = false;

    const poll = async () => {
      if (cancelled) return;
      try {
        const shouldContinue = await savedCallback.current();
        if (shouldContinue && !cancelled) {
          timeoutId = setTimeout(poll, intervalMs);
        }
      } catch {
        // 出错后仍继续轮询
        if (!cancelled) {
          timeoutId = setTimeout(poll, intervalMs);
        }
      }
    };

    poll();
    return () => {
      cancelled = true;
      clearTimeout(timeoutId);
    };
  }, [intervalMs, enabled]);
}
```

> 使用 `setTimeout` 递归而非 `setInterval`，确保上一次请求完成后才开始下一次倒计时，避免请求堆积。

---

## 4. 逐页实现策略

### 4.1 初始化页 `/init`（`pages/Init/index.tsx`）

**组件结构**：
- 居中卡片布局，Ant Design `Form` 表单：用户名、密码、确认密码。
- 页面 mount 时调用 `POST /api/init` 的预检（或捕获已有用户的错误码），决定是否跳转 `/login`。

**交互逻辑**：
1. 前端校验：密码一致性检查。
2. 调用 `POST /api/init { username, password }`。
3. 成功 → `message.success('管理员账号创建成功')` → 跳转 `/login`。
4. 失败 → 根据错误提示（用户名已存在等）。

**实现方式**：页面 mount 时先调用 `GET /api/libraries`（无 token）会返回 401，但 `POST /api/init` 若已有用户会返回特定错误。更简洁的方案：直接渲染表单，提交时如果后端返回"已初始化"的错误则跳转 `/login`。

### 4.2 登录页 `/login`（`pages/Login/index.tsx`）

**组件结构**：
- 居中卡片布局，Ant Design `Form`：用户名、密码。
- 检查 URL 参数或 `window.__AUTH_ERROR_MESSAGE__` 显示 401 提示信息。

**交互逻辑**：
1. 调用 `POST /api/login { username, password }`。
2. 成功 → `authStore.setAuth(token, user)` → 跳转 `state.from || '/'`。
3. 失败 → 根据后端 `detail` 字段提示（"用户名或密码错误"、"账号已被停用"）。

### 4.3 首页 `/`（`pages/Home/index.tsx`）

**组件结构**：
```
HomePage
├── Header（标题 + 管理员：新建媒体库按钮）
├── LibraryCard[] （antd Card 网格）
│   ├── 名称、类型标签（视频/相机）
│   ├── RefreshStatus（刷新状态指示器）
│   └── 管理员：删除按钮
├── CreateLibraryModal（antd Modal + Form）
└── 空状态提示
```

**数据获取**：
- 调用 `GET /api/libraries`，返回带 `refresh_status` 的媒体库列表。
- 对 `refresh_status` 非 `idle` 的媒体库启动轮询（`usePolling`，4s 间隔），轮询 `GET /api/libraries` 检查状态变化。

**管理员操作**：
- 新建：`POST /api/libraries { name, path, lib_type }` → 成功后刷新列表，该卡片进入刷新状态。
- 删除：二次确认 `Modal.confirm` → `DELETE /api/libraries/{id}` → 刷新列表。

### 4.4 媒体库详情页 `/library/:id`（`pages/Library/index.tsx`）

**组件结构**：
```
LibraryPage
├── Header
│   ├── DirBreadcrumb（面包屑导航）
│   ├── SearchBar（关键字搜索）
│   ├── RefreshStatus（刷新状态条）
│   ├── 刷新按钮 + UploadButton
│   └── 管理员：改名按钮
├── FileList
│   ├── 目录项[]（文件夹图标 + 名称，点击进入子目录）
│   ├── 文件项[]
│   │   ├── 视频：文件名 + 时长 + 进度条/已看标记
│   │   └── 图片（相机类型）：缩略图 + 文件名
│   └── 分页器（antd Pagination）
├── ImageLightbox（图片灯箱，点击图片时弹出）
└── 空状态提示
```

**状态管理**（页面内 `useState`/`useReducer`）：
- `currentPath: string`（当前目录路径，从 URL search params `?path=` 读取）
- `searchQuery: string`（搜索关键字，从 URL search params `?q=` 读取）
- `page: number`
- `files: FileItem[]`、`dirs: string[]`

**数据获取**：
```typescript
// 使用 URL search params 同步目录路径和搜索状态
const [searchParams, setSearchParams] = useSearchParams();
const currentPath = searchParams.get('path') || '';
const searchQuery = searchParams.get('q') || '';

// 调用文件列表 API
const { data, isLoading } = useFileList(libraryId, {
  path: searchQuery ? undefined : currentPath,
  q: searchQuery || undefined,
  page,
  page_size: 30,
});
```

**目录导航**：
- 点击子目录 → `setSearchParams({ path: currentPath + '/' + dirName })`
- 面包屑点击 → `setSearchParams({ path: targetPath })`
- 路径变化触发重新请求文件列表

**搜索**：
- 输入关键字 → debounce 300ms → `setSearchParams({ q: keyword })`
- 搜索模式下隐藏面包屑和目录列表，文件项显示完整 `relative_path`

**刷新轮询**：
- 页面 mount 时获取媒体库刷新状态
- 非 `idle` 状态时启动轮询（`usePolling`，4s 间隔），`idle` 后自动刷新文件列表

### 4.5 视频播放页 `/library/:id/play/:fid`（`pages/Player/index.tsx`）

**组件结构**：
```
PlayerPage
├── xgplayer 播放器容器
└── 返回按钮（回到媒体库详情页）
```

**播放器集成**：
```typescript
import Player from 'xgplayer';

useEffect(() => {
  const player = new Player({
    el: playerRef.current,
    url: `/api/files/${fid}/stream`,
    // 从上次进度续播
    startTime: initialProgress?.position || 0,
    // 播放器配置
    playbackRate: [0.5, 0.75, 1, 1.25, 1.5, 2],
    volume: 0.8,
  });

  return () => player.destroy();
}, [fid]);
```

**进度上报**（详见 5.3 节）：
- 定时上报（每 15 秒）+ 离开时上报（`beforeunload` / `visibilitychange`）。
- 使用 `fetch` with `keepalive: true` 作为离开时的方案。

**错误处理**：
- 404 → 提示"文件不存在或已移除"，3 秒后跳回媒体库页
- 其他错误 → 提示"播放失败，请稍后再试"

### 4.6 用户管理页 `/admin/users`（`pages/Admin/Users/index.tsx`）

**组件结构**：
```
UsersPage
├── Header（标题 + 新建用户按钮）
├── antd Table
│   ├── 列：用户名、角色、状态、创建时间、操作
│   └── 操作：禁用/解禁、重置密码、删除、展开权限
├── 展开行：PermissionPanel（媒体库白名单 Checkbox 列表）
├── CreateUserModal
└── ResetPasswordModal
```

**权限配置**：
- 展开用户行 → 加载全部媒体库列表 + 用户当前白名单
- 使用 antd `Checkbox.Group`，勾选变化时立即调用 `PUT /api/users/{id}/permissions`
- 静默保存，无需确认按钮

**操作保护**：
- 当前管理员自己的"禁用"和"删除"按钮设为 `disabled`
- 禁用操作前弹出 `Modal.confirm` 确认

### 4.7 系统运维页 `/admin/system`（`pages/Admin/System/index.tsx`）

**组件结构**：
```
SystemPage
├── antd Tabs
│   ├── Tab 1: Dashboard
│   │   ├── 媒体总数统计卡片
│   │   └── 用户活跃状态表格（用户名 + 最近活跃时间）
│   ├── Tab 2: TaskCenter
│   │   └── 各媒体库的任务状态列表
│   │       ├── 媒体库名称
│   │       ├── 当前执行中任务
│   │       ├── 待执行任务队列
│   │       └── 最近完成任务
│   └── Tab 3: Logs
│       ├── 关键字筛选输入框
│       ├── antd Table（时间 + 描述）
│       └── antd Pagination
```

**任务中心**：
- 调用 `GET /api/system/tasks`
- 有非 idle 状态时启动轮询（4s 间隔），全部完成后停止

**日志**：
- 调用 `GET /api/system/logs?q=keyword&page=1&page_size=30`
- 关键字输入 debounce 500ms 后触发查询

---

## 5. 关键实现细节

### 5.1 JWT Token 管理

**存储**：`localStorage` via Zustand persist middleware。

**注入**：Axios 请求拦截器从 Zustand store 读取 token，写入 `Authorization: Bearer <token>`。

**失效处理**：
```
响应 401
  → 拦截器读取 error_code
  → authStore.handleUnauthorized(errorCode)
     → 清除 token/user
     → 记录提示消息
  → AuthGuard 检测到 isLoggedIn=false
     → Navigate to /login
  → Login 页面读取提示消息并展示
```

**不做 Token 刷新**：后端未设计 refresh token 机制，JWT 过期后用户需重新登录。Token 有效期由后端 `TOKEN_EXPIRE` 环境变量控制。

### 5.2 文件上传与进度

```typescript
// api/libraries.ts
export async function uploadFile(
  libraryId: string,
  file: File,
  path: string,
  onProgress: (percent: number) => void,
  signal?: AbortSignal,
): Promise<void> {
  await client.post(
    `/libraries/${libraryId}/upload`,
    file, // 直接发送 File 对象作为 body（application/octet-stream）
    {
      params: { path },
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': `attachment; filename="${encodeURIComponent(file.name)}"`,
      },
      onUploadProgress: (e) => {
        if (e.total) {
          onProgress(Math.round((e.loaded / e.total) * 100));
        }
      },
      signal,
    },
  );
}
```

**UI 层**：
- `UploadButton` 组件使用 `<input type="file" accept=".mp4">` （视频库）或 `accept=".mp4,.jpg,.png"`（相机库）。
- 上传中显示 antd `Progress` 进度条，禁用上传按钮。
- 上传成功 → 触发文件列表刷新（上传后后端自动推入定向刷新任务，前端启动轮询等待 idle）。
- `409` → 提示"当前有上传任务进行中，请等待完成后再上传"。
- 上传失败 → 提示"上传失败，请重试"，显示重试按钮。

**Upload Store**：
```typescript
// stores/upload.ts
interface UploadState {
  uploads: Record<string, {  // key: libraryId
    fileName: string;
    progress: number;       // 0-100
    status: 'uploading' | 'success' | 'failed';
    abortController?: AbortController;
  }>;
  startUpload: (libraryId: string, fileName: string, ac: AbortController) => void;
  updateProgress: (libraryId: string, progress: number) => void;
  finishUpload: (libraryId: string, status: 'success' | 'failed') => void;
  clearUpload: (libraryId: string) => void;
}
```

### 5.3 视频进度上报

```typescript
// hooks/useProgress.ts
export function useProgressReporter(fid: string) {
  const playerRef = useRef<Player | null>(null);
  const lastReportedRef = useRef<number>(0);

  // 定时上报（每 15 秒）
  useEffect(() => {
    const timer = setInterval(() => {
      const player = playerRef.current;
      if (player && !player.paused) {
        reportProgress(fid, player.currentTime, player.duration);
        lastReportedRef.current = player.currentTime;
      }
    }, 15000);
    return () => clearInterval(timer);
  }, [fid]);

  // 离开时上报
  useEffect(() => {
    const report = () => {
      const player = playerRef.current;
      if (!player) return;
      const token = useAuthStore.getState().token;
      const body = JSON.stringify({
        position: player.currentTime,
        duration: player.duration,
      });
      const url = `/api/files/${fid}/progress`;

      // 优先使用 fetch + keepalive（支持自定义 Header）
      try {
        fetch(url, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
          },
          body,
          keepalive: true,
        });
      } catch {
        // fallback: 同步 XHR（已废弃但浏览器仍支持）
        const xhr = new XMLHttpRequest();
        xhr.open('PUT', url, false);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        xhr.send(body);
      }
    };

    const onVisibilityChange = () => {
      if (document.visibilityState === 'hidden') report();
    };

    window.addEventListener('beforeunload', report);
    document.addEventListener('visibilitychange', onVisibilityChange);

    return () => {
      report(); // 组件卸载时也上报（路由跳转场景）
      window.removeEventListener('beforeunload', report);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [fid]);

  return playerRef;
}
```

**API 调用**：
```typescript
// 常规定时上报（axios，异步）
function reportProgress(fid: string, position: number, duration: number) {
  client.put(`/files/${fid}/progress`, { position, duration }).catch(() => {
    // 静默失败，不打扰用户
  });
}
```

### 5.4 目录浏览与面包屑

**路径状态同步到 URL**：
```typescript
// pages/Library/index.tsx
const [searchParams, setSearchParams] = useSearchParams();
const currentPath = searchParams.get('path') ?? '';

// 进入子目录
const enterDir = (dirName: string) => {
  const newPath = currentPath ? `${currentPath}/${dirName}` : dirName;
  setSearchParams({ path: newPath });
};

// 面包屑点击
const navigateTo = (targetPath: string) => {
  setSearchParams(targetPath ? { path: targetPath } : {});
};
```

**面包屑组件**：
```typescript
// pages/Library/DirBreadcrumb.tsx
function DirBreadcrumb({ libraryName, currentPath, onNavigate }: Props) {
  const segments = currentPath ? currentPath.split('/') : [];

  const items = [
    { title: libraryName, onClick: () => onNavigate('') }, // 根目录
    ...segments.map((seg, i) => ({
      title: seg,
      onClick: () => onNavigate(segments.slice(0, i + 1).join('/')),
    })),
  ];

  return <Breadcrumb items={items} />;
}
```

**路径变化时重新请求文件列表**（通过 `useEffect` 依赖 `currentPath` + `page`）。

### 5.5 关键字搜索

```typescript
// pages/Library/SearchBar.tsx
function SearchBar({ onSearch }: { onSearch: (q: string) => void }) {
  const [value, setValue] = useState('');

  // debounce 300ms
  const debouncedSearch = useMemo(
    () => debounce((q: string) => onSearch(q), 300),
    [onSearch],
  );

  return (
    <Input.Search
      placeholder="搜索文件名..."
      value={value}
      onChange={(e) => {
        setValue(e.target.value);
        debouncedSearch(e.target.value);
      }}
      onSearch={onSearch}
      allowClear
    />
  );
}
```

搜索时：
- `setSearchParams({ q: keyword })`（清除 `path` 参数）
- API 调用 `GET /api/libraries/{id}/files?q=keyword&page=1&page_size=30`
- 搜索结果中文件显示完整 `relative_path`，点击视频跳转播放页，点击图片打开灯箱

### 5.6 图片灯箱

```typescript
// pages/Library/ImageLightbox.tsx
import Lightbox from 'yet-another-react-lightbox';
import Zoom from 'yet-another-react-lightbox/plugins/zoom';
import 'yet-another-react-lightbox/styles.css';

function ImageLightbox({ images, index, open, onClose }: Props) {
  const slides = images.map((img) => ({
    src: `/api/files/${img.id}/raw`, // 原图接口
  }));

  return (
    <Lightbox
      open={open}
      close={onClose}
      index={index}
      slides={slides}
      plugins={[Zoom]}
    />
  );
}
```

**缩略图**：在文件列表中，图片类型文件使用 `<img src="/api/files/${fid}/thumbnail" />` 展示缩略图。添加 `loading="lazy"` 实现懒加载。

### 5.7 刷新状态轮询

```typescript
// components/RefreshStatus.tsx
function RefreshStatus({ libraryId, onRefreshComplete }: Props) {
  const [status, setStatus] = useState<'idle' | 'running' | 'pending'>('idle');

  usePolling(
    async () => {
      const res = await getLibraries();
      const lib = res.items.find((l) => l.id === libraryId);
      const newStatus = lib?.refresh_status ?? 'idle';
      setStatus(newStatus);
      if (newStatus === 'idle') {
        onRefreshComplete?.();
        return false; // 停止轮询
      }
      return true; // 继续轮询
    },
    4000, // 4秒间隔
    status !== 'idle', // 仅在非 idle 时轮询
  );

  if (status === 'idle') return null;
  return (
    <Alert
      type="info"
      showIcon
      message={status === 'running' ? '刷新中…' : '等待刷新…'}
      banner
    />
  );
}
```

**轮询触发时机**：
1. 页面 mount 时获取初始状态，非 idle 则启动轮询
2. 手动触发刷新后 → 设置 status 为 `pending`/`running`，启动轮询
3. 新建媒体库后 → 该卡片进入轮询
4. 轮询到 `idle` → 停止轮询 + 刷新文件列表

---

## 6. 全局交互实现

### 6.1 全局导航栏（`components/AppLayout.tsx`）

```typescript
function AppLayout() {
  const { user, isAdmin, clearAuth } = useAuthStore();
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      await logout(); // POST /api/logout
    } finally {
      clearAuth();
      navigate('/login');
    }
  };

  return (
    <Layout>
      <Layout.Header>
        <div className="logo">家庭影院</div>
        <Menu mode="horizontal" items={[
          { key: 'home', label: <Link to="/">媒体库</Link> },
          ...(isAdmin ? [
            { key: 'users', label: <Link to="/admin/users">用户管理</Link> },
            { key: 'system', label: <Link to="/admin/system">系统运维</Link> },
          ] : []),
        ]} />
        <Dropdown menu={{
          items: [{ key: 'logout', label: '登出', onClick: handleLogout }],
        }}>
          <span>{user?.username}</span>
        </Dropdown>
      </Layout.Header>
      <Layout.Content>
        <Outlet />
      </Layout.Content>
    </Layout>
  );
}
```

### 6.2 加载与错误状态

- **骨架屏**：首页卡片列表、文件列表在加载时使用 antd `Skeleton` 组件。
- **Loading**：操作按钮点击后显示 loading 状态（antd Button `loading` prop）。
- **全局错误**：Axios 拦截器中 5xx 错误使用 `message.error('服务异常，请稍后再试')`。
- **网络断开**：监听 `window.offline` 事件，使用 `notification.warning` 持久提示。

### 6.3 响应式适配

- 使用 antd 的 Grid 系统（`Row`/`Col` 的 `xs`/`sm`/`md`/`lg` 断点）。
- 首页卡片：PC 一行 4 列，平板 2 列，手机 1 列。
- 文件列表：PC 用表格视图（antd Table），手机用列表视图（antd List）。
- 视频播放器：全宽自适应，xgplayer 原生支持。
- 管理页面：PC 优先，移动端基础可用。

---

## 7. 构建与部署

### 7.1 Vite 配置

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8080', // Go 后端开发地址
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    // 分包策略
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-react': ['react', 'react-dom', 'react-router-dom'],
          'vendor-antd': ['antd', '@ant-design/icons'],
          'vendor-player': ['xgplayer'],
        },
      },
    },
  },
});
```

### 7.2 Docker 构建集成

前端在 Dockerfile multi-stage build 中构建：

```dockerfile
# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

# Stage 2: Build backend
FROM golang:1.22-alpine AS backend-builder
WORKDIR /app/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ .
RUN CGO_ENABLED=0 go build -o server ./cmd/server

# Stage 3: Runtime
FROM alpine:3.19
RUN apk add --no-cache nginx ffmpeg

# Copy backend binary
COPY --from=backend-builder /app/backend/server /usr/local/bin/server

# Copy frontend static files
COPY --from=frontend-builder /app/frontend/dist /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy migrations
COPY backend/migrations /app/migrations

EXPOSE 80
CMD ["sh", "-c", "nginx && server"]
```

### 7.3 nginx 配置

```nginx
server {
    listen 80;

    # Frontend static files
    root /usr/share/nginx/html;
    index index.html;

    # SPA fallback - all non-API, non-static routes serve index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to Go backend
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Disable buffering for streaming (video/upload)
        proxy_buffering off;

        # No body size limit (for file upload)
        client_max_body_size 0;

        # Timeout for long uploads
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

### 7.4 开发流程

```bash
# 开发
cd frontend
npm install
npm run dev          # Vite dev server on :3000, proxy /api to :8080

# 构建
npm run build        # 输出到 frontend/dist/

# 类型检查
npm run typecheck    # tsc --noEmit

# Lint
npm run lint         # eslint
```

---

## 8. 依赖清单（package.json 主要依赖）

```json
{
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.23.0",
    "zustand": "^4.5.0",
    "antd": "^5.17.0",
    "@ant-design/icons": "^5.3.0",
    "axios": "^1.7.0",
    "xgplayer": "^3.0.0",
    "yet-another-react-lightbox": "^3.17.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.4.0",
    "vite": "^5.4.0",
    "eslint": "^8.57.0",
    "@typescript-eslint/eslint-plugin": "^7.0.0",
    "@typescript-eslint/parser": "^7.0.0",
    "eslint-plugin-react-hooks": "^4.6.0"
  }
}
```

---

## 9. API 类型定义概览（`api/types.ts`）

```typescript
// --- Common ---
export interface PaginatedResponse<T> {
  total: number;
  page: number;
  page_size: number;
  items: T[];
}

export interface ApiError {
  detail: string;
  error_code?: string;
}

// --- Auth ---
export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: {
    id: string;
    username: string;
    role: 'admin' | 'user';
  };
}

export interface InitRequest {
  username: string;
  password: string;
}

// --- Library ---
export type LibType = 'video' | 'camera';
export type RefreshStatus = 'idle' | 'running' | 'pending';

export interface Library {
  id: string;
  name: string;
  lib_type: LibType;
  refresh_status: RefreshStatus;
}

export interface CreateLibraryRequest {
  name: string;
  path: string;
  lib_type: LibType;
}

// --- Files ---
export type FileType = 'video' | 'image';

export interface FileItem {
  id: string;
  filename: string;
  relative_path: string;
  file_type: FileType;
  duration: number | null;   // seconds, null for images
  size: number | null;
  progress: number | null;   // 0.0-1.0, null for images
  is_watched: boolean | null;
}

export interface FileListResponse {
  path?: string;
  dirs?: string[];
  total: number;
  page: number;
  page_size: number;
  items: FileItem[];
}

// --- User ---
export interface User {
  id: string;
  username: string;
  role: 'admin' | 'user';
  is_disabled: boolean;
  library_ids: string[];
  created_at: string;
}

// --- System ---
export interface DashboardData {
  total_media_count: number;
  users: Array<{
    id: string;
    username: string;
    last_active_at: string | null;
  }>;
}

export interface TaskInfo {
  task_type: 'full' | 'targeted';
  target_file?: string;
  status: 'running' | 'pending' | 'success' | 'failed';
  started_at?: string;
  finished_at?: string;
  error?: string;
}

export interface LibraryTasks {
  library_id: string;
  library_name: string;
  current_task: TaskInfo | null;
  pending_tasks: TaskInfo[];
  recent_tasks: TaskInfo[];
}

export interface LogEntry {
  id: string;
  created_at: string;
  message: string;
}
```

---

## 10. 实现优先级

分 3 个阶段迭代实现：

### Phase 1：核心流程（可用）
1. 项目脚手架搭建（Vite + React + TS + Antd）
2. API 客户端 + Auth Store + 路由守卫
3. 初始化页 + 登录页
4. 首页（媒体库列表，含管理员的增删操作）
5. 媒体库详情页（目录浏览 + 面包屑 + 文件列表）
6. 视频播放页（基础播放 + 进度上报）

### Phase 2：完整功能
7. 文件上传（进度条 + 并发控制提示）
8. 手动刷新 + 轮询状态
9. 关键字搜索
10. 图片缩略图 + 灯箱
11. 用户管理页（CRUD + 权限配置）

### Phase 3：运维与优化
12. 系统运维页（仪表盘 + 任务中心 + 日志）
13. 骨架屏 / Loading 状态完善
14. 响应式适配
15. 错误处理完善（网络断开检测、403 跳转等）
