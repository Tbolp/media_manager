import { useNavigate, Outlet, Link, useLocation } from 'react-router-dom';
import { Layout, Menu, Dropdown, Button } from 'antd';
import { LogoutOutlined, UserOutlined, PlayCircleFilled, AppstoreOutlined, TeamOutlined, SettingOutlined } from '@ant-design/icons';
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

  const menuItems = isAdmin
    ? [
        { key: '/', icon: <AppstoreOutlined />, label: <Link to="/"><span className={styles.menuText}>媒体库</span></Link> },
        { key: '/admin/users', icon: <TeamOutlined />, label: <Link to="/admin/users"><span className={styles.menuText}>用户管理</span></Link> },
        { key: '/admin/system', icon: <SettingOutlined />, label: <Link to="/admin/system"><span className={styles.menuText}>系统运维</span></Link> },
      ]
    : [];

  const selectedKey = menuItems
    .map((item) => item.key)
    .filter((key) => location.pathname.startsWith(key))
    .sort((a, b) => b.length - a.length)[0] ?? '/';

  return (
    <Layout className={styles.layout}>
      <Layout.Header className={styles.header}>
        <div className={styles.logo}>
          <PlayCircleFilled className={styles.logoIcon} />
          <span className={styles.logoText}>家庭影院</span>
        </div>
        <Menu
          theme="dark"
          mode="horizontal"
          selectedKeys={[selectedKey]}
          items={menuItems}
          style={{ flex: 1, background: 'transparent', borderBottom: 'none', lineHeight: '64px' }}
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
