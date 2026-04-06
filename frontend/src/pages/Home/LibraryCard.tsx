import { useNavigate } from 'react-router-dom';
import { Card, Tag, Modal } from 'antd';
import { DeleteOutlined, VideoCameraOutlined, CameraOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { deleteLibrary } from '@/api/libraries';
import { RefreshStatus } from '@/components/RefreshStatus';
import type { Library } from '@/api/types';

interface Props {
  library: Library;
  onDeleted: () => void;
}

export default function LibraryCard({ library, onDeleted }: Props) {
  const isAdmin = useAuthStore((s) => s.isAdmin);
  const navigate = useNavigate();

  const handleDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
    Modal.confirm({
      title: '删除媒体库',
      content: `确定要删除「${library.name}」吗？此操作不可恢复。`,
      okText: '删除',
      okType: 'danger',
      cancelText: '取消',
      onOk: async () => {
        await deleteLibrary(library.id);
        onDeleted();
      },
    });
  };

  const typeIcon = library.lib_type === 'video'
    ? <VideoCameraOutlined />
    : <CameraOutlined />;

  const typeLabel = library.lib_type === 'video' ? '视频' : '相机';

  return (
    <Card
      hoverable
      onClick={() => navigate(`/library/${library.id}`)}
      actions={
        isAdmin
          ? [<DeleteOutlined key="delete" onClick={handleDelete} />]
          : undefined
      }
    >
      <Card.Meta
        title={library.name}
        description={
          <Tag icon={typeIcon} color={library.lib_type === 'video' ? 'blue' : 'green'}>
            {typeLabel}
          </Tag>
        }
      />
      <div style={{ marginTop: 12 }}>
        <RefreshStatus libraryId={library.id} initialStatus={library.refresh_status} />
      </div>
    </Card>
  );
}
