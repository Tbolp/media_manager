import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Form, Input, Button, message } from 'antd';
import { SettingFilled } from '@ant-design/icons';
import { init } from '@/api/auth';
import { AxiosError } from 'axios';
import styles from './index.module.css';

interface InitForm {
  username: string;
  password: string;
  confirmPassword: string;
}

export default function InitPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (values: InitForm) => {
    setLoading(true);
    try {
      await init({ username: values.username, password: values.password ?? '' });
      message.success('管理员账号创建成功');
      navigate('/login');
    } catch (err) {
      const error = err as AxiosError<{ detail?: string }>;
      if (error.response?.status === 409) {
        message.info('系统已初始化，请直接登录');
        navigate('/login');
      } else {
        message.error(error.response?.data?.detail ?? '初始化失败');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <div className={styles.header}>
          <div className={styles.icon}>
            <SettingFilled />
          </div>
          <h1 className={styles.title}>系统初始化</h1>
          <div className={styles.subtitle}>创建管理员账号</div>
        </div>
        <Form layout="vertical" onFinish={handleSubmit} autoComplete="off" className={styles.form}>
          <Form.Item
            name="username"
            label="管理员用户名"
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
          <Form.Item
            name="confirmPassword"
            label="确认密码"
            dependencies={['password']}
            rules={[
              ({ getFieldValue }) => ({
                validator(_, value) {
                  if (getFieldValue('password') === (value ?? '')) {
                    return Promise.resolve();
                  }
                  return Promise.reject(new Error('两次输入的密码不一致'));
                },
              }),
            ]}
          >
            <Input.Password placeholder="请再次输入密码" />
          </Form.Item>
          <Form.Item style={{ marginBottom: 0, marginTop: 8 }}>
            <Button type="primary" htmlType="submit" loading={loading} block className={styles.submitBtn}>
              创建管理员
            </Button>
          </Form.Item>
        </Form>
      </div>
    </div>
  );
}
