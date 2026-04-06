import { useState, useEffect, useCallback } from 'react';
import { Card, Tag, List, Empty, Badge, Spin } from 'antd';
import { getTasks } from '@/api/system';
import { usePolling } from '@/hooks/usePolling';
import { POLLING_INTERVAL } from '@/utils/constants';
import { formatDateTime } from '@/utils/format';
import type { LibraryTasks, TaskInfo } from '@/api/types';

export default function TaskCenter() {
  const [tasksList, setTasksList] = useState<LibraryTasks[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchTasks = useCallback(async () => {
    try {
      const data = await getTasks();
      setTasksList(data.items);
    } catch {
      // 拦截器已处理
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  const hasActive = tasksList.some(
    (lib) => lib.current_task != null || lib.pending_count > 0,
  );

  usePolling(
    async () => {
      const data = await getTasks();
      setTasksList(data.items);
      return data.items.some(
        (lib) => lib.current_task != null || lib.pending_count > 0,
      );
    },
    POLLING_INTERVAL,
    hasActive,
  );

  const renderTaskStatus = (task: TaskInfo) => {
    const colors: Record<string, string> = {
      running: 'processing',
      success: 'success',
      failed: 'error',
    };
    return (
      <Tag color={colors[task.status] ?? 'default'}>
        {task.task_type === 'full' ? '全量刷新' : `定向: ${task.target_file ?? ''}`}
        {' - '}
        {task.status === 'running' ? '执行中' : task.status === 'success' ? '成功' : '失败'}
      </Tag>
    );
  };

  if (loading) return <Spin />;
  if (tasksList.length === 0) return <Empty description="暂无任务数据" />;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {tasksList.map((lib) => (
        <Card
          key={lib.library_id}
          title={
            <span>
              {lib.library_name}
              {lib.current_task && <Badge status="processing" style={{ marginLeft: 8 }} />}
            </span>
          }
          size="small"
        >
          {/* 当前任务 */}
          {lib.current_task ? (
            <div style={{ marginBottom: 8 }}>
              <strong>当前任务：</strong>
              {renderTaskStatus(lib.current_task)}
              {lib.current_task.started_at && (
                <span style={{ color: '#999', marginLeft: 8 }}>
                  开始于 {formatDateTime(lib.current_task.started_at)}
                </span>
              )}
            </div>
          ) : (
            <div style={{ marginBottom: 8, color: '#999' }}>当前无任务</div>
          )}

          {/* 待执行 */}
          {lib.pending_count > 0 && (
            <div style={{ marginBottom: 8 }}>
              <strong>待执行：</strong>{lib.pending_count} 个任务
            </div>
          )}

          {/* 最近完成 */}
          {lib.recent_tasks.length > 0 && (
            <div>
              <strong>最近完成：</strong>
              <List
                size="small"
                dataSource={lib.recent_tasks}
                renderItem={(task) => (
                  <List.Item>
                    {renderTaskStatus(task)}
                    {task.finished_at && (
                      <span style={{ color: '#999' }}>
                        {formatDateTime(task.finished_at)}
                      </span>
                    )}
                    {task.error && (
                      <span style={{ color: '#ff4d4f', marginLeft: 8 }}>
                        {task.error}
                      </span>
                    )}
                  </List.Item>
                )}
              />
            </div>
          )}
        </Card>
      ))}
    </div>
  );
}
