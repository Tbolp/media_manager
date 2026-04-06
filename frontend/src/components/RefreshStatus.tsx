import { useState, useEffect } from 'react';
import { Alert } from 'antd';
import { usePolling } from '@/hooks/usePolling';
import { getLibraries } from '@/api/libraries';
import type { RefreshStatus as RefreshStatusType } from '@/api/types';
import { POLLING_INTERVAL } from '@/utils/constants';

interface Props {
  libraryId: string;
  initialStatus?: RefreshStatusType;
  onRefreshComplete?: () => void;
}

export function RefreshStatus({ libraryId, initialStatus = 'idle', onRefreshComplete }: Props) {
  const [status, setStatus] = useState<RefreshStatusType>(initialStatus);

  useEffect(() => {
    setStatus(initialStatus);
  }, [initialStatus]);

  usePolling(
    async () => {
      const res = await getLibraries();
      const lib = res.items.find((l) => l.id === libraryId);
      const newStatus = lib?.refresh_status ?? 'idle';
      setStatus(newStatus);
      if (newStatus === 'idle') {
        onRefreshComplete?.();
        return false;
      }
      return true;
    },
    POLLING_INTERVAL,
    status !== 'idle',
  );

  if (status === 'idle') return null;
  return (
    <Alert
      type="info"
      showIcon
      message={status === 'running' ? '刷新中...' : '等待刷新...'}
      banner
    />
  );
}
