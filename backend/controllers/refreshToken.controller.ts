import type { Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import User from "../models/user.model.js";
import generateTokensAndSetCookies from "../utils/auth/generate_tokens_and_set_cookies.js";
import { successApiResponse } from "../utils/succes_api_response.js";
import type { DecodedToken } from "../middleware/protect_route.middleware.js";
import { AppError } from "../utils/error_api_response.js";

const getAccessTokenWithRefreshToken = async (req: Request, res: Response) => {
  // Accept refresh token from either:
  //   1. Authorization: Bearer <token>  ← Flutter mobile sends this
  //   2. Cookie: refreshToken=<token>   ← Web browser sends this (unchanged)
  let token: string | undefined = req.cookies.refreshToken;

  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    token = authHeader.substring(7);
  }

  if (!token) {
    throw new AppError(401, "Unauthorized");
  }

  const decoded = jwt.verify(token, env.JWT_REFRESH_TOKEN) as DecodedToken;
  const user = await User.findById(decoded.userId);

  if (!user) {
    throw new AppError(404, "User not found");
  }

  const { accessToken, refreshToken } = generateTokensAndSetCookies(user._id, res);

  successApiResponse(res, 201, "refresh token generated successfully!", {
    accessToken,
    refreshToken, // Flutter reads this; web still gets the cookie
  });
};

export default {
  getAccessTokenWithRefreshToken,
};
