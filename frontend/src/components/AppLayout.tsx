import { useNavigate, Outlet, Link, useLocation } from 'react-router-dom';
import { Layout, Menu, Dropdown, Button } from 'antd';
import { LogoutOutlined, UserOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { logout } from '@/api/auth';

const { Header, Content } = Layout;

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

  // 确定当前选中的菜单项
  const selectedKey = menuItems
    .map((item) => item.key)
    .filter((key) => location.pathname.startsWith(key))
    .sort((a, b) => b.length - a.length)[0] ?? '/';

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ display: 'flex', alignItems: 'center', padding: '0 24px' }}>
        <div style={{ color: '#fff', fontSize: 18, fontWeight: 'bold', marginRight: 32 }}>
          家庭影院
        </div>
        <Menu
          theme="dark"
          mode="horizontal"
          selectedKeys={[selectedKey]}
          items={menuItems}
          style={{ flex: 1 }}
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
          <Button type="text" style={{ color: '#fff' }} icon={<UserOutlined />}>
            {user?.username}
          </Button>
        </Dropdown>
      </Header>
      <Content style={{ padding: 24 }}>
        <Outlet />
      </Content>
    </Layout>
  );
}
