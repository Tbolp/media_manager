import { useEffect, useRef, useState } from 'react';
import { useParams, useLocation } from 'react-router-dom';
import { message, Spin, Typography } from 'antd';
import Player from 'xgplayer/es/index.umd.js';
import 'xgplayer/dist/index.min.css';
import { useAuthStore } from '@/stores/auth';
import { getStreamUrl, getProgress } from '@/api/playback';
import { useProgressReporter } from '@/hooks/useProgress';

export default function PlayerPage() {
  const { fid } = useParams<{ id: string; fid: string }>();
  const location = useLocation();
  const token = useAuthStore((s) => s.token);
  const title = (location.state as { title?: string })?.title ?? '播放中';

  const playerRef = useRef<Player | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  const initialPositionRef = useRef(0);

  // 获取上次播放进度
  useEffect(() => {
    if (!fid) return;
    getProgress(fid)
      .then((res) => {
        initialPositionRef.current = res.position ?? 0;
      })
      .catch(() => {})
      .finally(() => {
        setReady(true);
      });
  }, [fid]);

  // 进度上报
  useProgressReporter(fid ?? '', playerRef);

  // 创建播放器
  useEffect(() => {
    if (!ready || !fid || !token || !containerRef.current) return;

    const player = new Player({
      el: containerRef.current,
      url: getStreamUrl(fid, token),
      startTime: initialPositionRef.current,
      playbackRate: [0.5, 0.75, 1, 1.25, 1.5, 2],
      volume: 0.8,
      width: 800,
      height: 450,
    });

    playerRef.current = player;

    player.on('error', () => {
      message.error('播放失败，请稍后再试');
    });

    return () => {
      player.destroy();
      playerRef.current = null;
    };
  }, [fid, ready, token]);

  return (
    <div>
      <Typography.Title level={4} style={{ marginBottom: 16 }}>{title}</Typography.Title>
      {!ready ? (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <Spin size="large" />
        </div>
      ) : (
        <div
          ref={containerRef}
          style={{ margin: '0 auto', background: '#000', width: 'fit-content' }}
        />
      )}
    </div>
  );
}
