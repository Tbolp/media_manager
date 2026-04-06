import client from './client';
import type { FileProgress } from './types';

export function getStreamUrl(fid: string, token: string): string {
  const base = import.meta.env.VITE_API_BASE || '/api';
  return `${base}/files/${fid}/stream?token=${encodeURIComponent(token)}`;
}

export function getRawImageUrl(fid: string, token: string): string {
  const base = import.meta.env.VITE_API_BASE || '/api';
  return `${base}/files/${fid}/raw?token=${encodeURIComponent(token)}`;
}

export function getThumbnailUrl(fid: string, token: string): string {
  const base = import.meta.env.VITE_API_BASE || '/api';
  return `${base}/files/${fid}/thumbnail?token=${encodeURIComponent(token)}`;
}

export async function getProgress(fid: string): Promise<FileProgress> {
  const res = await client.get<FileProgress>(`/files/${fid}/progress`);
  return res.data;
}

export async function reportProgress(fid: string, position: number, duration: number) {
  return client.put(`/files/${fid}/progress`, { position, duration });
}
