import { useEffect, useRef } from 'react';
import { useAuthStore } from '@/stores/auth';
import { reportProgress } from '@/api/playback';
import { PROGRESS_REPORT_INTERVAL } from '@/utils/constants';

interface PlayerLike {
  currentTime: number;
  duration: number;
  paused: boolean;
}

export function useProgressReporter(fid: string, playerRef: React.RefObject<PlayerLike | null>) {
  const lastReportedRef = useRef<number>(0);

  // 定时上报（每 15 秒）
  useEffect(() => {
    const timer = setInterval(() => {
      const player = playerRef.current;
      if (player && !player.paused) {
        reportProgress(fid, player.currentTime, player.duration).catch(() => {});
        lastReportedRef.current = player.currentTime;
      }
    }, PROGRESS_REPORT_INTERVAL);
    return () => clearInterval(timer);
  }, [fid, playerRef]);

  // 离开时上报
  useEffect(() => {
    const report = () => {
      const player = playerRef.current;
      if (!player) return;
      // 避免重复上报相同位置
      if (Math.abs(player.currentTime - lastReportedRef.current) < 1) return;

      const token = useAuthStore.getState().token;
      const base = import.meta.env.VITE_API_BASE || '/api';
      const url = `${base}/files/${fid}/progress`;
      const body = JSON.stringify({
        position: player.currentTime,
        duration: player.duration,
      });

      try {
        fetch(url, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
          },
          body,
          keepalive: true,
        });
      } catch {
        // 静默失败
      }
    };

    const onVisibilityChange = () => {
      if (document.visibilityState === 'hidden') report();
    };

    window.addEventListener('beforeunload', report);
    document.addEventListener('visibilitychange', onVisibilityChange);

    return () => {
      report();
      window.removeEventListener('beforeunload', report);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [fid, playerRef]);
}
