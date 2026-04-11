import { useRef } from 'react';
import { Button, Progress, message, Space } from 'antd';
import { UploadOutlined, CloseOutlined } from '@ant-design/icons';
import { useUploadStore } from '@/stores/upload';
import { uploadFile } from '@/api/libraries';
import { AxiosError } from 'axios';
import type { LibType } from '@/api/types';

interface Props {
  libraryId: string;
  libType: LibType;
  currentPath: string;
  onUploadComplete: () => void;
}

export default function UploadButton({ libraryId, libType, currentPath, onUploadComplete }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const upload = useUploadStore((s) => s.uploads[libraryId]);
  const { startUpload, updateProgress, finishUpload, cancelUpload, clearUpload } = useUploadStore();

  const accept = libType === 'video' ? '.mp4,.mkv' : '.mp4,.mkv,.jpg,.png';
  const isUploading = upload?.status === 'uploading';

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // 清空 input 以允许重复选择同一文件
    e.target.value = '';

    const ac = new AbortController();
    startUpload(libraryId, file.name, ac);

    try {
      await uploadFile(
        libraryId,
        file,
        currentPath,
        (percent) => updateProgress(libraryId, percent),
        ac.signal,
      );
      finishUpload(libraryId, 'success');
      message.success('上传成功');
      onUploadComplete();
      // 延迟清理状态
      setTimeout(() => clearUpload(libraryId), 2000);
    } catch (err) {
      if (ac.signal.aborted) return;
      const error = err as AxiosError<{ detail?: string }>;
      if (error.response?.status === 409) {
        message.warning('当前有上传任务进行中，请等待完成后再上传');
      } else {
        message.error('上传失败，请重试');
      }
      finishUpload(libraryId, 'failed');
    }
  };

  const handleCancel = () => {
    cancelUpload(libraryId);
    message.info('上传已取消');
    setTimeout(() => clearUpload(libraryId), 1000);
  };

  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        style={{ display: 'none' }}
        onChange={handleFileSelect}
      />
      <Button
        icon={<UploadOutlined />}
        onClick={() => inputRef.current?.click()}
        disabled={isUploading}
      >
        上传
      </Button>
      {upload && upload.status === 'uploading' && (
        <Space>
          <Progress
            percent={upload.progress}
            size="small"
            style={{ width: 120 }}
            status="active"
          />
          <Button
            type="text"
            size="small"
            icon={<CloseOutlined />}
            onClick={handleCancel}
            danger
          />
        </Space>
      )}
      {upload?.status === 'failed' && (
        <Button size="small" onClick={() => inputRef.current?.click()}>
          重试
        </Button>
      )}
    </div>
  );
}
