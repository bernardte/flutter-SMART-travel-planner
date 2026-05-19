import jwt from "jsonwebtoken";
import type { Request, Response, NextFunction } from "express";
import { env } from "../config/env.js";
import User from "../models/user.model.js";
import type { DecodedToken } from "./protect_route.middleware.js";
export const optionalAuth = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const token = req.cookies.accessToken;

        if (!token) {
            delete (req as any).user;
            return next();
        }

        const decoded = jwt.verify(token, env.JWT_ACCESS_TOKEN) as DecodedToken;

        const user = await User.findById(decoded.userId).select("-password"); 
    
        req.user = user;
        next();
    } catch {
        req.user = null;
        next();
    }
}