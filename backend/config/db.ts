import mongoose from "mongoose";
import { env } from "./env.js";

export const connectDB = async (): Promise<void> => {
  try {
    console.log("🔄 Connecting to MongoDB...");

    const conn = await mongoose.connect(env.MONGODB_URI, {
      dbName: "smart_travel_planner",
    });

    console.log("====================================");
    console.log("✅ MongoDB Connected Successfully");
    console.log("📡 Host:", conn.connection.host);
    console.log("📁 Database:", conn.connection.name);
    console.log("====================================");
  } catch (error) {
    console.error("❌ MongoDB Connection Failed");
    console.error(error);

    process.exit(1); //! 1 is failure, 0 is success message
  }
};
let isConnected = false;

export const connectOnce = async () => {
  if(isConnected) return;

  if(!env.MONGODB_URI) throw new Error("MONGODB_URI is missing");

  await connectDB();
  isConnected = true;
}