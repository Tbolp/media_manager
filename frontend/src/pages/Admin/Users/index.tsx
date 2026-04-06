import { useState, useEffect, useCallback } from 'react';
import { Table, Button, Tag, Modal, Space, message } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { getUsers, disableUser, enableUser, deleteUser } from '@/api/users';
import { formatDateTime } from '@/utils/format';
import type { User } from '@/api/types';
import type { ColumnsType } from 'antd/es/table';
import CreateUserModal from './CreateUserModal';
import ResetPasswordModal from './ResetPasswordModal';
import PermissionPanel from './PermissionPanel';

export default function UsersPage() {
  const currentUser = useAuthStore((s) => s.user);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [resetTarget, setResetTarget] = useState<User | null>(null);

  const fetchUsers = useCallback(async () => {
    try {
      const data = await getUsers();
      setUsers(data.items);
    } catch {
      // 拦截器已处理
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const handleToggleDisable = async (user: User) => {
    try {
      if (user.is_disabled) {
        await enableUser(user.id);
        message.success('已解禁');
      } else {
        await disableUser(user.id);
        message.success('已禁用');
      }
      fetchUsers();
    } catch {
      // 拦截器已处理
    }
  };

  const handleDelete = (user: User) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除用户「${user.username}」吗？此操作不可恢复。`,
      okText: '删除',
      okType: 'danger',
      cancelText: '取消',
      onOk: async () => {
        await deleteUser(user.id);
        message.success('用户已删除');
        fetchUsers();
      },
    });
  };

  const isSelf = (user: User) => user.id === currentUser?.id;

  const columns: ColumnsType<User> = [
    {
      title: '用户名',
      dataIndex: 'username',
      key: 'username',
    },
    {
      title: '角色',
      dataIndex: 'role',
      key: 'role',
      render: (role: string) => (
        <Tag color={role === 'admin' ? 'red' : 'blue'}>
          {role === 'admin' ? '管理员' : '普通用户'}
        </Tag>
      ),
    },
    {
      title: '状态',
      key: 'status',
      render: (_: unknown, record: User) => (
        record.is_disabled
          ? <Tag color="error">已禁用</Tag>
          : <Tag color="success">正常</Tag>
      ),
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (val: string) => formatDateTime(val),
    },
    {
      title: '操作',
      key: 'actions',
      render: (_: unknown, record: User) => (
        <Space>
          <Button
            size="small"
            onClick={() => handleToggleDisable(record)}
            disabled={isSelf(record)}
          >
            {record.is_disabled ? '解禁' : '禁用'}
          </Button>
          <Button size="small" onClick={() => setResetTarget(record)}>
            重置密码
          </Button>
          <Button
            size="small"
            danger
            onClick={() => handleDelete(record)}
            disabled={isSelf(record)}
          >
            删除
          </Button>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
        <h2 style={{ margin: 0 }}>用户管理</h2>
        <Button type="primary" icon={<PlusOutlined />} onClick={() => setShowCreate(true)}>
          新建用户
        </Button>
      </div>

      <Table
        rowKey="id"
        columns={columns}
        dataSource={users}
        loading={loading}
        pagination={false}
        expandable={{
          expandedRowRender: (record) => (
            <PermissionPanel userId={record.id} libraryIds={record.library_ids} />
          ),
          rowExpandable: (record) => record.role !== 'admin',
        }}
      />

      <CreateUserModal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        onCreated={fetchUsers}
      />

      <ResetPasswordModal
        user={resetTarget}
        onClose={() => setResetTarget(null)}
        onSuccess={fetchUsers}
      />
    </div>
  );
}
