import { useNavigate } from 'react-router-dom';
import styles from './DirBreadcrumb.module.css';

interface Props {
  libraryName: string;
  currentPath: string;
  onNavigate: (targetPath: string) => void;
}

export default function DirBreadcrumb({ libraryName, currentPath, onNavigate }: Props) {
  const navigate = useNavigate();
  const segments = currentPath ? currentPath.split('/').filter(Boolean) : [];

  const items = [
    { label: libraryName, path: '' },
    ...segments.map((seg, i) => ({
      label: seg,
      path: segments.slice(0, i + 1).join('/'),
    })),
  ];

  const isLastRoot = items.length === 1;

  return (
    <div className={styles.bar}>
      <span
        className={styles.item}
        onClick={() => navigate('/')}
      >
        媒体库
      </span>
      {items.map((item, i) => {
        const isLast = i === items.length - 1;
        return (
          <span
            key={item.path || '_root'}
            className={`${styles.item} ${isLast && isLastRoot ? styles.active : isLast ? styles.active : ''}`}
            onClick={isLast ? undefined : () => onNavigate(item.path)}
          >
            {item.label}
          </span>
        );
      })}
    </div>
  );
}
