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
    const token = req.cookies.accessToken;
    console.log("Token from cookies: ", token);
    if (!token) {
      throw new AppError(401, "Unauthorized");
    }

    //! decoded jwt token
    const decoded = jwt.verify(token, env.JWT_ACCESS_TOKEN) as DecodedToken;
    if (!decoded?.userId) {
      throw new AppError(401, "Unauthorized");
    }
    //! select all user attrbute exclude only password.
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