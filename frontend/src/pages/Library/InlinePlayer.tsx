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

  // 组件卸载时释放视频资源，防止内存泄漏
  useEffect(() => {
    return () => {
      const video = videoRef.current;
      if (video) {
        video.pause();
        video.removeAttribute('src');
        video.load(); // 强制释放已缓冲的数据
      }
    };
  }, []);

  // 设置初始播放位置并自动播放
  useEffect(() => {
    const video = videoRef.current;
    if (!ready || !video) return;
    let cancelled = false;

    const startPlayback = () => {
      if (cancelled) return;
      if (initialPositionRef.current > 0) {
        video.currentTime = initialPositionRef.current;
      }
      video.play().catch(() => {
        // 浏览器自动播放策略阻止，不再重试，由用户手动点击播放
      });
    };

    if (video.readyState >= 1) {
      startPlayback();
    } else {
      video.addEventListener('loadedmetadata', startPlayback, { once: true });
    }

    return () => {
      cancelled = true;
      video.removeEventListener('loadedmetadata', startPlayback);
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
          playsInline
          preload="auto"
          onError={handleError}
        />
      )}
    </div>
  );
}
