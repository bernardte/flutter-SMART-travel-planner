import mongoose, { Types } from "mongoose";

interface CommunityTravelGuide {
  title: string;
  authorId: Types.ObjectId;
  country: string;
  description: string;
  thumbnailImage: string;
  thumbnailImagePublicId: string;
  tags: string[];
  likes: Types.ObjectId[];
  saves: number;
  postSavedByUser: Types.ObjectId[];
  privacy: "public" | "private";
  views: number;
  viewsBy: Types.ObjectId[];
  itineraryId: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const CommunityTravelGuideSchema = new mongoose.Schema<CommunityTravelGuide>(
  {
    title: {
      type: String,
      required: true,
    },
    authorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    country: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    thumbnailImage: {
      type: String,
      required: true,
    },
    thumbnailImagePublicId: {
      type: String,
      required: true,
      select: false,
    },
    tags: {
      type: [String],
      required: true,
    },
    likes: {
      // array of user ids
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User",
      default: [],
    },
    saves: {
      type: Number,
      default: 0,
    },
    postSavedByUser: {
      // array of user ids
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User",
      default: [],
    },
    privacy: {
      type: String,
      enum: ["public", "private"],
      default: "public",
    },
    views: {
      type: Number,
      default: 0,
    },
    viewsBy: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    itineraryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "TripPlan",
      required: true,
    },
  },
  { timestamps: true },
);

CommunityTravelGuideSchema.index({ authorId: 1 });
CommunityTravelGuideSchema.index({ privacy: 1 });
CommunityTravelGuideSchema.index({ country: 1 });

const CommunityTravelGuide = mongoose.model<CommunityTravelGuide>(
  "CommunityTravelGuide",
  CommunityTravelGuideSchema,
);

export default CommunityTravelGuide;
