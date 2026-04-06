import { Pagination } from 'antd';
import { FileIcon } from '@/components/FileIcon';
import { useAuthStore } from '@/stores/auth';
import { formatDuration, formatFileSize } from '@/utils/format';
import { getThumbnailUrl } from '@/api/playback';
import type { FileItem } from '@/api/types';
import styles from './FileList.module.css';

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
  onVideoClick: (file: FileItem) => void;
}

export default function FileList({
  files,
  dirs,
  total,
  page,
  pageSize,
  isSearchMode,
  onEnterDir,
  onPageChange,
  onImageClick,
  onVideoClick,
}: Props) {
  const token = useAuthStore((s) => s.token);

  const handleFileClick = (file: FileItem) => {
    if (file.file_type === 'video') {
      onVideoClick(file);
    } else if (file.file_type === 'image') {
      onImageClick(file.id);
    }
  };

  return (
    <div>
      {/* 目录 + 文件混合卡片网格 */}
      <div className={styles.grid}>
        {dirs.map((dirName) => (
          <div key={`dir-${dirName}`} className={styles.dirCard} onClick={() => onEnterDir(dirName)}>
            <div className={styles.dirIcon}>
              <FileIcon isDir />
            </div>
            <div className={styles.dirName}>{dirName}</div>
          </div>
        ))}

        {files.map((file) => (
          <div key={file.id} id={`file-${file.id}`} className={styles.fileCard} onClick={() => handleFileClick(file)}>
            <div className={styles.thumbnail}>
              {token ? (
                <img
                  src={getThumbnailUrl(file.id, token)}
                  alt={file.filename}
                  className={styles.thumbnailImg}
                  loading="lazy"
                />
              ) : (
                <div className={styles.noThumb}>
                  <FileIcon fileType={file.file_type} style={{ fontSize: 28 }} />
                  <span>暂无预览</span>
                </div>
              )}
              {file.file_type === 'video' && file.duration != null && (
                <span className={styles.duration}>{formatDuration(file.duration)}</span>
              )}
              {file.is_watched && (
                <span className={styles.watchedBadge}>已看</span>
              )}
            </div>

            {file.file_type === 'video' && file.progress != null && file.progress > 0 && (
              <div className={styles.progressBar}>
                <div
                  className={styles.progressFill}
                  style={{ width: `${Math.round(file.progress * 100)}%` }}
                />
              </div>
            )}

            <div className={styles.fileInfo}>
              <div className={styles.fileName}>
                {isSearchMode ? file.relative_path : file.filename}
              </div>
              {file.size != null && (
                <div className={styles.fileMeta}>{formatFileSize(file.size)}</div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* 分页 */}
      {total > pageSize && (
        <div className={styles.pagination}>
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
