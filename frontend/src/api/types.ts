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
  duration: number | null;
  size: number | null;
  progress: number | null;
  is_watched: boolean | null;
}

export interface FileProgress {
  position: number;
  duration: number;
  is_watched: boolean;
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
  status: 'running' | 'success' | 'failed';
  started_at?: string;
  finished_at?: string;
  error?: string;
}

export interface LibraryTasks {
  library_id: string;
  library_name: string;
  current_task: TaskInfo | null;
  pending_count: number;
  recent_tasks: TaskInfo[];
}

export interface LogEntry {
  id: string;
  created_at: string;
  message: string;
}
