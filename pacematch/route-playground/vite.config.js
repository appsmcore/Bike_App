import { defineConfig } from 'vite';

export default defineConfig({
  // Shared secrets live in pacematch/.env (parent of this folder).
  envDir: '..',
  server: {
    port: 5173,
    open: true,
  },
});
