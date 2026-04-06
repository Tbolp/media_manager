import { useNavigate, Outlet, Link, useLocation } from 'react-router-dom';
import { Layout, Menu, Dropdown, Button } from 'antd';
import { LogoutOutlined, UserOutlined, PlayCircleFilled } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { logout } from '@/api/auth';
import styles from './AppLayout.module.css';

export function AppLayout() {
  const { user, isAdmin, clearAuth } = useAuthStore();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = async () => {
    try {
      await logout();
    } finally {
      clearAuth();
      navigate('/login');
    }
  };

  const menuItems = [
    { key: '/', label: <Link to="/">媒体库</Link> },
    ...(isAdmin
      ? [
          { key: '/admin/users', label: <Link to="/admin/users">用户管理</Link> },
          { key: '/admin/system', label: <Link to="/admin/system">系统运维</Link> },
        ]
      : []),
  ];

  const selectedKey = menuItems
    .map((item) => item.key)
    .filter((key) => location.pathname.startsWith(key))
    .sort((a, b) => b.length - a.length)[0] ?? '/';

  return (
    <Layout className={styles.layout}>
      <Layout.Header className={styles.header}>
        <div className={styles.logo}>
          <PlayCircleFilled className={styles.logoIcon} />
          家庭影院
        </div>
        <Menu
          theme="dark"
          mode="horizontal"
          selectedKeys={[selectedKey]}
          items={menuItems}
          style={{ flex: 1, background: 'transparent', borderBottom: 'none' }}
        />
        <Dropdown
          menu={{
            items: [
              {
                key: 'logout',
                icon: <LogoutOutlined />,
                label: '登出',
                onClick: handleLogout,
              },
            ],
          }}
        >
          <Button type="text" className={styles.userBtn} icon={<UserOutlined />}>
            {user?.username}
          </Button>
        </Dropdown>
      </Layout.Header>
      <Layout.Content className={styles.content}>
        <Outlet />
      </Layout.Content>
    </Layout>
  );
}
