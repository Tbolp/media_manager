import { useState, useEffect, useRef } from 'react';
import { Checkbox, Spin } from 'antd';
import { getLibraries } from '@/api/libraries';
import { updatePermissions } from '@/api/users';
import type { Library } from '@/api/types';

interface Props {
  userId: string;
  libraryIds: string[];
}

export default function PermissionPanel({ userId, libraryIds }: Props) {
  const [allLibraries, setAllLibraries] = useState<Library[]>([]);
  const [selected, setSelected] = useState<string[]>(libraryIds);
  const [loading, setLoading] = useState(true);
  const lastSavedRef = useRef<string[]>(libraryIds);

  // 同步外部 prop 变化
  useEffect(() => {
    setSelected(libraryIds);
    lastSavedRef.current = libraryIds;
  }, [libraryIds]);

  useEffect(() => {
    getLibraries()
      .then((data) => setAllLibraries(data.items))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handleChange = async (checkedValues: string[]) => {
    const previous = lastSavedRef.current;
    setSelected(checkedValues);
    try {
      await updatePermissions(userId, checkedValues);
      lastSavedRef.current = checkedValues;
    } catch {
      // 失败时恢复到上次成功保存的值
      setSelected(previous);
    }
  };

  if (loading) return <Spin size="small" />;

  if (allLibraries.length === 0) {
    return <span style={{ color: 'rgba(248,250,252,0.5)' }}>暂无媒体库</span>;
  }

  return (
    <div>
      <div style={{ marginBottom: 8, fontWeight: 500 }}>媒体库访问权限：</div>
      <Checkbox.Group
        value={selected}
        onChange={(values) => handleChange(values as string[])}
        options={allLibraries.map((lib) => ({
          label: `${lib.name} (${lib.lib_type === 'video' ? '视频' : '相机'})`,
          value: lib.id,
        }))}
      />
    </div>
  );
}
