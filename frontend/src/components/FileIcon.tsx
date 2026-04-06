import { FolderOutlined, PlayCircleOutlined, PictureOutlined } from '@ant-design/icons';
import type { FileType } from '@/api/types';

interface Props {
  fileType?: FileType;
  isDir?: boolean;
  style?: React.CSSProperties;
}

export function FileIcon({ fileType, isDir, style }: Props) {
  if (isDir) return <FolderOutlined style={{ color: '#eab308', ...style }} />;
  if (fileType === 'video') return <PlayCircleOutlined style={{ color: '#ca8a04', ...style }} />;
  if (fileType === 'image') return <PictureOutlined style={{ color: '#6366f1', ...style }} />;
  return <FolderOutlined style={style} />;
}
