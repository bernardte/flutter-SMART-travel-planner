import express from "express";
import { asyncHandler } from "../utils/async_handler.js";
import refreshTokenController from "../controllers/refreshToken.controller.js";

const route = express.Router();

route.get("/", asyncHandler(refreshTokenController.getAccessTokenWithRefreshToken));

export default route;