import mongoose, { type ObjectId } from "mongoose";
import { string } from "zod";

enum ListItemType {
  text = "text",
  checklist = "checklist",
}

export interface IListItem {
  order: number;
  text: string;
  type: ListItemType;
  checked?: boolean;
}

export const listItemSchema = new mongoose.Schema<IListItem>({
  order: {
    type: Number,
    required: true,
  },
  text: {
    type: String,
    default: "",
  },
  type: {
    type: String,
    enum: Object.values(ListItemType),
    required: true,
  },
  checked: {
    type: Boolean,
    default: false,
  },
});

enum CategoryItem {
  restaurant = "restaurant",
  attraction = "attraction",
  cafe = "cafe",
  viewPoint = "viewpoint",
  other = "other",
}

export interface IPlace {
  order: number;
  name: string;
  description?: string;
  lat: number;
  lng: number;
  category: CategoryItem;
  address?: string;
  timeEstimate?: string;
  locationImageUrl?: string;
}

export const placeSchema = new mongoose.Schema<IPlace>(
  {
    order: {
      type: Number,
    },
    name: String,
    description: String,
    lat: Number,
    lng: Number,
    locationImageUrl: string,
    category: {
      type: String,
      enum: ["restaurant", "attraction", "cafe", "viewpoint", "other"],
    },
    address: String,
  },
  { _id: false }, 
);

export interface IRouteStop {
  id: string;
  name: string;
  lat: number;
  lng: number;
  order: number;
}

export const routeStopSchema = new mongoose.Schema<IRouteStop>(
  {
    id: String,
    name: String,
    lat: Number,
    lng: Number,
    order: Number,
  },
  { _id: false },
);

export interface ITipsSection {
  id: string;
  type: "tips";
  title: string;
  content: string;
  isOpen: boolean;
}

// tips section
export const tipsSelectionSchema = new mongoose.Schema<ITipsSection>(
  {
    id: String,
    type: { type: String, enum: ["tips"], required: true },
    title: String,
    content: String,
    isOpen: Boolean,
  },
  { _id: false },
);

export interface IDaySection {
  id: string;
  type: "day";
  title: string;
  route: IRouteStop[];
  places: IPlace[];
  listItems: IListItem[];
  notes: string;
  isOpen: boolean;
}

export const daySectionSchema = new mongoose.Schema<IDaySection>(
  {
    id: String,
    type: { type: String, enum: ["day"], required: true },
    title: String,

    route: { type: [routeStopSchema], default: [] },
    places: { type: [placeSchema], default: [] },
    listItems: { type: [listItemSchema], default: [] },

    notes: String,
    isOpen: Boolean,
  },
  { _id: false },
);

export interface ISections {
  id: string,
  type: "tips" | "day",
  title: string,
  content: string,
  route: IRouteStop[],
  places: IPlace[],
  listItems:IListItem[],
  notes: string,
  isOpen: boolean;
}

export const sectionSchema = new mongoose.Schema<ISections>(
  {
    id: String,
    type: {
      type: String,
      enum: ["tips", "day"],
      required: true,
    },
    title: String,

    // Tips
    content: String,

    // Day
    route: { type: [routeStopSchema], default: [] },
    places: { type: [placeSchema], default: [] },
    listItems: { type: [listItemSchema], default: [] },
    notes: String,

    isOpen: Boolean,
  },
  { _id: false },
);
