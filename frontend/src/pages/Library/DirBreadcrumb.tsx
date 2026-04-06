import styles from './DirBreadcrumb.module.css';

interface Props {
  libraryName: string;
  currentPath: string;
  onNavigate: (targetPath: string) => void;
}

export default function DirBreadcrumb({ libraryName, currentPath, onNavigate }: Props) {
  const segments = currentPath ? currentPath.split('/').filter(Boolean) : [];

  const items = [
    { label: libraryName, path: '' },
    ...segments.map((seg, i) => ({
      label: seg,
      path: segments.slice(0, i + 1).join('/'),
    })),
  ];

  return (
    <div className={styles.bar}>
      {items.map((item, i) => {
        const isLast = i === items.length - 1;
        return (
          <span
            key={item.path || '_root'}
            className={`${styles.item} ${isLast ? styles.active : ''}`}
            onClick={isLast ? undefined : () => onNavigate(item.path)}
          >
            {item.label}
          </span>
        );
      })}
    </div>
  );
}
