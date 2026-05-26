import User from "../models/user.model.js";
import jwt from "jsonwebtoken";
import type { JwtPayload } from "jsonwebtoken";
import { env } from "../config/env.js";
import type { Request, Response, NextFunction } from "express";
import { AppError } from "../utils/error_api_response.js";

export interface DecodedToken extends JwtPayload {
  userId: string;
}

export const protectRoute = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Accept token from either:
    //   1. Authorization: Bearer <token>  ← Flutter mobile app sends this
    //   2. Cookie: accessToken=<token>    ← Web browser sends this (unchanged)
    let token: string | undefined = req.cookies.accessToken;

    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith("Bearer ")) {
      token = authHeader.substring(7); // strip "Bearer " prefix
    }

    if (!token) {
      throw new AppError(401, "Unauthorized");
    }

    const decoded = jwt.verify(token, env.JWT_ACCESS_TOKEN) as DecodedToken;
    if (!decoded?.userId) {
      throw new AppError(401, "Unauthorized");
    }

    const user = await User.findById(decoded.userId).select("-password");
    if (!user) throw new AppError(401, "User not found, authorization denied");

    req.user = user;
    next();

  } catch (error) {
    if (
      error instanceof jwt.TokenExpiredError ||
      error instanceof jwt.JsonWebTokenError
    ) {
      return next(new AppError(401, "Unauthorized"));
    }
    next(error);
  }
};
