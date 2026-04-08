export interface JwtPayload {
  sub: string;
  name: string;
  role: 'admin' | 'user';
  ver: number;
  exp: number;
}

/**
 * 解码 JWT payload（不做签名校验，签名由后端负责）。
 * 返回 null 表示格式异常。
 */
export function decodeJwt(token: string): JwtPayload | null {
  try {
    const base64 = token.split('.')[1];
    const json = atob(base64.replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json);
  } catch {
    return null;
  }
}
