import { useState, useEffect, useCallback } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import { Button, Skeleton, Empty, message, Input, Space } from 'antd';
import { ReloadOutlined, EditOutlined } from '@ant-design/icons';
import { useAuthStore } from '@/stores/auth';
import { getFiles, getLibrary, refreshLibrary, renameLibrary } from '@/api/libraries';
import { RefreshStatus } from '@/components/RefreshStatus';
import { DEFAULT_PAGE_SIZE } from '@/utils/constants';
import type { Library, FileItem, RefreshStatus as RefreshStatusType } from '@/api/types';
import FileList from './FileList';
import DirBreadcrumb from './DirBreadcrumb';
import SearchBar from './SearchBar';
import UploadButton from './UploadButton';
import ImageLightbox from './ImageLightbox';
import InlinePlayer from './InlinePlayer';

export default function LibraryPage() {
  const { id: libraryId } = useParams<{ id: string }>();
  const isAdmin = useAuthStore((s) => s.isAdmin);
  const [searchParams, setSearchParams] = useSearchParams();

  const currentPath = searchParams.get('path') || '';
  const searchQuery = searchParams.get('q') || '';
  const page = Number(searchParams.get('page') || '1');

  const [library, setLibrary] = useState<Library | null>(null);
  const [files, setFiles] = useState<FileItem[]>([]);
  const [dirs, setDirs] = useState<string[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [refreshStatus, setRefreshStatus] = useState<RefreshStatusType>('idle');

  // 改名相关
  const [renaming, setRenaming] = useState(false);
  const [newName, setNewName] = useState('');

  // 灯箱相关
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [lightboxIndex, setLightboxIndex] = useState(0);

  // 内嵌播放器
  const [playingFile, setPlayingFile] = useState<FileItem | null>(null);
  const [lastPlayedId, setLastPlayedId] = useState<string | null>(null);

  const imageFiles = files.filter((f) => f.file_type === 'image');

  const fetchLibraryInfo = useCallback(async () => {
    if (!libraryId) return;
    try {
      const lib = await getLibrary(libraryId);
      setLibrary(lib);
      setRefreshStatus(lib.refresh_status);
    } catch {
      // 拦截器已处理
    }
  }, [libraryId]);

  const fetchFiles = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const data = await getFiles(libraryId, {
        path: searchQuery ? undefined : currentPath || undefined,
        q: searchQuery || undefined,
        page,
        page_size: DEFAULT_PAGE_SIZE,
      });
      setFiles(data.items);
      setDirs(data.dirs ?? []);
      setTotal(data.total);
    } catch {
      // 拦截器已处理
    } finally {
      setLoading(false);
    }
  }, [libraryId, currentPath, searchQuery, page]);

  useEffect(() => {
    fetchLibraryInfo();
  }, [fetchLibraryInfo]);

  // 关闭播放器后，滚动到上次播放的文件卡片
  useEffect(() => {
    if (lastPlayedId && !playingFile) {
      requestAnimationFrame(() => {
        const el = document.getElementById(`file-${lastPlayedId}`);
        if (el) {
          el.scrollIntoView({ block: 'start', behavior: 'instant' });
        }
        setLastPlayedId(null);
      });
    }
  }, [lastPlayedId, playingFile]);

  useEffect(() => {
    fetchFiles();
  }, [fetchFiles]);

  const handleEnterDir = (dirName: string) => {
    const newPath = currentPath ? `${currentPath}/${dirName}` : dirName;
    setSearchParams({ path: newPath });
  };

  const handleNavigate = (targetPath: string) => {
    setSearchParams(targetPath ? { path: targetPath } : {});
  };

  const handleSearch = (q: string) => {
    if (q) {
      setSearchParams({ q });
    } else {
      setSearchParams(currentPath ? { path: currentPath } : {});
    }
  };

  const handlePageChange = (newPage: number) => {
    const params: Record<string, string> = {};
    if (searchQuery) params.q = searchQuery;
    else if (currentPath) params.path = currentPath;
    if (newPage > 1) params.page = String(newPage);
    setSearchParams(params);
  };

  const handleRefresh = async () => {
    if (!libraryId) return;
    try {
      await refreshLibrary(libraryId);
      setRefreshStatus('pending');
      message.success('已触发刷新');
    } catch {
      message.error('刷新触发失败');
    }
  };

  const handleRename = async () => {
    if (!libraryId || !newName.trim()) return;
    try {
      await renameLibrary(libraryId, newName.trim());
      message.success('改名成功');
      setRenaming(false);
      fetchLibraryInfo();
    } catch {
      message.error('改名失败');
    }
  };

  const handleRefreshComplete = () => {
    setRefreshStatus('idle');
    fetchFiles();
  };

  const handleImageClick = (fileId: string) => {
    const idx = imageFiles.findIndex((f) => f.id === fileId);
    if (idx >= 0) {
      setLightboxIndex(idx);
      setLightboxOpen(true);
    }
  };

  if (!libraryId) return null;

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, flexWrap: 'wrap', gap: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {renaming ? (
            <Space.Compact>
              <Input
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                onPressEnter={handleRename}
                style={{ width: 200 }}
              />
              <Button type="primary" onClick={handleRename}>确定</Button>
              <Button onClick={() => setRenaming(false)}>取消</Button>
            </Space.Compact>
          ) : (
            <>
              <h2 style={{ margin: 0 }}>{library?.name ?? '加载中...'}</h2>
              {isAdmin && (
                <Button
                  type="text"
                  size="small"
                  icon={<EditOutlined />}
                  onClick={() => { setNewName(library?.name ?? ''); setRenaming(true); }}
                />
              )}
            </>
          )}
        </div>
        <Space>
          <SearchBar onSearch={handleSearch} initialValue={searchQuery} />
          <Button icon={<ReloadOutlined />} onClick={handleRefresh}>刷新</Button>
          <UploadButton
            libraryId={libraryId}
            libType={library?.lib_type ?? 'video'}
            currentPath={currentPath}
            onUploadComplete={() => { setRefreshStatus('pending'); }}
          />
        </Space>
      </div>

      {/* 刷新状态 */}
      <RefreshStatus
        libraryId={libraryId}
        initialStatus={refreshStatus}
        onRefreshComplete={handleRefreshComplete}
      />

      {/* 面包屑（非搜索模式下显示） */}
      {!searchQuery && (
        <DirBreadcrumb
          libraryName={library?.name ?? ''}
          currentPath={currentPath}
          onNavigate={(path) => { setPlayingFile(null); handleNavigate(path); }}
        />
      )}

      {/* 播放器 */}
      {playingFile && (
        <InlinePlayer
          key={playingFile.id}
          file={playingFile}
          onClose={() => { setLastPlayedId(playingFile?.id ?? null); setPlayingFile(null); }}
        />
      )}

      {/* 文件列表（播放时隐藏但不卸载，保留滚动位置） */}
      <div style={{ display: playingFile ? 'none' : undefined }}>
        {loading ? (
          <Skeleton active paragraph={{ rows: 8 }} />
        ) : files.length === 0 && dirs.length === 0 ? (
          <Empty description={searchQuery ? '未找到匹配文件' : '当前目录为空'} />
        ) : (
          <FileList
            libraryId={libraryId}
            files={files}
            dirs={searchQuery ? [] : dirs}
            total={total}
            page={page}
            pageSize={DEFAULT_PAGE_SIZE}
            isSearchMode={!!searchQuery}
            onEnterDir={handleEnterDir}
            onPageChange={handlePageChange}
            onImageClick={handleImageClick}
            onVideoClick={(file) => { setPlayingFile(file); window.scrollTo(0, 0); }}
          />
        )}
      </div>

      {/* 图片灯箱 */}
      <ImageLightbox
        images={imageFiles}
        index={lightboxIndex}
        open={lightboxOpen}
        onClose={() => setLightboxOpen(false)}
      />
    </div>
  );
}
