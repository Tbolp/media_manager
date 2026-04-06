import axios from 'axios';
import { message } from 'antd';
import { useAuthStore } from '@/stores/auth';

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE,
  timeout: 30000,
});

// 请求拦截器：注入 Authorization header
client.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 响应拦截器：统一错误处理
client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const errorCode = error.response.data?.error_code;
      useAuthStore.getState().handleUnauthorized(errorCode);
    } else if (error.response?.status === 403) {
      message.error('无权访问');
    } else if (error.response?.status === 409) {
      // 由调用方处理
    } else if (error.response?.status && error.response.status >= 500) {
      message.error('服务异常，请稍后再试');
    } else if (!error.response) {
      message.error('网络已断开');
    }
    return Promise.reject(error);
  }
);

export default client;
