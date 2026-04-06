import { FolderOutlined, PlayCircleOutlined, PictureOutlined } from '@ant-design/icons';
import type { FileType } from '@/api/types';

interface Props {
  fileType?: FileType;
  isDir?: boolean;
  style?: React.CSSProperties;
}

export function FileIcon({ fileType, isDir, style }: Props) {
  if (isDir) return <FolderOutlined style={{ color: '#faad14', ...style }} />;
  if (fileType === 'video') return <PlayCircleOutlined style={{ color: '#1677ff', ...style }} />;
  if (fileType === 'image') return <PictureOutlined style={{ color: '#52c41a', ...style }} />;
  return <FolderOutlined style={style} />;
}
