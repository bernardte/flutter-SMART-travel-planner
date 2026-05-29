import type { Request, Response } from "express";
import User from "../models/user.model.js";
import { successApiResponse } from "../utils/succes_api_response.js";
import { AppError } from "../utils/error_api_response.js";
import bcrypt from "bcryptjs";
import type {
  updateData,
  UserLoginDTO,
  UserRegisterDTO,
} from "../types/DTO/user.dto.js";
import generateTokensAndSetCookies from "../utils/auth/generate_tokens_and_set_cookies.js";
import { env } from "../config/env.js";
import mongoose from "mongoose";
import CommunityTravelGuide from "../models/community.model.js";
import { uploadToCloudinary } from "../utils/helpers/uploadToCloudinary.js";
import { deleteFromCloudinary } from "../utils/helpers/deleteFromCloudinary.js";
import TripPlan from "../models/tripPlan.model.js";

const registerAccount = async (
  req: Request<{}, {}, UserRegisterDTO>,
  res: Response,
): Promise<void> => {
  const { name, username, email, password } = req.body;

  if (
    !name?.trim() ||
    !username?.trim() ||
    !email?.trim() ||
    !password?.trim()
  ) {
    throw new AppError(400, "All fields are required.");
  }

  if (password.length < 8) {
    throw new AppError(409, "Password must be at least 8 characters long");
  }

  if (!/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email)) {
    throw new AppError(409, "Invalid email format");
  }

  // check email exists
  const existingUser = await User.findOne({
    $or: [{ email }, { username }],
  });

  if (existingUser) {
    throw new AppError(409, "Email or username already in use.");
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  // Create new user
  const newUser = await User.create({
    name,
    username,
    email,
    password: hashedPassword,
  });

  if (!newUser) {
    throw new AppError(500, "Failed to create user.");
  }

  const { accessToken: regAccessToken, refreshToken: regRefreshToken } = generateTokensAndSetCookies(newUser._id, res);
  successApiResponse(res, 201, "Account registered successfully", {
    _id: newUser._id,
    name: newUser.name,
    username: newUser.username,
    email: newUser.email,
    profilePicture: "",
    followers: [],
    following: [],
    token: regAccessToken,
    refreshToken: regRefreshToken,  // Flutter mobile reads this
  });
};

const loginAccount = async (
  req: Request<{}, {}, UserLoginDTO>,
  res: Response,
) => {
  const { email, password } = req.body;

  if (!email?.trim() || !password?.trim()) {
    throw new AppError(400, "Email and password are required.");
  }

  const user = await User.findOne({
    email,
  }).select("+password");

  if (!user) {
    throw new AppError(401, "Invalid email or password.");
  }

  const isPasswordValid = await bcrypt.compare(password, user.password);

  if (!isPasswordValid) {
    throw new AppError(401, "Invalid email or password.");
  }

  const { accessToken, refreshToken } = generateTokensAndSetCookies(user._id, res);
  successApiResponse(res, 200, "Login successful", {
    _id: user._id,
    username: user.username,
    name: user.name,
    profilePicture: user.profilePicture || "",
    followers: user.followers,
    following: user.following,
    email: user.email,
    token: accessToken,
    refreshToken,  // Flutter mobile reads this; web uses the cookie
  });
};

const logoutAccount = async (
  req: Request<{}, {}, UserLoginDTO>,
  res: Response,
) => {
  res.clearCookie("accessToken", {
    httpOnly: true,
    sameSite: env.NODE_ENV == "production" ? "none" : "lax",
    secure: env.NODE_ENV == "production",
    expires: new Date(Date.now()),
    maxAge: 1,
  });

  res.clearCookie("refreshToken", {
    httpOnly: true,
    sameSite: env.NODE_ENV == "production" ? "none" : "lax",
    secure: env.NODE_ENV == "production",
    expires: new Date(Date.now()),
    maxAge: 1,
  });

  successApiResponse(res, 201, "Logout successfully");
};

const getLoginUser = async (req: Request, res: Response) => {
  const userId = req.user?._id;

  const user = await User.findById({ _id: userId }).select("-password");

  if (!user) {
    throw new AppError(404, "User not found");
  }

  successApiResponse(res, 200, "User found", {
    user,
  });
};

const followAndUnfollowUser = async (
  req: Request<{ userId: string }>,
  res: Response,
) => {
  const currentUserId = req.user?._id;
  const targetUserId = req.params.userId;

  if (!currentUserId || !targetUserId) {
    throw new AppError(400, "User ID is required");
  }

  if (!mongoose.Types.ObjectId.isValid(targetUserId)) {
    throw new AppError(400, "Invalid userID");
  }

  if (currentUserId.toString() === targetUserId) {
    throw new AppError(400, "You cannot follow yourself");
  }

  const currentUser = await User.findById(currentUserId);
  const targetUser = await User.findById(targetUserId);

  if (!currentUser || !targetUser) {
    throw new AppError(404, "User not found");
  }

  const isFollowing = currentUser.following.some(
    (id) => id.toString() === targetUserId,
  );

  let newIsFollowing: boolean;

  if (isFollowing) {
    currentUser.following = currentUser.following.filter(
      (id) => id.toString() !== targetUserId,
    );

    targetUser.followers = targetUser.followers.filter(
      (id) => id.toString() !== currentUserId.toString(),
    );

    newIsFollowing = false;
  } else {
    currentUser.following.push(targetUser._id);
    targetUser.followers.push(currentUser._id);

    newIsFollowing = true;
  }

  await currentUser.save();
  await targetUser.save();

  return successApiResponse(res, 200, "Success", {
    isFollowing: newIsFollowing,
    followersCount: targetUser.followers.length,
  });
};

const getUserProfile = async (req: Request, res: Response) => {
  const { username } = req.params;

  if (!username) throw new AppError(400, "Invalid username");

  const user = await User.findOne({
    username,
  }).select("-password -__v -resetToken -resetTokenExpiration");

  if (!user) throw new AppError(404, "User not found");

  successApiResponse(res, 200, "", user);
};

const getUserPublishTravelGuide = async (req: Request, res: Response) => {
  const { userId } = req.params;

  if (!userId) throw new AppError(400, "Invalid userID");

  const travelGuide = await CommunityTravelGuide.find({
    authorId: userId,
    privacy: "public",
  }).sort({ createdAt: -1 });

  if (!travelGuide) throw new AppError(404, "Travel guide not found");

  successApiResponse(res, 200, "travel guide found", travelGuide);
};

const updateUserProfile = async (req: Request<{}, {}, updateData>, res: Response) => {
  const user = req.user;

  if (!user?._id) throw new AppError(400, "Invalid userID");

  const allowedField: (keyof updateData)[] = ["bio", "username"];

  const updates: Partial<updateData> = {};
  allowedField.forEach((field) => {
    if (req.body[field] !== undefined) {
      updates[field] = req.body[field];
    }
  });

  if (req.file && user.profilePictureCloudinaryPublicId) {
    await deleteFromCloudinary(user.profilePictureCloudinaryPublicId);
  }

  // if frontend upload user
  if (req.file) {
    const { url, public_id } = await uploadToCloudinary(
      req.file.buffer,
      "travel_guide",
    );
    updates["profilePicture"] = url;
    updates["profilePictureCloudinaryPublicId"] = public_id;
  }

  const updateUser = await User.findByIdAndUpdate(
    user?._id,
    { $set: updates },
    { new: true, runValidators: true },
  );


  await TripPlan.updateMany(
    // @ts-ignore
    { userId: user._id },
    {
      $set: {
        authorName: updates.username,
        authorAvatar: updates.profilePicture,
      },
    },
  );
  // TripPlan reviews update
  await TripPlan.updateMany(
   // @ts-ignore
   { "reviews.user": user._id },
   {
     $set: {
       "reviews.$[review].username": updates.username,
     },
   },
   {
     arrayFilters: [{ "review.user": user._id }],
   },
 );
  successApiResponse(res, 200, "updated successfully", updateUser);
};

const getUserProfileStats = async (req: Request, res: Response) => {
  const username = req.params?.username;

  if (!username) throw new AppError(400, "Invalid username");

  const stats = await CommunityTravelGuide.aggregate([
    //! join User collection
    {
      $lookup: {
        from: "users", //* collection name(usually lowercase + plural)
        localField: "authorId",
        foreignField: "_id",
        as: "author",
      },
    },
    //! flatten array
    {
      $unwind: "$author",
    },
    {
      $match: {
        "author.username": username,
        privacy: "public",
      },
    },
    {
      $group: {
        _id: null,
        totalGuide: { $sum: 1 },
        totalViews: { $sum: "$views" },
        totalLikes: { $sum: { $size: "$likes" } }, // handle array
      },
    },
  ]);

  const result = {
    totalGuides: stats[0]?.totalGuide || 0,
    totalViews: stats[0]?.totalViews || 0,
    totalLikes: stats[0]?.totalLikes || 0,
  };

  successApiResponse(res, 200, "User stats fetched", result);
};

export default {
  updateUserProfile,
  registerAccount,
  loginAccount,
  logoutAccount,
  followAndUnfollowUser,
  getLoginUser,
  getUserProfile,
  getUserPublishTravelGuide,
  getUserProfileStats,
};
