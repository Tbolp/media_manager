import { Tabs } from 'antd';
import Dashboard from './Dashboard';
import TaskCenter from './TaskCenter';
import Logs from './Logs';

export default function SystemPage() {
  return (
    <div>
      <h2 style={{ marginBottom: 16 }}>系统运维</h2>
      <Tabs
        defaultActiveKey="dashboard"
        items={[
          { key: 'dashboard', label: '仪表盘', children: <Dashboard /> },
          { key: 'tasks', label: '任务中心', children: <TaskCenter /> },
          { key: 'logs', label: '日志', children: <Logs /> },
        ]}
      />
    </div>
  );
}
