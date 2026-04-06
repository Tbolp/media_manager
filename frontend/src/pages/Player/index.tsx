import { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Button, message, Spin } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import Player from 'xgplayer';
import { useAuthStore } from '@/stores/auth';
import { getStreamUrl, getProgress } from '@/api/playback';
import { useProgressReporter } from '@/hooks/useProgress';

export default function PlayerPage() {
  const { id: libraryId, fid } = useParams<{ id: string; fid: string }>();
  const navigate = useNavigate();
  const token = useAuthStore((s) => s.token);

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
      width: '100%',
      height: '100%',
      fluid: true,
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
      <Button
        icon={<ArrowLeftOutlined />}
        style={{ marginBottom: 16 }}
        onClick={() => navigate(`/library/${libraryId}`)}
      >
        返回
      </Button>
      {!ready ? (
        <div style={{ textAlign: 'center', padding: 48 }}>
          <Spin size="large" />
        </div>
      ) : (
        <div
          ref={containerRef}
          style={{ width: '100%', maxWidth: 960, margin: '0 auto', background: '#000' }}
        />
      )}
    </div>
  );
}
