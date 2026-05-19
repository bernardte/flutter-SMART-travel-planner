import jwt from "jsonwebtoken";
import type { Response } from "express";
import { env } from "../../config/env.js";
import { type ObjectId } from "mongoose";

function generateTokensAndSetCookies(userId: ObjectId, res: Response) {
  const accessToken = jwt.sign({ userId }, env.JWT_ACCESS_TOKEN, {
    expiresIn: "2h",
  });

  const refreshToken = jwt.sign({ userId }, env.JWT_REFRESH_TOKEN, {
    expiresIn: "7d",
  });

  res.cookie("refreshToken", refreshToken, {
    httpOnly: true,
    maxAge: 7 * 24 * 60 * 60 * 1000,
    sameSite: env.NODE_ENV === "production" ? "none" : "lax",
    secure: env.NODE_ENV === "production", //? return boolean ? true : false
  });

  res.cookie("accessToken", accessToken, {
    httpOnly: true,
    maxAge: 2 * 60 * 60 * 1000,
    sameSite: env.NODE_ENV === "production" ? "none" : "lax",
    secure: env.NODE_ENV === "production", //? return boolean  ? true : false
  });

  return { accessToken };
}

export default generateTokensAndSetCookies;