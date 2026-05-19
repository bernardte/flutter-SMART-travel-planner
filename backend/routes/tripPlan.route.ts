import express from "express";
import multer from "multer";
import { asyncHandler } from "../utils/async_handler.js";
import { protectRoute } from "../middleware/protect_route.middleware.js";
import travelGuideControllers from "../controllers/tripPlan.controller.js";
import { optionalAuth } from "../middleware/optional_auth.middleware.js";

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.post(
  "/create",
  protectRoute,
  upload.single("thumbnailImage"),
  asyncHandler(travelGuideControllers.createTrip),
);

router.get(
  "/by-itinerary/:tripId",
  protectRoute,
  asyncHandler(travelGuideControllers.getTripPlanByTripId),
);

router.get(
  "/:tripPlanId",
  optionalAuth,
  asyncHandler(travelGuideControllers.getTripPlan),
);

router.put(
  "/:tripPlanId",
  protectRoute,
  upload.single("thumbnailImage"),
  asyncHandler(travelGuideControllers.updateTripPlan),
);

router
  .route("/:tripPlanId/comments")
  .get(travelGuideControllers.getSpecificTripPlanComment)
  .post(protectRoute, travelGuideControllers.createCommentTripPlanApi);

router
  .route("/:tripPlanId/comments/:reviewId")
  .patch(protectRoute, travelGuideControllers.updateSpecificTripPlanComment)
  .delete(protectRoute, travelGuideControllers.deleteSpecificTripPlanComment);

export default router;
