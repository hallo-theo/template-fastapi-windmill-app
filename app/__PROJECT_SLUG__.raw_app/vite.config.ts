/// <reference types="vitest" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In dev with a real backend running:
//   export FRONTEND_SERVICE_SECRET=<token from .env.general>
//   export API_PROXY_TARGET=https://__CLOUD_RUN_SERVICE__-xxx.a.run.app  # optional
//   npm run dev
//
// Without these env vars the frontend runs without backend; /api/* requests
// will fail.
const apiTarget = process.env.API_PROXY_TARGET ?? 'http://localhost:8000';
const devSecret = process.env.FRONTEND_SERVICE_SECRET ?? '';
const devUserEmail = process.env.VITE_DEV_USER_EMAIL ?? 'dev@hallotheo.local';
const devUsername  = process.env.VITE_DEV_USER_USERNAME ?? 'dev';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
  },
  server: {
    proxy: {
      '/api': {
        target: apiTarget,
        changeOrigin: true,
        configure: devSecret
          ? (proxy) => {
              proxy.on('proxyReq', (proxyReq) => {
                proxyReq.setHeader('X-Service-Secret', devSecret);
                proxyReq.setHeader('X-Windmill-User', devUserEmail);
                proxyReq.setHeader('X-Windmill-Username', devUsername);
              });
            }
          : undefined,
      },
    },
  },
});
