import mongoose, { type ObjectId } from "mongoose";
import { boolean } from "zod";

export interface ILocation {
  id: string;
  name: string;
  note: string;
  lat: number;
  lng: number;
}

export interface IDay {
  date: string; // ISO date string e.g. "2025-04-01"
  locations: ILocation[];
}

export interface ITrip {
  _id: ObjectId;
  userId: ObjectId;
  country: string;
  startDate: string;
  endDate: string;
  days: IDay[];
  isTravelGuideCreated: boolean;
}

const locationSchema = new mongoose.Schema<ILocation>(
  {
    id: { type: String, required: true },
    name: { type: String, required: true },
    note: { type: String, default: "" },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
  },
  { _id: false },
);

const daySchema = new mongoose.Schema<IDay>(
  {
    date: { type: String, required: true },
    locations: { type: [locationSchema], default: [] },
  },
  { _id: false },
);

const tripSchema = new mongoose.Schema<ITrip>(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    country: { type: String, required: true },
    startDate: { type: String, required: true },
    endDate: { type: String, required: true },
    days: { type: [daySchema], default: [] },
    isTravelGuideCreated: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true },
);

const Trip = mongoose.model<ITrip>("Trip", tripSchema);

export default Trip;
