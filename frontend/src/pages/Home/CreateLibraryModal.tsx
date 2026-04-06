import { useState } from 'react';
import { Modal, Form, Input, Select, message } from 'antd';
import { createLibrary } from '@/api/libraries';
import { AxiosError } from 'axios';

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}

export default function CreateLibraryModal({ open, onClose, onCreated }: Props) {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  const handleOk = async () => {
    try {
      const values = await form.validateFields();
      setLoading(true);
      await createLibrary(values);
      message.success('媒体库创建成功');
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
      title="新建媒体库"
      open={open}
      onOk={handleOk}
      onCancel={() => { form.resetFields(); onClose(); }}
      confirmLoading={loading}
      okText="创建"
      cancelText="取消"
    >
      <Form form={form} layout="vertical">
        <Form.Item
          name="name"
          label="名称"
          rules={[{ required: true, message: '请输入媒体库名称' }]}
        >
          <Input placeholder="例如：电影" />
        </Form.Item>
        <Form.Item
          name="path"
          label="目录路径"
          rules={[{ required: true, message: '请输入服务器目录路径' }]}
        >
          <Input placeholder="例如：/data/movies" />
        </Form.Item>
        <Form.Item
          name="lib_type"
          label="类型"
          rules={[{ required: true, message: '请选择类型' }]}
        >
          <Select placeholder="请选择">
            <Select.Option value="video">视频</Select.Option>
            <Select.Option value="camera">相机</Select.Option>
          </Select>
        </Form.Item>
      </Form>
    </Modal>
  );
}
