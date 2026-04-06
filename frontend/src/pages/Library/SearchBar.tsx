import { useState, useMemo, useCallback } from 'react';
import { Input } from 'antd';
import { debounce } from '@/utils/debounce';

interface Props {
  onSearch: (q: string) => void;
  initialValue?: string;
}

export default function SearchBar({ onSearch, initialValue = '' }: Props) {
  const [value, setValue] = useState(initialValue);

  const debouncedSearch = useMemo(
    () => debounce((q: string) => onSearch(q), 300),
    [onSearch],
  );

  const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setValue(val);
    debouncedSearch(val);
  }, [debouncedSearch]);

  return (
    <Input.Search
      placeholder="搜索文件名..."
      value={value}
      onChange={handleChange}
      onSearch={onSearch}
      allowClear
      style={{ width: 220 }}
    />
  );
}
