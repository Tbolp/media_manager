import client from './client';
import type { DashboardData, LibraryTasks, PaginatedResponse, LogEntry } from './types';

export async function getDashboard() {
  const res = await client.get<DashboardData>('/system/dashboard');
  return res.data;
}

export async function getTasks() {
  const res = await client.get<{ items: LibraryTasks[] }>('/system/tasks');
  return res.data;
}

export async function getLogs(params: { q?: string; page?: number; page_size?: number }) {
  const res = await client.get<PaginatedResponse<LogEntry>>('/system/logs', { params });
  return res.data;
}
