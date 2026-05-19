import type { IDay } from "../../models/trip.model.js";

export interface SaveTripBodyDTO {
  country: string;
  startDate: string;
  endDate: string;
  days: IDay[];
}

export interface createCommentDTO {
  content: string;
}