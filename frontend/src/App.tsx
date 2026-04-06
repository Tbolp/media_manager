import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { ConfigProvider, theme } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { AuthGuard } from '@/components/AuthGuard';
import { AdminGuard } from '@/components/AdminGuard';
import { AppLayout } from '@/components/AppLayout';
import InitPage from '@/pages/Init';
import LoginPage from '@/pages/Login';
import HomePage from '@/pages/Home';
import LibraryPage from '@/pages/Library';
import PlayerPage from '@/pages/Player';
import UsersPage from '@/pages/Admin/Users';
import SystemPage from '@/pages/Admin/System';

const router = createBrowserRouter([
  {
    path: '/init',
    element: <InitPage />,
  },
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    element: (
      <ErrorBoundary>
        <AuthGuard>
          <AppLayout />
        </AuthGuard>
      </ErrorBoundary>
    ),
    children: [
      { index: true, element: <HomePage /> },
      { path: 'library/:id', element: <LibraryPage /> },
      { path: 'library/:id/play/:fid', element: <PlayerPage /> },
      {
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

const cinemaTheme = {
  algorithm: theme.darkAlgorithm,
  cssVar: true,
  token: {
    colorPrimary: '#ca8a04',
    colorBgBase: '#0f0f23',
    colorBgContainer: 'rgba(30, 27, 75, 0.6)',
    colorBgElevated: 'rgba(39, 39, 59, 0.8)',
    colorBorder: 'rgba(67, 56, 202, 0.25)',
    colorBorderSecondary: 'rgba(67, 56, 202, 0.15)',
    colorText: '#f8fafc',
    colorTextSecondary: 'rgba(248, 250, 252, 0.7)',
    colorTextTertiary: 'rgba(248, 250, 252, 0.5)',
    colorTextQuaternary: 'rgba(248, 250, 252, 0.3)',
    borderRadius: 12,
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
    colorLink: '#eab308',
    colorLinkHover: '#ca8a04',
    colorError: '#ef4444',
    colorSuccess: '#22c55e',
    colorWarning: '#f59e0b',
    colorInfo: '#4338ca',
  },
};

export default function App() {
  return (
    <ConfigProvider locale={zhCN} theme={cinemaTheme}>
      <RouterProvider router={router} />
    </ConfigProvider>
  );
}
