import mongoose, { type ObjectId } from "mongoose";

export interface IUser {
  _id: ObjectId;
  name: string;
  username: string;
  bio: string;
  email: string;
  followers: ObjectId[],
  following: ObjectId[],
  password: string;
  profilePicture?: string;
  profilePictureCloudinaryPublicId?: string;
  resetToken?: string | null;
  resetTokenExpiration?: Date | null;
}


const userSchema = new mongoose.Schema<IUser>(
  {
    name: {
      type: String,
      required: true,
    },
    username: {
      type: String,
      required: true,
    },
    bio: {
      type: String,
    },
    email: {
      type: String,
      required: true,
    },
    followers: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
    },
    following: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
    },
    password: {
      type: String,
      required: true,
      select: false,
    },
    profilePicture: {
      type: String,
    },
    profilePictureCloudinaryPublicId: {
      type: String,
      select: false
    },
    resetToken: {
      type: String,
      default: null,
      select: false,
    },
    resetTokenExpiration: {
      type: Date,
      default: null,
      select: false,
    },
  },
  { timestamps: true },
);

const User = mongoose.model<IUser>("User", userSchema);

export default User;
