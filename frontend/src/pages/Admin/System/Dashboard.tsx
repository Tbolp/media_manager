import { useState, useEffect } from 'react';
import { Card, Statistic, Table, Row, Col, Spin } from 'antd';
import { getDashboard } from '@/api/system';
import { formatDateTime } from '@/utils/format';
import type { DashboardData } from '@/api/types';

export default function Dashboard() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getDashboard()
      .then(setData)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <Spin />;
  if (!data) return null;

  const userColumns = [
    { title: '用户名', dataIndex: 'username', key: 'username' },
    {
      title: '最近活跃',
      dataIndex: 'last_active_at',
      key: 'last_active_at',
      render: (val: string | null) => formatDateTime(val),
    },
  ];

  return (
    <div>
      <Row gutter={16} style={{ marginBottom: 24 }}>
        <Col span={8}>
          <Card>
            <Statistic title="媒体文件总数" value={data.total_media_count} />
          </Card>
        </Col>
      </Row>

      <Card title="用户活跃状态">
        <Table
          rowKey="id"
          columns={userColumns}
          dataSource={data.users}
          pagination={false}
          size="small"
        />
      </Card>
    </div>
  );
}
