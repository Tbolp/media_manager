import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { ConfigProvider } from 'antd';
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

export default function App() {
  return (
    <ConfigProvider locale={zhCN}>
      <RouterProvider router={router} />
    </ConfigProvider>
  );
}
