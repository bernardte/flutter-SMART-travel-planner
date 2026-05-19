import mongoose, { Types } from "mongoose";
import { sectionSchema } from "./section.model.js";

export interface IReview {
  _id?: mongoose.Types.ObjectId;
  user: mongoose.Types.ObjectId;
  username: string;
  content: string;
  createdAt?: Date;
}

export interface ITripPlan extends mongoose.Document {
  _id: Types.ObjectId;

  // 🔗 Link to Trip
  tripId: Types.ObjectId;
  userId: Types.ObjectId;

  // 📌 Guide Info
  title: string;
  authorName: string;
  authorAvatar?: string;
  authorIntro: string;

  // 🌍 Content
  sections: any[]; // mixed (tips + day)

  // 🌏 Meta
  country?: string;

  // ❤️ Social
  thumbnailImage: String;

  // 🔐 Visibility
  reviews: IReview[];
  createdAt: Date;
  updatedAt: Date;
}

const tripPlanSchema = new mongoose.Schema<ITripPlan>(
  {
    tripId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip",
      required: true,
    },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    title: { type: String, required: true },

    authorName: String,
    authorAvatar: String,
    authorIntro: String,

    sections: [sectionSchema],

    country: String,
    thumbnailImage: String,

    reviews: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        username: { type: String },
        content: { type: String },
        createdAt: { type: Date, default: Date.now },
        updatedAt: { type: Date, default: Date.now }
      },
    ],
  },
  { timestamps: true },
);

tripPlanSchema.index({ userId: 1 });
tripPlanSchema.index({ publishStatus: 1 });
tripPlanSchema.index({ country: 1 });

const TripPlan = mongoose.model<ITripPlan>("TripPlan", tripPlanSchema);

export default TripPlan;
