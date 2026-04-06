import { useEffect, useRef, useState } from 'react';
import { Button, Spin, message } from 'antd';
import { CloseOutlined } from '@ant-design/icons';
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
  const videoRef = useRef<HTMLVideoElement | null>(null);
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

  // 进度上报（复用 useProgressReporter，接口兼容 { currentTime, duration, paused }）
  useProgressReporter(file.id, videoRef);

  // 设置初始播放位置
  useEffect(() => {
    const video = videoRef.current;
    if (!ready || !video) return;

    const onLoadedMetadata = () => {
      if (initialPositionRef.current > 0) {
        video.currentTime = initialPositionRef.current;
      }
    };

    video.addEventListener('loadedmetadata', onLoadedMetadata);

    // 如果 metadata 已加载（缓存命中）
    if (video.readyState >= 1 && initialPositionRef.current > 0) {
      video.currentTime = initialPositionRef.current;
    }

    return () => {
      video.removeEventListener('loadedmetadata', onLoadedMetadata);
    };
  }, [file.id, ready]);

  const handleError = () => {
    message.error('播放失败，请稍后再试');
  };

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
        <video
          ref={videoRef}
          className={styles.video}
          src={token ? getStreamUrl(file.id, token) : undefined}
          controls
          autoPlay
          playsInline
          preload="metadata"
          onError={handleError}
        />
      )}
    </div>
  );
}
