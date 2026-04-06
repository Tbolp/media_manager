import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, Form, Input, Button, message, Typography } from 'antd';
import { init } from '@/api/auth';
import { AxiosError } from 'axios';

const { Title } = Typography;

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
      await init({ username: values.username, password: values.password });
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
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}>
      <Card style={{ width: 400 }}>
        <Title level={3} style={{ textAlign: 'center' }}>系统初始化</Title>
        <Form layout="vertical" onFinish={handleSubmit} autoComplete="off">
          <Form.Item
            name="username"
            label="管理员用户名"
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
            <Input.Password />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading} block>
              创建管理员
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
}
