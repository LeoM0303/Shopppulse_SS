import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api": {
        target: (process.env as Record<string, string>)["VITE_API_BASE_URL"] || "http://localhost:8000",
        changeOrigin: true,
      },
    },
  },
});
