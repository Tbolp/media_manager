import client from './client';
import type { InitRequest, LoginRequest, LoginResponse } from './types';

export async function getInitStatus(): Promise<boolean> {
  const res = await client.get<{ initialized: boolean }>('/init/status');
  return res.data.initialized;
}

export async function init(data: InitRequest) {
  return client.post('/init', data);
}

export async function login(data: LoginRequest) {
  const res = await client.post<LoginResponse>('/login', data);
  return res.data;
}

export async function logout() {
  return client.post('/logout');
}
