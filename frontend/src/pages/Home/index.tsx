import { useState, useEffect, useCallback } from 'react';
import { Row, Col, Button, Skeleton, Empty, message } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { getLibraries } from '@/api/libraries';
import { usePolling } from '@/hooks/usePolling';
import { POLLING_INTERVAL } from '@/utils/constants';
import type { Library } from '@/api/types';
import LibraryCard from './LibraryCard';
import CreateLibraryModal from './CreateLibraryModal';

export default function HomePage() {
  const isAdmin = useAuthStore((s) => s.isAdmin);
  const [libraries, setLibraries] = useState<Library[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const fetchLibraries = useCallback(async () => {
    try {
      const data = await getLibraries();
      setLibraries(data.items);
    } catch {
      // 拦截器已处理
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchLibraries();
  }, [fetchLibraries]);

  // 有非 idle 的库时轮询
  const hasNonIdle = libraries.some((lib) => lib.refresh_status !== 'idle');
  usePolling(
    async () => {
      const data = await getLibraries();
      setLibraries(data.items);
      return data.items.some((lib) => lib.refresh_status !== 'idle');
    },
    POLLING_INTERVAL,
    hasNonIdle,
  );

  const handleDeleted = (id: string) => {
    setLibraries((prev) => prev.filter((lib) => lib.id !== id));
    message.success('媒体库已删除');
  };

  if (loading) {
    return (
      <Row gutter={[16, 16]}>
        {[1, 2, 3, 4].map((i) => (
          <Col key={i} xs={24} sm={12} md={8} lg={6}>
            <Skeleton active />
          </Col>
        ))}
      </Row>
    );
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
        <h2 style={{ margin: 0 }}>媒体库</h2>
        {isAdmin && (
          <Button type="primary" icon={<PlusOutlined />} onClick={() => setShowCreate(true)}>
            新建媒体库
          </Button>
        )}
      </div>

      {libraries.length === 0 ? (
        <Empty description="暂无媒体库" />
      ) : (
        <Row gutter={[16, 16]}>
          {libraries.map((lib) => (
            <Col key={lib.id} xs={24} sm={12} md={8} lg={6}>
              <LibraryCard library={lib} onDeleted={() => handleDeleted(lib.id)} />
            </Col>
          ))}
        </Row>
      )}

      <CreateLibraryModal
        open={showCreate}
        onClose={() => setShowCreate(false)}
        onCreated={fetchLibraries}
      />
    </div>
  );
}
