import type { Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import User from "../models/user.model.js";
import generateTokensAndSetCookies from "../utils/auth/generate_tokens_and_set_cookies.js";
import { successApiResponse } from "../utils/succes_api_response.js";
import type { DecodedToken } from "../middleware/protect_route.middleware.js";
import { AppError } from "../utils/error_api_response.js";


const getAccessTokenWithRefreshToken = async (req: Request, res: Response) => {
  const token = req.cookies.refreshToken;
  if (!token) {
    throw new AppError(401, "Unauthorized");
  }

  const decoded = jwt.verify(token, env.JWT_REFRESH_TOKEN)  as DecodedToken;
  const user = await User.findById(decoded.userId); 

  if (!user) {
    throw new AppError(404, "User not found");
  }

  const { accessToken } = generateTokensAndSetCookies(user._id, res);

  user.password = ""; //? Remove password from user object

  successApiResponse(res, 201, "refresh token generated successfully!", {
    accessToken,
  });
};

export default {
  getAccessTokenWithRefreshToken,
};
