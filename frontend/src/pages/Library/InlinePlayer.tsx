import { useEffect, useRef, useState } from 'react';
import { Button, Spin, message } from 'antd';
import { CloseOutlined } from '@ant-design/icons';
import Player from 'xgplayer/es/index.umd.js';
import 'xgplayer/dist/index.min.css';
import { useAuthStore } from '@/stores/auth';
import { getStreamUrl, getProgress } from '@/api/playback';
import { useProgressReporter } from '@/hooks/useProgress';
import type { FileItem } from '@/api/types';
import styles from './InlinePlayer.module.css';

interface Props {
  file: FileItem;
  onClose: () => void;
}

export default function InlinePlayer({ file, onClose }: Props) {
  const token = useAuthStore((s) => s.token);
  const playerRef = useRef<Player | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  const initialPositionRef = useRef(0);

  // 获取上次播放进度
  useEffect(() => {
    getProgress(file.id)
      .then((res) => {
        initialPositionRef.current = res.position ?? 0;
      })
      .catch(() => {})
      .finally(() => {
        setReady(true);
      });
  }, [file.id]);

  // 进度上报
  useProgressReporter(file.id, playerRef);

  // 创建播放器
  useEffect(() => {
    if (!ready || !token || !containerRef.current) return;

    const player = new Player({
      el: containerRef.current,
      url: getStreamUrl(file.id, token),
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
  }, [file.id, ready, token]);

  return (
    <div className={styles.wrapper}>
      <div className={styles.header}>
        <span className={styles.title}>{file.filename}</span>
        <Button
          type="text"
          size="small"
          icon={<CloseOutlined />}
          className={styles.closeBtn}
          onClick={onClose}
        />
      </div>
      {!ready ? (
        <div className={styles.loading}>
          <Spin size="large" />
        </div>
      ) : (
        <div ref={containerRef} className={styles.playerContainer} />
      )}
    </div>
  );
}
