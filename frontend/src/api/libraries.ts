import client from './client';
import type {
  Library,
  CreateLibraryRequest,
  FileListResponse,
} from './types';

export async function getLibraries() {
  const res = await client.get<{ items: Library[] }>('/libraries');
  return res.data;
}

export async function createLibrary(data: CreateLibraryRequest) {
  const res = await client.post<Library>('/libraries', data);
  return res.data;
}

export async function renameLibrary(id: string, name: string) {
  return client.patch(`/libraries/${id}`, { name });
}

export async function deleteLibrary(id: string) {
  return client.delete(`/libraries/${id}`);
}

export async function getFiles(
  libraryId: string,
  params: { path?: string; q?: string; page?: number; page_size?: number },
) {
  const res = await client.get<FileListResponse>(`/libraries/${libraryId}/files`, { params });
  return res.data;
}

export async function refreshLibrary(id: string) {
  return client.post(`/libraries/${id}/refresh`);
}

export async function uploadFile(
  libraryId: string,
  file: File,
  path: string,
  onProgress: (percent: number) => void,
  signal?: AbortSignal,
): Promise<void> {
  await client.post(
    `/libraries/${libraryId}/upload`,
    file,
    {
      params: { path },
      timeout: 0,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': `attachment; filename="${encodeURIComponent(file.name)}"`,
      },
      onUploadProgress: (e) => {
        if (e.total) {
          onProgress(Math.round((e.loaded / e.total) * 100));
        }
      },
      signal,
    },
  );
}
