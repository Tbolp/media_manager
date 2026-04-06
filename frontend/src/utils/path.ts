/**
 * 拼接路径段，过滤空段
 */
export function joinPath(...segments: string[]): string {
  return segments.filter(Boolean).join('/');
}

/**
 * 获取父路径
 */
export function getParentPath(path: string): string {
  const parts = path.split('/').filter(Boolean);
  parts.pop();
  return parts.join('/');
}

/**
 * 将路径拆分为段
 */
export function getPathSegments(path: string): string[] {
  return path.split('/').filter(Boolean);
}

/**
 * 获取路径的最后一段（文件名）
 */
export function getFileName(path: string): string {
  const parts = path.split('/').filter(Boolean);
  return parts[parts.length - 1] ?? '';
}
