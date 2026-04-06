export const DEFAULT_PAGE_SIZE = 30;
export const MAX_PAGE_SIZE = 200;
export const POLLING_INTERVAL = 4000;
export const PROGRESS_REPORT_INTERVAL = 15000;

export const ERROR_CODE_MESSAGES: Record<string, string> = {
  token_expired: '登录已过期，请重新登录',
  user_disabled: '账号已被停用，请联系管理员',
  user_deleted: '账号不存在，请联系管理员',
};
