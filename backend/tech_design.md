# 家庭影院系统 · 后端技术方案文档

## 1. 技术选型

| 层次 | 选型 | 说明 |
|------|------|------|
| 语言 | Go 1.22+ | 原生并发模型，编译为单二进制，部署简单 |
| Web 框架 | Gin | 成熟、高性能，中间件生态完善；内置流式响应支持 |
| 数据库驱动 | `modernc.org/sqlite`（纯 Go，无 CGO）+ `jmoiron/sqlx` | 零外部依赖，sqlx 提供结构体映射便利性；连接初始化时启用 WAL 模式 |
| 数据迁移 | goose（SQL 文件方式） | SQL 迁移文件版本化管理，语法直接 |
| 认证 | JWT（`golang-jwt/jwt/v5`）+ Argon2 密码哈希（`golang.org/x/crypto`） | JWT payload 携带版本号，实现 Token 即时失效 |
| 图片处理 | `disintegration/imaging` | 生成缩略图（约 400px 宽），缓存至磁盘 |
| 视频时长读取 | `ffprobe`（系统依赖，启动时强制检测） | 索引时读取 mp4 时长，未安装则拒绝启动 |
| 任务队列 | goroutine + `chan RefreshTask` | 每个媒体库一个独立 channel + goroutine worker，进程内串行执行 |
| 文件上传 | Gin `c.Request.Body` 流式写入 | 并发控制用 `sync.Mutex.TryLock()`（粒度：用户×媒体库） |
| 配置管理 | `godotenv` + `os.Getenv` | 统一管理 JWT_SECRET、TOKEN_EXPIRE 等 |

---

## 2. 目录结构

```
backend/
├── cmd/
│   └── server/
│       └── main.go              # 应用入口，初始化 DB、队列、路由，启动 Gin
├── internal/
│   ├── config/
│   │   └── config.go            # 配置加载（godotenv + os.Getenv）
│   ├── database/
│   │   ├── database.go          # DB 连接工厂（app.db / logs.db）
│   │   └── migrate.go           # goose 迁移执行
│   ├── middleware/
│   │   ├── auth.go                    # JWT 解析、token_version 校验、last_active_at 更新
│   │   ├── require_admin.go           # 管理员角色校验
│   │   └── require_library_access.go  # 白名单校验（admin 跳过）
│   ├── handlers/
│   │   ├── auth.go              # POST /init, POST /login, POST /logout
│   │   ├── users.go             # 用户管理（管理员操作）
│   │   ├── libraries.go         # 媒体库 CRUD + 文件列表
│   │   ├── upload.go            # 文件上传 + 手动刷新（路由挂载在 /api/libraries/{id}/ 下）
│   │   ├── playback.go          # 视频流、原图、缩略图（路由挂载在 /api/files/{fid}/ 下）
│   │   ├── behavior.go          # 进度上报、历史查询
│   │   └── system.go            # 仪表盘、任务中心、日志查询
│   ├── services/
│   │   ├── user_service.go
│   │   ├── library_service.go
│   │   ├── index_service.go     # 文件递归扫描、索引写入（保留 relative_path）、ffprobe 调用
│   │   ├── playback_service.go
│   │   ├── behavior_service.go
│   │   └── log_service.go
│   ├── models/
│   │   ├── user.go              # User
│   │   ├── library.go           # MediaLibrary, MediaFile
│   │   ├── behavior.go          # PlaybackProgress, WatchHistory
│   │   └── log.go               # Log
│   ├── queue/
│   │   └── queue_manager.go     # 刷新队列管理器（每库独立 channel + goroutine）
│   └── core/
│       ├── startup.go           # 启动时依赖检测（ffprobe）
│       ├── security.go          # JWT 签发/校验、Argon2 哈希
│       └── errors.go            # error_code 枚举、统一错误响应
├── migrations/
│   ├── app/
│   │   └── 00001_init.sql       # app.db 建表（goose 针对 app.db 连接执行）
│   └── logs/
│       └── 00001_init.sql       # logs.db 建表（goose 针对 logs.db 连接执行）
├── data/                        # SQLite 数据库文件（.gitignore）
├── thumbnails/                  # 缩略图磁盘缓存（.gitignore）
├── go.mod
├── go.sum
└── .env.example
```

---

## 3. 数据库设计

数据库拆分为两个 SQLite 文件，避免日志写入占用主库写锁：

| 文件 | 包含的表 |
|------|---------|
| `data/app.db` | users, media_libraries, media_files, playback_progress, watch_history |
| `data/logs.db` | logs |

> UUID 均为 v4，存储为 TEXT（36 字符），由应用层生成后写入数据库。

> 两个数据库均在连接初始化时执行 `PRAGMA journal_mode=WAL`，允许读写并发，避免刷新索引写入期间阻塞用户查询请求。

### 3.1 users

| 列 | 类型 | 说明 |
|----|------|------|
| id | TEXT PK | UUID v4 |
| username | TEXT NOT NULL | 应用层校验未删除用户中名称唯一 |
| password_hash | TEXT NOT NULL | Argon2 哈希 |
| role | TEXT NOT NULL | `admin` / `user` |
| is_disabled | BOOLEAN DEFAULT FALSE | |
| is_deleted | BOOLEAN DEFAULT FALSE | 软删除 |
| token_version | INTEGER DEFAULT 0 | 递增使已签发 Token 失效（密码修改/登出/禁用/删除时递增） |
| library_ids | TEXT NOT NULL DEFAULT '[]' | JSON 数组，存储白名单媒体库 ID；鉴权时联合 media_libraries.is_deleted 判断是否有效 |
| deleted_at | DATETIME NULL | |
| last_active_at | DATETIME NULL | 最近鉴权通过时间 |
| created_at | DATETIME | |

> 软删除后保留行（用于审计），用户名释放后可被新用户使用（应用层校验未删除用户中唯一）。
> 媒体库删除后不清理 library_ids，鉴权时判断 media_libraries.is_deleted 即可过滤失效 ID。

### 3.2 media_libraries

| 列 | 类型 | 说明 |
|----|------|------|
| id | TEXT PK | UUID v4 |
| name | TEXT NOT NULL | 应用层校验未删除库中名称唯一 |
| path | TEXT NOT NULL | 目录绝对路径，创建时校验存在且可读 |
| lib_type | TEXT NOT NULL | `video` / `camera` |
| is_deleted | BOOLEAN DEFAULT FALSE | 软删除，保留行供日志中库名关联 |
| created_at | DATETIME | |

### 3.3 media_files

| 列 | 类型 | 说明 |
|----|------|------|
| id | TEXT PK | UUID v4 |
| library_id | TEXT FK media_libraries.id | |
| filename | TEXT NOT NULL | 文件名（最后一个路径段，便于展示） |
| relative_path | TEXT NOT NULL | 相对于媒体库根目录的路径，如 `a/b/c.mp4`；绝对路径在运行时由 `media_libraries.path + relative_path` 拼接得到 |
| file_type | TEXT NOT NULL | `video` / `image` |
| duration | REAL NULL | 视频时长（秒），图片为 NULL |
| size | INTEGER NULL | 文件大小（字节） |
| indexed_at | DATETIME | |

UNIQUE (library_id, relative_path)

### 3.4 playback_progress

| 列 | 类型 | 说明 |
|----|------|------|
| id | TEXT PK | UUID v4 |
| user_id | TEXT FK users.id | |
| file_id | TEXT NOT NULL | 不设外键，媒体库删除后进度保留 |
| position | REAL NOT NULL | 当前播放秒数 |
| duration | REAL NOT NULL | 视频总时长（冗余，便于计算百分比） |
| is_watched | BOOLEAN DEFAULT FALSE | 进度达到 90% 后标记 |
| updated_at | DATETIME | |

UNIQUE (user_id, file_id)

### 3.5 watch_history

| 列 | 类型 | 说明 |
|----|------|------|
| id | TEXT PK | UUID v4 |
| user_id | TEXT FK users.id | |
| file_id | TEXT NOT NULL | 不设外键，媒体库删除后历史保留 |
| watched_at | DATETIME | 最新观看时间，多次观看用 upsert 更新 |

UNIQUE (user_id, file_id)

### 3.6 logs

所有日志（审计、刷新、上传、播放失败）统一写入单张表，支持关键字筛选：

| 列 | 类型 | 说明 |
|----|------|------|
| id | TEXT PK | UUID v4 |
| created_at | DATETIME NOT NULL | |
| message | TEXT NOT NULL | 自由格式描述，包含所有上下文信息 |

日志写入示例：
- 审计：`"管理员 admin 禁用用户 alice"`
- 刷新：`"媒体库 movies 全量刷新完成，共索引 42 个文件"`
- 上传：`"用户 alice 上传 foo.mp4 至媒体库 movies 失败：并发冲突"`
- 播放失败：`"用户 alice 播放文件 foo.mp4 失败：文件不存在"`

---

## 4. 认证与鉴权设计

### 4.1 JWT 结构

```json
{
  "sub": "用户ID（字符串）",
  "ver": 3,
  "exp": 1712345678
}
```

- `ver` 对应 `users.token_version`，每次需要使 Token 立即失效时递增该字段。
- 校验流程：解码 JWT → 检查 exp → 查用户行 → 按顺序判断：
  1. `is_deleted == true` → 返回 `user_deleted`
  2. `is_disabled == true` → 返回 `user_disabled`
  3. `ver != token_version` → 返回 `token_expired`
  4. 通过 → 更新 `last_active_at`，注入 User 到 Context

### 4.2 401 错误码约定

所有 401 响应体统一包含：
```json
{ "detail": "...", "error_code": "token_expired | user_disabled | user_deleted" }
```

- `token_expired`：JWT 过期，或版本号不匹配（含密码修改、登出后 Token 被重用等所有版本号递增场景）
- `user_disabled`：用户已禁用
- `user_deleted`：用户已删除

登出采用服务端递增版本号方式使 Token 立即失效，与密码修改共用同一机制。

### 4.3 权限中间件链

```
AuthMiddleware          → 解码 JWT，注入 User 到 gin.Context
RequireAdmin            → AuthMiddleware + 校验 role == admin
RequireLibraryAccess    → AuthMiddleware + 校验白名单（admin 跳过）
                          挂载在 /api/libraries/{id}/* 路由上，直接从路径参数取 library_id
                          挂载在 /api/files/{fid}/* 路由上时，需先查 media_files 取 library_id，再做白名单校验
```

---

## 5. 刷新队列设计

### 5.1 数据结构

```go
// queue/queue_manager.go

type RefreshTask struct {
    TaskType   string // "full" | "targeted"
    TargetFile string // targeted 时填写文件的 relative_path，worker 执行时拼接媒体库根目录得到绝对路径
}

type TaskStatus struct {
    TaskType   string    // "full" | "targeted"
    TargetFile string    // targeted 时填写 relative_path
    Status     string    // "running" | "success" | "failed"
    StartedAt  time.Time
    FinishedAt time.Time // 完成时填写
    Error      string    // 失败时填写
}

type LibraryQueue struct {
    ch             chan RefreshTask // 有缓冲 channel，容量足够大（如 64），避免持锁发送时阻塞
    cancel         context.CancelFunc
    mu             sync.Mutex
    hasPendingFull bool
    currentTask    *TaskStatus   // 当前执行中的任务，无任务时为 nil
    recentTasks    []TaskStatus  // 最近完成的任务（固定上限，如保留最近 20 条，FIFO 淘汰）
}

var (
    queues sync.Map      // key: libraryID (string) → *LibraryQueue
    wg     sync.WaitGroup // 追踪所有 worker goroutine，shutdown 时等待全部退出
)
```

### 5.2 入队逻辑

```
全量刷新入队：
  加锁 mu
  if hasPendingFull → 解锁，返回 queued=false（去重）
  else → 向 ch 发送任务，hasPendingFull=true，解锁，返回 queued=true

定向刷新入队：
  直接向 ch 发送任务（不合并）

媒体库删除：
  调用 cancel() → worker goroutine 检测到 ctx.Done() 后退出
```

### 5.3 Worker 执行流程

```go
func (lq *LibraryQueue) run(ctx context.Context, libraryID string) {
    for {
        select {
        case <-ctx.Done():
            // 写日志"媒体库已删除，剩余任务取消"
            return
        case task := <-lq.ch:
            // 加锁，设置 currentTask（Status="running", StartedAt=now），解锁
            // 执行索引（index_service.RunRefresh(ctx, ...)）— ctx 须透传，确保删库时 cancel() 可中断扫描
            // 加锁：
            //   若 task.TaskType == "full"：hasPendingFull=false
            //   将 currentTask 写入 recentTasks（更新 Status/FinishedAt/Error），currentTask=nil
            // 解锁
            // 写日志（完成/失败 + 简要结果）
        }
    }
}
```

> 注意：`hasPendingFull=false` 须在**执行完成后**才重置（不是取出任务时），以保证执行期间的新全量刷新请求同样被去重。

### 5.4 全量刷新索引清理

全量刷新不仅扫描新增/更新文件，还须清理磁盘已不存在的索引条目：
1. 递归扫描磁盘，收集当前存在的文件 `relative_path` 集合。
2. 新增/更新索引（UPSERT）。
3. 删除 `media_files` 表中 `library_id` 匹配但 `relative_path` 不在磁盘集合中的记录。

定向刷新仅索引指定文件，不做清理。

### 5.5 应用启动 / 关闭

- `startup`：为所有未删除的媒体库重建 `LibraryQueue`，启动 worker goroutine（channel 无消息时阻塞等待）。
- `shutdown`：调用所有队列的 `cancel()`，等待所有 worker goroutine 退出（用 `sync.WaitGroup`）。

---

## 6. 文件上传并发控制

```go
// 粒度：(userID, libraryID)
type uploadKey struct {
    UserID    string
    LibraryID string
}

var uploadLocks sync.Map // key: uploadKey → *sync.Mutex
```

- 请求进入时：`lock.TryLock()`（Go 1.18+）
  - 成功 → 执行上传，完成后 `lock.Unlock()`
  - 失败 → 返回 409
- 原子写入：流式写入临时文件（同目录下 `.tmp` 后缀），完成后 `os.Rename` 到目标路径；出错或中断时删除临时文件，避免磁盘残留不完整文件。
- 目标子目录（由 `path` 参数指定）在磁盘不存在时，服务端自动创建（`os.MkdirAll`），无需用户预先建目录。
- 路径穿越防护：拼接后的绝对路径须以媒体库根目录为前缀（`filepath.Join` + `filepath.Rel` 校验），不合法返回 400。
- 文件类型校验：服务端根据媒体库 `lib_type` 校验上传文件扩展名（视频类型库仅接受 `.mp4`，相机类型库接受 `.mp4`/`.jpg`/`.png`），不合规返回 400。

---

## 7. 关键接口一览

### 认证
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/init` | 系统初始化（创建管理员，仅无用户时可用） |
| POST | `/api/login` | 登录，返回 JWT |
| POST | `/api/logout` | 登出（递增 token_version） |

### 用户管理（需 admin）
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/users` | 用户列表 |
| POST | `/api/users` | 创建用户 |
| PATCH | `/api/users/{id}/disable` | 禁用用户 |
| PATCH | `/api/users/{id}/enable` | 解禁用户 |
| DELETE | `/api/users/{id}` | 删除用户（软删除，同时清理 playback_progress 和 watch_history 中该用户的记录） |
| PUT | `/api/users/{id}/password` | 重置密码 |
| PUT | `/api/users/{id}/permissions` | 更新白名单 |

### 媒体库
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/libraries` | 媒体库列表（含用户可见范围，每个库附带刷新状态） |
| POST | `/api/libraries` | 创建媒体库（admin） |
| PATCH | `/api/libraries/{id}` | 改名（admin） |
| DELETE | `/api/libraries/{id}` | 删除媒体库（admin，软删除库记录 + 硬删除该库全部 media_files + 清理 `thumbnails/{library_id}/` 缩略图缓存 + cancel 队列） |
| GET | `/api/libraries/{id}/files` | 目录浏览 + 文件列表（见下方说明） |
| POST | `/api/libraries/{id}/refresh` | 手动触发全量刷新 |
| POST | `/api/libraries/{id}/upload` | 上传文件（`Content-Type: application/octet-stream`，文件名通过 `Content-Disposition: attachment; filename="foo.mp4"` 请求头传递；`path` 查询参数指定目标子目录，如 `?path=a/b`，默认空表示根目录） |

**`GET /api/libraries` 响应结构：**
```json
{
  "items": [
    {
      "id": "...",
      "name": "movies",
      "lib_type": "video",
      "refresh_status": "idle"
    }
  ]
}
```
> `refresh_status` 取值：`idle`（无任务）、`running`（有任务执行中）、`pending`（仅有待执行任务）。从内存队列的 `currentTask` 和 `len(ch)` 推导。

**`GET /api/libraries/{id}/files` 查询参数：**
- `path`（可选）：当前目录路径前缀，如 `a/b`；不传或传空字符串表示根目录。
- `q`（可选）：关键字搜索，不为空时跨目录全局匹配 `filename`，忽略 `path` 参数。
- `page` / `page_size`：分页，含义同全局规范。

**响应结构（目录浏览模式，`q` 为空）：**
```json
{
  "path": "a/b",
  "dirs": ["c", "d"],
  "total": 5,
  "page": 1,
  "page_size": 30,
  "items": [
    { "id": "...", "filename": "foo.mp4", "relative_path": "a/b/foo.mp4", "file_type": "video", "duration": 120.5, "progress": 0.45, "is_watched": false }
  ]
}
```

**响应结构（关键字搜索模式，`q` 不为空）：**
```json
{
  "total": 2,
  "page": 1,
  "page_size": 30,
  "items": [
    { "id": "...", "filename": "foo.mp4", "relative_path": "a/b/foo.mp4", "file_type": "video", "duration": 120.5, "progress": 0.0, "is_watched": false }
  ]
}
```

> `dirs` 为当前层级下的直接子目录名列表（从 `relative_path` 推导）；`progress` 和 `is_watched` 来自当前用户的 `playback_progress`，图片文件两字段均为 null。

### 播放
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/files/{fid}/stream` | 视频流（支持 Range） |
| GET | `/api/files/{fid}/raw` | 原图 |
| GET | `/api/files/{fid}/thumbnail` | 缩略图（~400px，磁盘缓存） |

### 用户行为
| 方法 | 路径 | 描述 |
|------|------|------|
| PUT | `/api/files/{fid}/progress` | 上报播放进度 |
| GET | `/api/behavior/history` | 最近观看历史 |

### 系统运维（需 admin）
| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/system/dashboard` | 仪表盘（媒体总数、用户活跃时间） |
| GET | `/api/system/tasks` | 任务中心（从内存队列读取各库实时状态） |
| GET | `/api/system/logs` | 日志查询（分页，支持关键字筛选） |

---

## 8. 非功能性设计

### 8.1 错误响应规范

```json
{
  "detail": "人类可读描述",
  "error_code": "可选，机器可读枚举"
}
```

标准 HTTP 状态码：
- `400` 参数错误（含媒体库路径不存在或不可读、请求体解析/校验失败）
- `401` 未认证（含 `error_code`）
- `403` 权限不足
- `404` 资源不存在
- `409` 并发冲突（如上传）

### 8.2 缩略图策略

- 生成时机：首次请求时按需生成（懒加载）。
- 缓存路径：`thumbnails/{library_id}/{file_id}.jpg`。
- 生成逻辑：用 `imaging.Open` 打开原图 → `imaging.Resize(img, 400, 0, imaging.Lanczos)` 保持宽高比 → 保存为 JPEG。
- 原图宽度 ≤ 400px 时直接返回原图，不生成缩略图。
- 并发控制：用 `sync.Map` 维护 per-file 生成锁（key 为 `file_id`），同一文件并发请求时只有一个触发生成，其余等待完成后直接读缓存，避免重复写文件。

### 8.3 视频流（HTTP Range）

使用 `http.ServeContent`（Go 标准库），自动处理 `Range` 请求头，返回 `206 Partial Content`。

### 8.4 视频时长读取

使用 ffprobe，不做降级。应用启动时强制检测 ffprobe 是否可用，检测失败直接退出进程：

```go
// internal/core/startup.go
import (
    "fmt"
    "os"
    "os/exec"
)

func CheckDependencies() {
    if _, err := exec.LookPath("ffprobe"); err != nil {
        fmt.Fprintln(os.Stderr, "错误：未找到 ffprobe，请先安装 ffmpeg。")
        os.Exit(1)
    }
}
```

索引时调用：

```go
func GetVideoDuration(ctx context.Context, filepath string) (float64, error) {
    cmd := exec.CommandContext(ctx, "ffprobe",
        "-v", "quiet", "-print_format", "json", "-show_format", filepath)
    out, err := cmd.Output()
    if err != nil {
        return 0, err
    }
    var result struct {
        Format struct {
            Duration string `json:"duration"`
        } `json:"format"`
    }
    if err := json.Unmarshal(out, &result); err != nil {
        return 0, err
    }
    return strconv.ParseFloat(result.Format.Duration, 64)
}
```

### 8.5 分页规范

所有列表查询接口统一使用 `page` + `page_size` 查询参数：
- `page`：页码，从 1 开始，默认 1
- `page_size`：每页条数，默认 30，最大 200

响应体统一包装：
```json
{
  "total": 150,
  "page": 1,
  "page_size": 30,
  "items": [ ... ]
}
```

涉及分页的接口：文件列表（目录浏览/搜索）、日志查询。文件列表的 `dirs` 字段不参与分页，始终返回当前层级全部子目录。

### 8.6 部署说明

Docker 单容器部署，nginx 作为反向代理放在前面，前端静态文件由 nginx 直接 serve，API 请求转发至 Gin：

```
用户 → nginx（SSL 终止、静态文件 serve、/api/* 反向代理） → Gin（Go 二进制）
```

注意事项：
- 前端静态文件由 nginx 的 `root` / `try_files` 配置直接返回，不经过 Gin
- 文件流（视频/图片）经过 nginx 时需配置 `proxy_buffering off`，避免大文件传输超时
- 上传场景需配置 `client_max_body_size 0`（不限制请求体大小），否则 nginx 默认 1MB 会导致大文件上传返回 413
- `X-Forwarded-For` / `X-Real-IP` 头需透传，启动时设置 `gin.SetTrustedProxies`
- Range 请求由 Go 标准库 `http.ServeContent` 自行处理，nginx 不做拦截

---

## 9. 依赖清单（go.mod 主要依赖）

```
github.com/gin-gonic/gin          v1.10+    # Web 框架
modernc.org/sqlite                v1.29+    # SQLite 驱动（纯 Go，无 CGO）
github.com/jmoiron/sqlx           v1.3+     # SQL 辅助（结构体扫描）
github.com/pressly/goose/v3       v3.20+    # 数据库迁移
github.com/golang-jwt/jwt/v5      v5.2+     # JWT
golang.org/x/crypto               latest    # Argon2 密码哈希
github.com/disintegration/imaging v1.6+     # 图片缩略图
github.com/joho/godotenv          v1.5+     # .env 加载
github.com/google/uuid            v1.6+     # UUID v4 生成
```

---

## 10. 已确认事项

1. **视频时长读取**：ffprobe，无降级，启动时强制检测，未找到直接退出
2. **error_code**：去除 `password_changed`，版本号不匹配统一返回 `token_expired`
3. **媒体库路径**：创建时校验目录存在且可读，失败返回 400
4. **分页**：需要，默认 page_size=30
5. **CORS**：不需要，Docker 单容器，nginx 同域名下分别 serve 前端静态文件和代理 API 请求
6. **nginx**：在前，配置 `proxy_buffering off` + `SetTrustedProxies`
7. **行为数据存储**：播放进度和观看历史持久化到数据库，重启不丢失
8. **行为表外键**：`playback_progress` 和 `watch_history` 的 `file_id` 不设外键，媒体库删除后行为数据保留
9. **数据库迁移**：远期可能切换 MySQL，当前 SQLite 方案不做提前适配；切换时需关注：驱动替换、WAL 移除、UUID 主键改 BINARY(16) 或自增整数、UPSERT 语法差异、goose 迁移文件重写
10. **刷新队列持久化**：不持久化，进程重启后队列任务丢失符合预期；如需恢复索引，管理员手动触发全量刷新即可
