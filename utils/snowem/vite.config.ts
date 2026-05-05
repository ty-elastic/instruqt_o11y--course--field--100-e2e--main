import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  root: 'src/client',
  build: {
    outDir: '../../dist/client',
    emptyOutDir: true,
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'https://localhost:3000',
        secure: false,
      },
      '/_internal': {
        target: 'https://localhost:3000',
        secure: false,
      },
    },
  },
});
