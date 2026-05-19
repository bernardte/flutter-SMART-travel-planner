import type { Request, Response } from "express";
import type { CreatTripPlanDTO } from "../types/DTO/travel_guide.dto.js";
import { AppError } from "../utils/error_api_response.js";
import mongoose, { Types } from "mongoose";
import { successApiResponse } from "../utils/succes_api_response.js";
import Trip from "../models/trip.model.js";
import TripPlan from "../models/tripPlan.model.js";
import CommunityTravelGuide from "../models/community.model.js";
import { mongoDBObjectIDConverter } from "../utils/helpers/mongoDBObjectIDConverter.js";
import type { createCommentDTO } from "../types/DTO/trip.dto.js";

const createTrip = async (
  req: Request<{}, {}, CreatTripPlanDTO>,
  res: Response,
) => {
  const title = req.body.title as string;
  const authorIntro = req.body.authorIntro as string;
  const tripId = req.body.tripId as string;
  const sections = JSON.parse(req.body.sections as string);
  console.log("sections: ", sections);
  const user = req.user;

  if (!title || !title.trim() || !sections || sections.length === 0) {
    throw new AppError(400, "Title and sections are required");
  }

  if (!tripId || !mongoose.Types.ObjectId.isValid(tripId)) {
    throw new AppError(400, "Invalid tripId");
  }

  const tripObjectId = new mongoose.Types.ObjectId(tripId);
  const existingGuide = await TripPlan.findOne({ tripId: tripObjectId });

  if (existingGuide) {
    throw new AppError(400, "Guide already exists for this trip");
  }

  const trip = await Trip.findById(tripObjectId).select(
    "country isTravelGuideCreated",
  );
  if (!trip?.country) throw new AppError(400, "Trip not found");

  const newGuide = new TripPlan({
    title,
    authorIntro,
    tripId: tripObjectId,
    userId: user?._id,
    country: trip.country,
    authorName: user?.username,
    authorAvatar: user?.profilePicture ?? "",
    sections: sections,
    publishStatus: "private",
  });

  await newGuide.save();
  trip.isTravelGuideCreated = true;
  await trip.save();

  successApiResponse(res, 201, "Travel guide created successfully!", newGuide);
};

const getTripPlan = async (req: Request, res: Response) => {
  const tripPlanId = req.params.tripPlanId as string;
  const userId = req.user?._id;

  if (!tripPlanId || !mongoose.Types.ObjectId.isValid(tripPlanId)) {
    throw new AppError(400, "Invalid tripPlanId");
  }

  const tripPlan = await TripPlan.findById(
    new mongoose.Types.ObjectId(tripPlanId),
  );
  console.log("trip plan: ", tripPlan);
  if (!tripPlan) throw new AppError(404, "Trip plan not found");

  if (userId !== undefined) {
    // @ts-ignore
    const userObjectId = mongoDBObjectIDConverter(userId);

    await CommunityTravelGuide.updateOne(
      {
        itineraryId: tripPlan._id,
        viewsBy: { $ne: userObjectId },
      },
      {
        $inc: { views: 1 },
        $addToSet: { viewsBy: userObjectId },
      },
    );

    console.log("trip plan id: ", tripPlan._id);
  }

  console.log("your trip plan", tripPlan);

  successApiResponse(res, 200, "Trip plan fetched successfully!", tripPlan);
};

const updateTripPlan = async (
  req: Request<{ tripPlanId: string }, {}, CreatTripPlanDTO>,
  res: Response,
) => {
  const tripPlanId = req.params.tripPlanId as string;
  const title = req.body.title as string;
  const authorIntro = req.body.authorIntro as string;
  const sections = JSON.parse(req.body.sections as string);
  const user = req.user;

  if (!tripPlanId || !mongoose.Types.ObjectId.isValid(tripPlanId)) {
    throw new AppError(400, "Invalid tripPlanId");
  }

  const tripPlan = await TripPlan.findById(
    new mongoose.Types.ObjectId(tripPlanId),
  );
  if (!tripPlan) throw new AppError(404, "Trip plan not found");

  if (tripPlan.userId.toString() !== user?._id.toString()) {
    throw new AppError(401, "Unauthorized");
  }

  if (title) tripPlan.title = title;
  if (authorIntro !== undefined) tripPlan.authorIntro = authorIntro;
  if (sections && sections.length > 0) tripPlan.sections = sections;

  await tripPlan.save();

  successApiResponse(res, 200, "Trip plan updated successfully!", tripPlan);
};

const getTripPlanByTripId = async (req: Request, res: Response) => {
  const tripId = req.params.tripId as string;

  console.log("Looking for tripId:", tripId);

  if (!tripId || !mongoose.Types.ObjectId.isValid(tripId)) {
    throw new AppError(400, "Invalid tripId");
  }

  const tripPlan = await TripPlan.findOne({
    tripId: new mongoose.Types.ObjectId(tripId),
  });

  console.log("Found tripPlan:", tripPlan);

  if (!tripPlan) throw new AppError(404, "Trip plan not found");

  successApiResponse(res, 200, "Trip plan fetched successfully!", tripPlan);
};

const createCommentTripPlanApi = async (
  req: Request<{ tripPlanId: string }, {}, createCommentDTO>,
  res: Response,
) => {
  const userId = req.user?._id;
  const { content } = req.body;
  const tripPlanId = req.params.tripPlanId;
  console.log("your content: ", content);

  if (!userId) throw new AppError(403, "Unauthorized");
  if (!content) throw new AppError(400, "comment is required!");
  if (!tripPlanId) throw new AppError(400, "Trip plan ID is required!");

  const tripPlanExist = await TripPlan.findById(tripPlanId).select("reviews");

  if (!tripPlanExist) throw new AppError(404, "Trip plan not found");

  const tripPlan = await TripPlan.findByIdAndUpdate(
    tripPlanId,
    {
      $push: {
        reviews: {
          user: userId,
          username: req.user?.username || "Unknown",
          content,
          createdAt: new Date(),
        },
      },
    },
    { new: true },
  ).populate("reviews.user", "username profilePicture");

  if (!tripPlan) throw new AppError(404, "Trip plan not found");

  return successApiResponse(
    res,
    201,
    "Comment created successfully",
    tripPlan.reviews.at(-1), // 👉 返回刚创建的 comment
  );
};

const getSpecificTripPlanComment = async (req: Request, res: Response) => {
  const tripPlanId = req.params.tripPlanId;

  if (!tripPlanId) throw new AppError(400, "Trip plan ID is required!");

  const tripPlan = await TripPlan.findById(tripPlanId)
    .select("reviews")
    .populate("reviews.user", "username profilePicture")

  if (!tripPlan) {
    throw new AppError(404, "Trip plan not found");
  }

  // 🔥 normalize comments
  const content = (tripPlan.reviews || [])
    .sort(
      (a: any, b: any) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    )
    .map((review: any) => ({
      _id: review._id,
      user: review.user,
      username: review.username,
      content: review.content,
      createdAt: review.createdAt,
    }));

  return successApiResponse(
    res,
    200,
    "Trip plan comments fetched successfully",
    {
      tripPlanId,
      content,
      total: content.length,
    },
  );
};

const deleteSpecificTripPlanComment = async (req: Request, res: Response) => {
  const reviewId = req.params.reviewId;
  const userId = req.user?._id;
  const tripPlanId = req.params.tripPlanId;

  if (!userId) throw new AppError(403, "Unauthorized");
  if (!tripPlanId) throw new AppError(400, "Trip Plan ID is required");
  if (!reviewId) throw new AppError(400, "Review ID is required");

  const result = await TripPlan.updateOne(
    {
      _id: tripPlanId,
      reviews: {
        $elemMatch: {
          _id: reviewId,
          user: userId, //! only allow delete own comment
        },
      },
    },
    {
      $pull: {
        reviews: { _id: reviewId },
      },
    },
  );

  if (result.modifiedCount === 0) {
    throw new AppError(404, "Comment not found or no permission");
  }

  return successApiResponse(res, 200, "Comment deleted successfully", null);
};

const updateSpecificTripPlanComment = async (req: Request, res: Response) => {
  const reviewId = req.params.reviewId;
  const tripPlanId = req.params.tripPlanId;
  const userId = req.user?._id;
  const { content } = req.body;

  if (!reviewId) throw new AppError(400, "Review ID is required");
  if (!tripPlanId) throw new AppError(400, "Trip Plan ID is required");
  if (!userId) throw new AppError(403, "Unauthorized");
  if (!content) throw new AppError(400, "Comment is required");

  const tripPlan = await TripPlan.findOneAndUpdate(
    {
      _id: tripPlanId,
      reviews: {
        $elemMatch: {
          _id: reviewId,
          user: userId, //! only allow edit own comment
        },
      },
    },
    {
      $set: {
        "reviews.$[r].content": content,
        "reviews.$[r].updatedAt": new Date(),
      },
    },
    {
      new: true,
      arrayFilters: [
        {
          "r._id": reviewId,
          "r.user": userId,
        },
      ],
    },
  );


  if (!tripPlan) {
    throw new AppError(404, "Comment not found or no permission");
  }

  return successApiResponse(res, 200, "Comment updated successfully", {
    _id: reviewId,
    content,
    updatedAt: new Date(),
  });
};

export default {
  createTrip,
  getTripPlan,
  getTripPlanByTripId,
  updateTripPlan,
  createCommentTripPlanApi,
  getSpecificTripPlanComment,
  deleteSpecificTripPlanComment,
  updateSpecificTripPlanComment,
};
