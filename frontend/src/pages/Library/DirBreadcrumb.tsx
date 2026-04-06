import { Breadcrumb } from 'antd';
import { HomeOutlined } from '@ant-design/icons';

interface Props {
  libraryName: string;
  currentPath: string;
  onNavigate: (targetPath: string) => void;
}

export default function DirBreadcrumb({ libraryName, currentPath, onNavigate }: Props) {
  const segments = currentPath ? currentPath.split('/').filter(Boolean) : [];

  const items = [
    {
      title: (
        <span style={{ cursor: 'pointer' }} onClick={() => onNavigate('')}>
          <HomeOutlined style={{ marginRight: 4 }} />
          {libraryName}
        </span>
      ),
    },
    ...segments.map((seg, i) => ({
      title: (
        <span
          style={{ cursor: 'pointer' }}
          onClick={() => onNavigate(segments.slice(0, i + 1).join('/'))}
        >
          {seg}
        </span>
      ),
    })),
  ];

  return <Breadcrumb items={items} style={{ marginBottom: 16 }} />;
}
