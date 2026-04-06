import { useNavigate } from 'react-router-dom';
import { List, Progress, Pagination, Tag } from 'antd';
import { CheckCircleOutlined } from '@ant-design/icons';
import { FileIcon } from '@/components/FileIcon';
import { useAuthStore } from '@/stores/auth';
import { formatDuration, formatFileSize } from '@/utils/format';
import { getThumbnailUrl } from '@/api/playback';
import type { FileItem } from '@/api/types';

interface Props {
  libraryId: string;
  files: FileItem[];
  dirs: string[];
  total: number;
  page: number;
  pageSize: number;
  isSearchMode: boolean;
  onEnterDir: (dirName: string) => void;
  onPageChange: (page: number) => void;
  onImageClick: (fileId: string) => void;
}

export default function FileList({
  libraryId,
  files,
  dirs,
  total,
  page,
  pageSize,
  isSearchMode,
  onEnterDir,
  onPageChange,
  onImageClick,
}: Props) {
  const navigate = useNavigate();
  const token = useAuthStore((s) => s.token);

  const handleFileClick = (file: FileItem) => {
    if (file.file_type === 'video') {
      navigate(`/library/${libraryId}/play/${file.id}`, { state: { title: file.filename } });
    } else if (file.file_type === 'image') {
      onImageClick(file.id);
    }
  };

  return (
    <div>
      {/* 目录列表 */}
      {dirs.length > 0 && (
        <List
          dataSource={dirs}
          renderItem={(dirName) => (
            <List.Item
              style={{ cursor: 'pointer' }}
              onClick={() => onEnterDir(dirName)}
            >
              <List.Item.Meta
                avatar={<FileIcon isDir style={{ fontSize: 24 }} />}
                title={dirName}
              />
            </List.Item>
          )}
        />
      )}

      {/* 文件列表 */}
      <List
        dataSource={files}
        renderItem={(file) => (
          <List.Item
            style={{ cursor: 'pointer' }}
            onClick={() => handleFileClick(file)}
          >
            <List.Item.Meta
              avatar={
                file.file_type === 'image' && token ? (
                  <img
                    src={getThumbnailUrl(file.id, token)}
                    alt={file.filename}
                    loading="lazy"
                    style={{ width: 60, height: 60, objectFit: 'cover', borderRadius: 4 }}
                  />
                ) : (
                  <FileIcon fileType={file.file_type} style={{ fontSize: 24 }} />
                )
              }
              title={
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span>{isSearchMode ? file.relative_path : file.filename}</span>
                  {file.is_watched && (
                    <Tag icon={<CheckCircleOutlined />} color="success">已看</Tag>
                  )}
                </div>
              }
              description={
                <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
                  {file.file_type === 'video' && (
                    <>
                      <span>{formatDuration(file.duration)}</span>
                      {file.size != null && <span>{formatFileSize(file.size)}</span>}
                    </>
                  )}
                  {file.file_type === 'image' && file.size != null && (
                    <span>{formatFileSize(file.size)}</span>
                  )}
                </div>
              }
            />
            {/* 视频进度条 */}
            {file.file_type === 'video' && file.progress != null && file.progress > 0 && (
              <div style={{ width: 120 }}>
                <Progress
                  percent={Math.round(file.progress * 100)}
                  size="small"
                  strokeColor={file.is_watched ? '#52c41a' : undefined}
                />
              </div>
            )}
          </List.Item>
        )}
      />

      {/* 分页 */}
      {total > pageSize && (
        <div style={{ textAlign: 'center', marginTop: 16 }}>
          <Pagination
            current={page}
            pageSize={pageSize}
            total={total}
            onChange={onPageChange}
            showSizeChanger={false}
          />
        </div>
      )}
    </div>
  );
}
