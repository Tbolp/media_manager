import { useEffect, useRef } from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { message } from 'antd';
import { useAuthStore } from '@/stores/auth';

export function AdminGuard() {
  const isAdmin = useAuthStore((s) => s.isAdmin);
  const navigated = useRef(false);

  useEffect(() => {
    if (!isAdmin && !navigated.current) {
      message.warning('无权访问');
      navigated.current = true;
    }
  }, [isAdmin]);

  if (!isAdmin) {
    return <Navigate to="/" replace />;
  }
  return <Outlet />;
}
