import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";
import dotenv from "dotenv";

dotenv.config();
export const env = createEnv({
  server: {
    PORT: z.string().optional(),
    FRONTEND_URL: z.url().min(1, "FRONTEND_URL is required"),
    MONGODB_URI: z.string().min(1, "MONGODB_URI is required"),
    JWT_ACCESS_TOKEN: z.string().min(1, "Access token is requried"),
    JWT_REFRESH_TOKEN: z.string().min(1, "Refresh token is required"),
    NODE_ENV: z.string().min(1, "Node environment is required"),
    CLOUDINARY_API_KEY: z.string().min(1, "CLOUDINARY_API_KEY is required"),
    CLOUDINARY_API_SECRET: z.string().min(1, "CLOUDINARY_API_SECRET is required"),
    CLOUDINARY_CLOUD_NAME: z.string().min(1, "CLOUDINARY_NAME is required")
  },

  runtimeEnv: process.env,
});