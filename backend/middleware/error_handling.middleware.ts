import type { Request, Response, NextFunction } from "express";

interface AppError extends Error {
    statusCode?: number;
}

export const errorHandlingMiddleware = (
    error: AppError,
    req: Request,
    res: Response,
    next: NextFunction
) => {
    res.status(error.statusCode || 500).json({
        success: false,
        message: error.message || "Internal Server Error",
        data: null
    });
}