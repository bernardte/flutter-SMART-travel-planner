import type { Request, Response } from "express";
import CommunityTravelGuide from "../models/community.model.js";
import { successApiResponse } from "../utils/succes_api_response.js";
import { AppError } from "../utils/error_api_response.js";
import type mongoose from "mongoose";

type PopulatedAuthor = {
  _id: mongoose.Types.ObjectId;
  name: string;
  username: string;
  profilePicture: string;
};

const getAllFavourite = async (req: Request, res: Response) => {
  const userId = req.user?._id;

  if (!userId) {
    throw new AppError(401, "Unauthorized");
  }

  const favourites = await CommunityTravelGuide.find({
    //@ts-ignore
    postSavedByUser: userId,
  })
    .populate<{ authorId: PopulatedAuthor }>(
      "authorId",
      "_id name username profilePicture",
    )
    .sort({ createdAt: -1 });

  const data = favourites.map((post) => {
    const isLiked = userId
      ? post.likes?.some((id: any) => id.toString() === userId.toString())
      : false;
    const isSaved = userId
      ? post.postSavedByUser?.some(
          (id: any) => id.toString() === userId.toString(),
        )
      : false;

    return {
      _id: post._id,
      title: post.title,
      description: post.description,
      country: post.country,
      thumbnailImage: post.thumbnailImage,
      itineraryId: post.itineraryId,

      likes: post.likes?.length || 0,
      saves: post.postSavedByUser?.length || 0,
      views: post.views || 0,

      isLiked: isLiked,
      privacy: post.privacy,

      isSaved: isSaved,

      tags: post.tags || [],

      author: post.authorId
        ? {
            _id: post.authorId._id,
            name: post.authorId.name,
            username: post.authorId.username,
            profilePicture: post.authorId.profilePicture,
          }
        : null,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
    };
  });

  return successApiResponse(res, 200, "", data);
};

export default {
  getAllFavourite,
};
