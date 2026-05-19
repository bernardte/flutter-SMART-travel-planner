import express from "express";
import { asyncHandler } from "../utils/async_handler.js";
import { protectRoute } from "../middleware/protect_route.middleware.js";
import tripController from "../controllers/trip.controller.js";

const router = express.Router();

router.post("/save", protectRoute, asyncHandler(tripController.saveTrip));
router.get("/my-trips", protectRoute, asyncHandler(tripController.getMyTrips));
router.get("/popular-destination", asyncHandler(tripController.getPopularDestination));
router.get("/:id", protectRoute, asyncHandler(tripController.getTripById));
router.put("/:id", protectRoute, asyncHandler(tripController.updateTrip));
router.delete("/:id", protectRoute, asyncHandler(tripController.deleteTrip));

export default router;