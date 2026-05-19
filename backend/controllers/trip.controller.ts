import type { Request, Response } from "express";
import Trip from "../models/trip.model.js";
import { successApiResponse } from "../utils/succes_api_response.js";
import { AppError } from "../utils/error_api_response.js";
import type { SaveTripBodyDTO } from "../types/DTO/trip.dto.js";
import TripPlan from "../models/tripPlan.model.js";
import CommunityTravelGuide from "../models/community.model.js";

const saveTrip = async (
  req: Request<{}, {}, SaveTripBodyDTO>,
  res: Response,
): Promise<void> => {
  if (!req.user) throw new AppError(401, "Unauthorized");
  const userId = req.user._id;
  const { country, startDate, endDate, days } = req.body;

  if (!country?.trim()) throw new AppError(400, "Country is required.");
  if (!startDate?.trim() || !endDate?.trim())
    throw new AppError(400, "Start date and end date are required.");
  if (!Array.isArray(days) || days.length === 0)
    throw new AppError(400, "At least one day is required.");

  const trip = await Trip.create({ userId, country, startDate, endDate, days });
  successApiResponse(res, 201, "Trip saved successfully", { trip });
};

const getMyTrips = async (req: Request, res: Response): Promise<void> => {
  if (!req.user) throw new AppError(401, "Unauthorized");
  const userId = req.user._id;

  const trips = await Trip.find({ userId }).sort({ createdAt: -1 });

  // For each trip, find its tripPlan and attach the tripPlanId
  const tripsWithPlanId = await Promise.all(
    trips.map(async (trip) => {
      const tripPlan = await TripPlan.findOne({
        tripId: trip._id,
      } as any).select("_id");
      return {
        ...trip.toObject(),
        tripPlanId: tripPlan?._id?.toString() ?? null,
      };
    }),
  );

  successApiResponse(res, 200, "Trips fetched successfully", {
    trips: tripsWithPlanId,
  });
};

const getTripById = async (
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> => {
  if (!req.user) throw new AppError(401, "Unauthorized");
  const userId = req.user._id;
  const { id } = req.params;

  const trip = await Trip.findOne({
    _id: id,
    userId,
  } as any);

  if (!trip) throw new AppError(404, "Trip not found.");
  successApiResponse(res, 200, "Trip fetched successfully", { trip });
};

const updateTrip = async (
  req: Request<{ id: string }, {}, SaveTripBodyDTO>,
  res: Response,
): Promise<void> => {
  if (!req.user) throw new AppError(401, "Unauthorized");
  const userId = req.user._id;
  const { id } = req.params;
  const { country, startDate, endDate, days } = req.body;

  if (!country?.trim()) throw new AppError(400, "Country is required.");
  if (!startDate?.trim() || !endDate?.trim())
    throw new AppError(400, "Start date and end date are required.");

  const trip = await Trip.findOneAndUpdate(
    { _id: id, userId } as any,
    { country, startDate, endDate, days },
    { new: true },
  );

  if (!trip) throw new AppError(404, "Trip not found or not authorized.");
  successApiResponse(res, 200, "Trip updated successfully", { trip });
};

const deleteTrip = async (
  req: Request<{ id: string }>,
  res: Response,
): Promise<void> => {
  if (!req.user) throw new AppError(401, "Unauthorized");
  const userId = req.user._id;
  const { id } = req.params;

  const trip = await Trip.findOneAndDelete({
    _id: id,
    userId,
  } as any);

  if (!trip) throw new AppError(404, "Trip not found or not authorized.");
  successApiResponse(res, 200, "Trip deleted successfully");
};

const getPopularDestination = async (req: Request, res: Response) => {
  const result = await CommunityTravelGuide.aggregate([
    {
      $match: {
        privacy: "public",
      },
    },

    // 1. Compute per-post score
    {
      $addFields: {
        likesCount: { $size: "$likes" },
        score: {
          $add: [
            { $multiply: [{ $size: "$likes" }, 2] },
            { $multiply: ["$saves", 3] },
            "$views",
          ],
        },
      },
    },

    // 2. Group by country
    {
      $group: {
        _id: "$country",
        totalScore: { $sum: "$score" },
        totalLikes: { $sum: "$likesCount" },
        totalSaves: { $sum: "$saves" },
        totalViews: { $sum: "$views" },
        guides: { $push: "$$ROOT" },
      },
    },

    // 3. Sort countries by popularity
    {
      $sort: { totalScore: -1 },
    },

    // 4. Limit top countries
    {
      $limit: 5,
    },

    // 5. Clean output
    {
      $project: {
        _id: 0,
        country: "$_id",
        totalScore: 1,
        totalLikes: 1,
        totalSaves: 1,
        totalViews: 1,
        topGuide: { $arrayElemAt: ["$guides", 0] },
      },
    },
  ]);

  successApiResponse(res, 200, "Popular destination", result);
};

export default {
  saveTrip,
  getMyTrips,
  getTripById,
  updateTrip,
  deleteTrip,
  getPopularDestination,
};
