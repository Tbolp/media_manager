import { useState, useEffect, useCallback, useMemo } from 'react';
import { Table, Input, Pagination } from 'antd';
import { getLogs } from '@/api/system';
import { debounce } from '@/utils/debounce';
import { formatDateTime } from '@/utils/format';
import { DEFAULT_PAGE_SIZE } from '@/utils/constants';
import type { LogEntry } from '@/api/types';

export default function Logs() {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [keyword, setKeyword] = useState('');
  const [loading, setLoading] = useState(true);

  const fetchLogs = useCallback(async (q: string, p: number) => {
    setLoading(true);
    try {
      const data = await getLogs({ q: q || undefined, page: p, page_size: DEFAULT_PAGE_SIZE });
      setLogs(data.items);
      setTotal(data.total);
    } catch {
      // 拦截器已处理
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchLogs(keyword, page);
  }, [fetchLogs, keyword, page]);

  const debouncedSearch = useMemo(
    () => debounce((q: string) => {
      setKeyword(q);
      setPage(1);
    }, 500),
    [],
  );

  const columns = [
    {
      title: '时间',
      dataIndex: 'created_at',
      key: 'created_at',
      width: 200,
      render: (val: string) => formatDateTime(val),
    },
    {
      title: '描述',
      dataIndex: 'message',
      key: 'message',
    },
  ];

  return (
    <div>
      <Input.Search
        placeholder="搜索日志..."
        allowClear
        onChange={(e) => debouncedSearch(e.target.value)}
        onSearch={(val) => { setKeyword(val); setPage(1); }}
        style={{ width: 300, marginBottom: 16 }}
      />

      <Table
        rowKey="id"
        columns={columns}
        dataSource={logs}
        loading={loading}
        pagination={false}
        size="small"
      />

      {total > DEFAULT_PAGE_SIZE && (
        <div style={{ textAlign: 'center', marginTop: 16 }}>
          <Pagination
            current={page}
            pageSize={DEFAULT_PAGE_SIZE}
            total={total}
            onChange={(p) => setPage(p)}
            showSizeChanger={false}
          />
        </div>
      )}
    </div>
  );
}
