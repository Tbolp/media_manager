import client from './client';
import type { User } from './types';

export async function getUsers() {
  const res = await client.get<{ items: User[] }>('/users');
  return res.data;
}

export async function createUser(data: { username: string; password: string; role: string }) {
  return client.post('/users', data);
}

export async function disableUser(id: string) {
  return client.patch(`/users/${id}/disable`);
}

export async function enableUser(id: string) {
  return client.patch(`/users/${id}/enable`);
}

export async function deleteUser(id: string) {
  return client.delete(`/users/${id}`);
}

export async function resetPassword(id: string, password: string) {
  return client.put(`/users/${id}/password`, { password });
}

export async function updatePermissions(id: string, libraryIds: string[]) {
  return client.put(`/users/${id}/permissions`, { library_ids: libraryIds });
}
