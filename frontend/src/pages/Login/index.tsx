import { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { Card, Form, Input, Button, Alert, Typography } from 'antd';
import { useAuthStore } from '@/stores/auth';
import { login } from '@/api/auth';
import { AxiosError } from 'axios';

const { Title } = Typography;

interface LoginForm {
  username: string;
  password: string;
}

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { setAuth, authErrorMessage, clearAuthError } = useAuthStore();
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // 读取 authErrorMessage（401 被踢出时的提示）
  useEffect(() => {
    if (authErrorMessage) {
      setErrorMsg(authErrorMessage);
      clearAuthError();
    }
  }, [authErrorMessage, clearAuthError]);

  const handleSubmit = async (values: LoginForm) => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const data = await login(values);
      setAuth(data.token, data.user);
      const from = (location.state as { from?: { pathname: string } })?.from?.pathname ?? '/';
      navigate(from, { replace: true });
    } catch (err) {
      const error = err as AxiosError<{ detail?: string }>;
      setErrorMsg(error.response?.data?.detail ?? '登录失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
      <Card style={{ width: 400 }}>
        <Title level={3} style={{ textAlign: 'center' }}>家庭影院</Title>
        {errorMsg && (
          <Alert message={errorMsg} type="error" showIcon closable style={{ marginBottom: 16 }}
            onClose={() => setErrorMsg(null)} />
        )}
        <Form layout="vertical" onFinish={handleSubmit} autoComplete="off">
          <Form.Item
            name="username"
            label="用户名"
            rules={[{ required: true, message: '请输入用户名' }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            name="password"
            label="密码"
            rules={[]}
          >
            <Input.Password />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading} block>
              登录
            </Button>
          </Form.Item>
        </Form>
        <div style={{ textAlign: 'center' }}>
          <Link to="/init">首次使用？初始化系统</Link>
        </div>
      </Card>
    </div>
  );
}
