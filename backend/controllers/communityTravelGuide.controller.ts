import CommunityTravelGuide from "../models/community.model.js";
import TripPlan from "../models/tripPlan.model.js";
import { successApiResponse } from "../utils/succes_api_response.js";
import { AppError } from "../utils/error_api_response.js";
import type { Request, Response } from "express";
import { uploadToCloudinary } from "../utils/helpers/uploadToCloudinary.js";
import { deleteFromCloudinary } from "../utils/helpers/deleteFromCloudinary.js";
import type { Types } from "mongoose";
import mongoose from "mongoose";
import User from "../models/user.model.js";

const createPost = async (req: Request, res: Response) => {
  const { title, description, country, tags, privacy, authorId, itineraryId } =
    req.body;

  console.log("body: ", req.body);

  if (!title || !description || !country || !authorId || !itineraryId) {
    throw new AppError(400, "All field are required!");
  }

  const parsedTags = Array.isArray(tags) ? tags : JSON.parse(tags);

  if (!req.file) {
    throw new AppError(400, "Thumbnail image is required!");
  }

  const { url, public_id } = await uploadToCloudinary(
    req.file.buffer,
    "travel_guide",
  );

  //! Create new post
  const newPost = await CommunityTravelGuide.create({
    title,
    description,
    country,
    thumbnailImage: url,
    thumbnailImagePublicId: public_id,
    tags: parsedTags,
    privacy,
    authorId,
    itineraryId,
    saves: 0,
    views: 0,
  });

  const populated = await CommunityTravelGuide.findById(newPost._id)
    .populate("authorId", "username name email profilePicture")
    .populate("itineraryId");

  const obj = populated!.toObject();

  const normalized = {
    ...obj,
    author: obj.authorId,
    authorId: undefined,
    likes: obj.likes?.length || 0,
    saves: obj.postSavedByUser?.length || 0,
    stats: {
      views: obj.views || 0,
    },
    itinerary: obj.itineraryId
      ? {
          _id: obj.itineraryId._id,
          title: obj.title,
          country: obj.country,
        }
      : null,
  };

  successApiResponse(res, 201, "Post created successfully", normalized);
};

const editPost = async (req: Request, res: Response) => {
  const { postId } = req.params;
  const { title, description, country, tags, privacy, authorId, itineraryId } =
    req.body;

  if (!postId) throw new AppError(400, "Post ID are required");

  // Check if post exists
  const existingPost = await CommunityTravelGuide.findById(postId).select(
    "+thumbnailImagePublicId",
  );

  if (!existingPost) throw new AppError(404, "Post not found");

  // Update only provided fields (PATCH behavior)
  if (title !== undefined) existingPost.title = title;
  if (description !== undefined) existingPost.description = description;
  if (authorId !== undefined) existingPost.authorId = authorId;
  if (country !== undefined) existingPost.country = country;
  if (privacy !== undefined) existingPost.privacy = privacy;
  if (itineraryId !== undefined) existingPost.itineraryId = itineraryId;

  if (tags !== undefined) {
    console.log(Array.isArray(tags));
    let parsedTags = [];
    if (typeof tags === "string") {
      try {
        parsedTags = JSON.parse(tags);
      } catch {
        parsedTags = [];
      }
    }
    existingPost.tags = parsedTags;
  }

  // image update
  if (req.file?.buffer) {
    const existingPublicId = existingPost.thumbnailImagePublicId;
    if (existingPublicId) {
      await deleteFromCloudinary(existingPublicId);
    }

    const { url, public_id } = await uploadToCloudinary(req.file.buffer);
    existingPost.thumbnailImage = url;
    existingPost.thumbnailImagePublicId = public_id;
  }

  // 1. Save the post
  await existingPost.save();

  // 2. Fetch it again and populate the required fields
  const populatedPost = await CommunityTravelGuide.findById(existingPost._id)
    .populate("authorId", "username name email profilePicture")
    .populate("itineraryId");

  const obj = populatedPost!.toObject();

  // 3. Normalize the data to match your frontend interface
  const normalized = {
    ...obj,
    author: obj.authorId,
    authorId: undefined,
    likes: obj.likes?.length || 0,
    saves: obj.postSavedByUser?.length || 0,
    stats: {
      views: obj.views || 0,
    },
    itinerary: obj.itineraryId
      ? {
          _id: (obj.itineraryId as Types.ObjectId)._id,
          title: (obj.itineraryId as any).title,
          country: (obj.itineraryId as any).country,
        }
      : null,
  };

  // 4. Send the normalized data back
  successApiResponse(res, 200, "updated successfully", normalized);
};

const fetchUserItinerary = async (
  req: Request<{ authorId: string }>,
  res: Response,
) => {
  const { authorId } = req.params;

  if (!authorId) throw new AppError(400, "User ID are required");

  const itineraries = await TripPlan.find({
    userId: authorId,
  })
    .select("_id country title")
    .sort({ createdAt: -1 });

  successApiResponse(res, 200, "Itineraries found", itineraries);
};

const getAllPublicPost = async (req: Request, res: Response) => {
  const userId = req.user?._id;
  const allPublicPost = await CommunityTravelGuide.find({
    privacy: "public",
  }).populate("authorId", "username name email profilePicture following");

  //! normalize data
  const normalized = allPublicPost.map((post) => {
    const obj = post.toObject();
   const isLiked =
     !!userId && obj.likes?.some((id) => String(id) === String(userId));

   const isSaved =
     !!userId &&
     obj.postSavedByUser?.some((id) => String(id) === String(userId));

    return {
      ...obj,

      //  rename
      author: obj.authorId,
      authorId: undefined,

      //  numbers
      likes: obj.likes?.length || 0,
      isLiked,
      saves: obj.postSavedByUser?.length || 0,
      isSaved,

      // stats
      stats: {
        views: obj.views || 0,
      },
      createdAt: obj.createdAt,

      //  itinerary
      itinerary: obj.itineraryId
        ? {
            _id: obj.itineraryId,
            title: obj.title,
            country: obj.country,
          }
        : null,
    };
  });

  console.log("normalized: ", normalized);

  successApiResponse(res, 200, "", normalized);
};

const deleteOwnPost = async (req: Request, res: Response) => {
  try {
    const { postId } = req.params;
    const userId = req.user?._id;

    const post = await CommunityTravelGuide.findById(postId).select(
      "+thumbnailImagePublicId",
    );

    if (!post) {
      throw new AppError(404, "Post not found");
    }

    if (!userId) {
      throw new AppError(401, "Unauthorized");
    }

    if (post.authorId.toString() !== userId.toString()) {
      throw new AppError(403, "You are not allowed to delete this post");
    }

    // 1. delete image if exists
    if (post.thumbnailImagePublicId) {
      try {
        await deleteFromCloudinary(post.thumbnailImagePublicId);
      } catch (err) {
        console.error("Cloudinary delete failed:", err);
        //! Do not prevent the deletion of posts
      }
    }

    // 2. ALWAYS delete post
    await CommunityTravelGuide.findByIdAndDelete(postId);

    return successApiResponse(res, 200, "Post deleted successfully");
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

const likeAndUnlikePost = async (req: Request, res: Response) => {
  const { postId } = req.params;
  const userId = req.user?._id;

  if (!postId) throw new AppError(400, "Invalid postId");
  if (!userId) throw new AppError(401, "Unauthorized");

  const post = await CommunityTravelGuide.findById(postId);
  if (!post) throw new AppError(404, "Post not found");

  const alreadyLiked = post.likes.some(
    (id) => id.toString() === userId.toString(),
  );

  if (alreadyLiked) {
    post.likes = post.likes.filter((id) => id.toString() !== userId.toString());
  } else {
    post.likes.push(userId);
  }

  await post.save();

  successApiResponse(
    res,
    200,
    `Success ${alreadyLiked ? "liked post" : "unliked post"}`,
    {
      likes: post.likes.length,
      isLiked: !alreadyLiked,
    },
  );
};

const savedPost = async (req: Request, res: Response) => {
  const { postId } = req.params;
  const userId = req.user?._id;

  if (!postId) {
    throw new AppError(401, "Invalid post");
  }

  const post = await CommunityTravelGuide.findById(postId);
  if (!post) {
    throw new AppError(401, "Post not found");
  }

  const isSaved = post.postSavedByUser.includes(userId);
  if (isSaved) {
    post.postSavedByUser = post.postSavedByUser.filter(
      (id) => id.toString() !== userId?.toString(),
    );

    post.saves = Math.max(0, post.saves - 1);
  } else {
    post.postSavedByUser.push(userId);

    post.saves += 1;
  }

  await post.save();
  successApiResponse(
    res,
    200,
    `Success ${isSaved ? "unsaved post" : "saved post"}`,
    {
      saves: post.postSavedByUser.length,
      isSaved: !isSaved,
    },
  );
};

const getPersonalizedRecommendation = async (req: Request, res: Response) => {
  const userId = req.user?._id;

  if (!userId) throw new AppError(401, "Unauthorized");

  const guides = await CommunityTravelGuide.find({
    privacy: "public",
  }).populate("authorId", "_id username");

  const userLikedPosts = await CommunityTravelGuide.find({
    likes: userId.toString(),
  });

  const userTags = userLikedPosts.flatMap((p) => p.tags);
  const userCountries = userLikedPosts.flatMap((p) => p.country);

  if (userCountries.length === 0) {
    //! popularity
    const coldStart = await CommunityTravelGuide.find({
      privacy: "public",
    })
      .populate("authorId", "_id username")
      .sort({
        views: -1,
        saves: -1,
        likes: -1,
        createdAt: -1,
      });

    const filtered = coldStart
      .map((post) => {
        if (!post.authorId) return null;
        if (post.authorId._id.toString() === userId.toString()) return null;

        const obj = post.toObject();
        const isLiked = obj.likes?.some(
          (id: Types.ObjectId | string) => id.toString() === userId.toString(),
        );
        const isSaved = obj.postSavedByUser?.some(
          (id: Types.ObjectId | string) => id.toString() === userId.toString(),
        );

        return {
          ...obj,
          author: obj.authorId,
          authorId: undefined,
          likes: obj.likes?.length || 0,
          isLiked: isLiked ?? false,
          saves: obj.postSavedByUser?.length || 0,
          isSaved: isSaved ?? false,
          itinerary: obj.itineraryId
            ? { _id: obj.itineraryId, title: obj.title, country: obj.country }
            : null,
        };
      })
      .filter(Boolean)
      .slice(0, 3);

    return successApiResponse(res, 200, "Cold start recommendation", filtered);
  }

  const scores = guides.map((guide) => {
    if (!guide.authorId) return null;
    //! exclude my own publish post
    if (guide.authorId._id.toString() === userId.toString()) {
      return null;
    }
    //! exclude own like post
    if (guide.likes.some((id) => id.toString() === userId.toString())) {
      return null;
    }

    //! exclude my save post
    if (
      guide.postSavedByUser.some((id) => id.toString() === userId.toString())
    ) {
      return null;
    }

    const tagMatch = guide.tags.filter((tag) => userTags.includes(tag)).length;
    const countryMatch = userCountries.includes(guide.country) ? 1 : 0;
    const likesCount = guide.likes.length;
    const saveCount = guide.postSavedByUser.length;

    // log scaling, avoid hot post always being recommended
    const baseScore =
      Math.log(1 + likesCount) * 3 +
      Math.log(1 + (saveCount ?? guide.saves)) * 5 +
      Math.log(1 + guide.views);

    //! old post exclude
    const daysOld =
      (Date.now() - new Date(guide.createdAt).getTime()) /
      (1000 * 60 * 60 * 24);

    const timeDecay = 1 / (1 + daysOld);

    const score = (baseScore + tagMatch * 10 + countryMatch * 8) * timeDecay;

    const obj = guide.toObject();

    const isLiked = obj.likes?.some(
      (id: Types.ObjectId | string) => id.toString() === userId.toString(),
    );

    const isSaved = obj.postSavedByUser?.some(
      (id: Types.ObjectId | string) => id.toString() === userId.toString(),
    );

    return {
      ...obj,

      // ⭐ author rename
      author: obj.authorId,
      authorId: undefined,

      // ⭐ numbers
      likes: obj.likes?.length || 0,
      isLiked,
      saves: obj.postSavedByUser?.length || 0,
      isSaved,

      // ⭐ stats
      stats: {
        views: obj.views || 0,
      },

      // ⭐ itinerary
      itinerary: obj.itineraryId
        ? {
            _id: obj.itineraryId,
            title: obj.title,
            country: obj.country,
          }
        : null,

      // ⭐ recommendation score
      score,
    };
  });

  const sorted = scores
    .filter(Boolean)
    .sort((a: any, b: any) => b.score - a.score)
    .slice(0, 3);

  successApiResponse(res, 200, "Recommendation for you", sorted);
};

const getFollowersTravelGuide = async (req: Request, res: Response) => {
  const userId = req.user?._id;

  // @ts-ignore
  if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
    throw new AppError(401, "Unauthorized");
  }

  const user = await User.findById(userId).select("following");

  if (!user) {
    throw new AppError(404, "User not found");
  }

  const followingIds = user.following || [];

  const guides = await CommunityTravelGuide.find({
    //@ts-ignore
    $and: [
      {
        $or: [{ authorId: { $in: followingIds } }, { authorId: userId }],
      },
      {
        privacy: "private",
      },
    ],
  })
    .populate("authorId", "username profilePicture")
    .sort({ createdAt: -1 });

  // ✅ normalize
  const normalizedGuides = guides.map((obj: any) => {
    const isLiked =
      req.user &&
      obj.likes?.some((id: any) => id.toString() === req.user?._id.toString());

    const isSaved =
      req.user &&
      obj.postSavedByUser?.some(
        (id: any) => id.toString() === req.user?._id.toString(),
      );

    return {
      ...obj.toObject(), // 👈 important (Mongoose doc → plain object)

      // rename
      author: obj.authorId,
      authorId: undefined,

      // numbers
      likes: obj.likes?.length || 0,
      isLiked,
      saves: obj.postSavedByUser?.length || 0,
      isSaved,

      // stats
      stats: {
        views: obj.views || 0,
      },

      createdAt: obj.createdAt,

      // itinerary formatting
      itinerary: obj.itineraryId
        ? {
            _id: obj.itineraryId,
            title: obj.title,
            country: obj.country,
          }
        : null,
    };
  });

  return successApiResponse(
    res,
    200,
    "Followers travel guides fetched successfully",
    normalizedGuides,
  );
};

export default {
  createPost,
  editPost,
  fetchUserItinerary,
  getAllPublicPost,
  deleteOwnPost,
  likeAndUnlikePost,
  savedPost,
  getPersonalizedRecommendation,
  getFollowersTravelGuide,
};
