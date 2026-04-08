import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { decodeJwt } from '@/utils/jwt';

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
  authErrorMessage: string | null;

  setAuth: (token: string) => void;
  clearAuth: () => void;
  handleUnauthorized: (errorCode?: string) => void;
  clearAuthError: () => void;
}

function deriveUser(token: string | null): User | null {
  if (!token) return null;
  const payload = decodeJwt(token);
  if (!payload) return null;
  return { id: payload.sub, username: payload.name, role: payload.role };
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      user: null,
      isLoggedIn: false,
      isAdmin: false,
      authErrorMessage: null,

      setAuth: (token) => {
        const user = deriveUser(token);
        set({
          token,
          user,
          isLoggedIn: true,
          isAdmin: user?.role === 'admin',
          authErrorMessage: null,
        });
      },

      clearAuth: () =>
        set({ token: null, user: null, isLoggedIn: false, isAdmin: false }),

      clearAuthError: () => set({ authErrorMessage: null }),

      handleUnauthorized: (errorCode) => {
        const messages: Record<string, string> = {
          token_expired: '登录已过期，请重新登录',
          user_disabled: '账号已被停用，请联系管理员',
          user_deleted: '账号不存在，请联系管理员',
        };
        const msg = messages[errorCode ?? ''] ?? '登录已失效，请重新登录';
        get().clearAuth();
        set({ authErrorMessage: msg });
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ token: state.token }),
      onRehydrateStorage: () => (state) => {
        if (state?.token) {
          const user = deriveUser(state.token);
          state.user = user;
          state.isLoggedIn = true;
          state.isAdmin = user?.role === 'admin';
        }
      },
    }
  )
);
