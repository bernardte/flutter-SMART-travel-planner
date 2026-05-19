export interface CreatTripPlanDTO {
  title: string;
  authorIntro: string;
  tripId: string;
  sections: string; //* due to frontend sending as JSON.stringify() will convert to a string when passing.
}
