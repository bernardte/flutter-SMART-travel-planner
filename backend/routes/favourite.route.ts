import express from "express";
import { asyncHandler } from "../utils/async_handler.js";
import favouriteController from "../controllers/favourite.controller.js";
import { protectRoute } from "../middleware/protect_route.middleware.js";

const route = express.Router();

route.get(
  "/",
  protectRoute,
  asyncHandler(favouriteController.getAllFavourite),
);


export default route;
