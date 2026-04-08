import { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Form, Input, Button, Alert, Spin } from 'antd';
import { PlayCircleFilled } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { login, getInitStatus } from '@/api/auth';
import { AxiosError } from 'axios';
import styles from './index.module.css';

interface LoginForm {
  username: string;
  password: string;
}

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { setAuth, authErrorMessage, clearAuthError } = useAuthStore();
  const [loading, setLoading] = useState(false);
  const [checking, setChecking] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    getInitStatus()
      .then((initialized) => {
        if (!initialized) {
          navigate('/init', { replace: true });
        }
      })
      .catch(() => {})
      .finally(() => setChecking(false));
  }, [navigate]);

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
      setAuth(data.token);
      const from = (location.state as { from?: { pathname: string } })?.from?.pathname ?? '/';
      navigate(from, { replace: true });
    } catch (err) {
      const error = err as AxiosError<{ detail?: string }>;
      setErrorMsg(error.response?.data?.detail ?? '登录失败');
    } finally {
      setLoading(false);
    }
  };

  if (checking) {
    return (
      <div className={styles.loading}>
        <Spin size="large" />
      </div>
    );
  }

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <div className={styles.header}>
          <div className={styles.icon}>
            <PlayCircleFilled />
          </div>
          <h1 className={styles.title}>家庭影院</h1>
          <div className={styles.subtitle}>Home Theater</div>
        </div>

        {errorMsg && (
          <Alert
            message={errorMsg}
            type="error"
            showIcon
            closable
            className={styles.alert}
            onClose={() => setErrorMsg(null)}
          />
        )}

        <Form layout="vertical" onFinish={handleSubmit} autoComplete="off" className={styles.form}>
          <Form.Item
            name="username"
            label="用户名"
            rules={[{ required: true, message: '请输入用户名' }]}
          >
            <Input placeholder="请输入用户名" />
          </Form.Item>
          <Form.Item
            name="password"
            label="密码"
            rules={[]}
          >
            <Input.Password placeholder="请输入密码" />
          </Form.Item>
          <Form.Item style={{ marginBottom: 0, marginTop: 8 }}>
            <Button
              type="primary"
              htmlType="submit"
              loading={loading}
              block
              className={styles.submitBtn}
            >
              登录
            </Button>
          </Form.Item>
        </Form>
      </div>
    </div>
  );
}
