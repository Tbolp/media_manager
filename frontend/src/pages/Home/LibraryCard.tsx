import { useNavigate } from 'react-router-dom';
import { Tag, Modal, Button } from 'antd';
import { DeleteOutlined, VideoCameraOutlined, CameraOutlined, PictureOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { deleteLibrary } from '@/api/libraries';
import { getThumbnailUrl } from '@/api/playback';
import { RefreshStatus } from '@/components/RefreshStatus';
import type { Library } from '@/api/types';
import styles from './LibraryCard.module.css';

interface Props {
  library: Library;
  onDeleted: () => void;
}

export default function LibraryCard({ library, onDeleted }: Props) {
  const isAdmin = useAuthStore((s) => s.isAdmin);
  const token = useAuthStore((s) => s.token);
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

  const typeIcon = library.lib_type === 'video' ? <VideoCameraOutlined /> : <CameraOutlined />;
  const typeLabel = library.lib_type === 'video' ? '视频' : '相机';

  return (
    <div className={styles.card} onClick={() => navigate(`/library/${library.id}`)}>
      {/* 封面区域 */}
      <div className={styles.cover}>
        {library.cover_file_id && token ? (
          <img
            src={getThumbnailUrl(library.cover_file_id, token)}
            alt={library.name}
            className={styles.coverImg}
            loading="lazy"
          />
        ) : (
          <div className={styles.noPreview}>
            <PictureOutlined className={styles.noPreviewIcon} />
            <span>暂无预览</span>
          </div>
        )}
      </div>

      {/* 内容区域 */}
      <div className={styles.body}>
        <div className={styles.name}>{library.name}</div>
        <div className={styles.footer}>
          <Tag icon={typeIcon} color={library.lib_type === 'video' ? 'blue' : 'green'} className={styles.typeTag}>
            {typeLabel}
          </Tag>
          {isAdmin && (
            <Button
              type="text"
              size="small"
              icon={<DeleteOutlined />}
              className={styles.deleteBtn}
              onClick={handleDelete}
            />
          )}
        </div>
        <RefreshStatus libraryId={library.id} initialStatus={library.refresh_status} />
      </div>
    </div>
  );
}
