import { useState } from 'react';
import { Modal, Form, Input, message } from 'antd';
import { resetPassword } from '@/api/users';
import { AxiosError } from 'axios';
import type { User } from '@/api/types';

interface Props {
  user: User | null;
  onClose: () => void;
  onSuccess: () => void;
}

export default function ResetPasswordModal({ user, onClose, onSuccess }: Props) {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  const handleOk = async () => {
    if (!user) return;
    try {
      const values = await form.validateFields();
      setLoading(true);
      await resetPassword(user.id, values.password);
      message.success('密码已重置');
      form.resetFields();
      onClose();
      onSuccess();
    } catch (err) {
      if (err instanceof AxiosError) {
        message.error(err.response?.data?.detail ?? '重置失败');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      title={`重置密码 - ${user?.username ?? ''}`}
      open={!!user}
      onOk={handleOk}
      onCancel={() => { form.resetFields(); onClose(); }}
      confirmLoading={loading}
      okText="确认"
      cancelText="取消"
    >
      <Form form={form} layout="vertical">
        <Form.Item
          name="password"
          label="新密码"
          rules={[]}
        >
          <Input.Password />
        </Form.Item>
      </Form>
    </Modal>
  );
}
