import { useState } from 'react';
import { Modal, Form, Input, Select, message } from 'antd';
import { createUser } from '@/api/users';
import { AxiosError } from 'axios';

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}

export default function CreateUserModal({ open, onClose, onCreated }: Props) {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  const handleOk = async () => {
    try {
      const values = await form.validateFields();
      setLoading(true);
      await createUser(values);
      message.success('用户创建成功');
      form.resetFields();
      onClose();
      onCreated();
    } catch (err) {
      if (err instanceof AxiosError) {
        message.error(err.response?.data?.detail ?? '创建失败');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      title="新建用户"
      open={open}
      onOk={handleOk}
      onCancel={() => { form.resetFields(); onClose(); }}
      confirmLoading={loading}
      okText="创建"
      cancelText="取消"
    >
      <Form form={form} layout="vertical">
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
          rules={[{ required: true, message: '请输入密码' }]}
        >
          <Input.Password />
        </Form.Item>
        <Form.Item
          name="role"
          label="角色"
          rules={[{ required: true, message: '请选择角色' }]}
        >
          <Select placeholder="请选择">
            <Select.Option value="user">普通用户</Select.Option>
            <Select.Option value="admin">管理员</Select.Option>
          </Select>
        </Form.Item>
      </Form>
    </Modal>
  );
}
