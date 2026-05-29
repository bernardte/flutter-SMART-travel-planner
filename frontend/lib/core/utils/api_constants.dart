// lib/core/utils/api_constants.dart
// ─────────────────────────────────────────────────────────────────────────────
// Change BASE_URL to point at your running backend.
//
//  • Android emulator  → http://10.0.2.2:PORT/api
//  • iOS simulator     → http://localhost:PORT/api
//  • Physical device   → http://<your-machine-LAN-IP>:PORT/api
//  • Production        → https://your-deployed-backend.com/api
// ─────────────────────────────────────────────────────────────────────────────

class ApiConstants {
  // ⬇️  Edit this line before running the app
  static const String baseUrl = 'http://192.168.100.219:8000/api';

  // Auth
  static const String login = '/users/login';
  static const String register = '/users/register-account';
  static const String logout = '/users/logout';
  static const String getLoginUser = '/users/get-login-user';
  static const String refreshToken = '/refreshToken';

  // Users
  static String getUserProfile(String username) =>
      '/users/get-user-profile/$username';
  static String getUserPublishTravelGuide(String userId) =>
      '/users/get-user-publish-travel-guide/$userId';
  static String getUserProfileStats(String username) =>
      '/users/profile/stats/$username';
  static String followUnfollowUser(String userId) =>
      '/users/follow-unfollow-user/$userId';
  static const String updateProfile = '/users/profile';

  // Trips
  static const String saveTrip = '/trips/save';
  static const String myTrips = '/trips/my-trips';
  static const String popularDestination = '/trips/popular-destination';
  static String tripById(String id) => '/trips/$id';

  // Trip Plans
  static const String createTripPlan = '/trips-plan/create';
  static String tripPlanByItinerary(String tripId) =>
      '/trips-plan/by-itinerary/$tripId';
  static String tripPlanById(String tripPlanId) => '/trips-plan/$tripPlanId';
  static String tripPlanComments(String tripPlanId) =>
      '/trips-plan/$tripPlanId/comments';
  static String tripPlanComment(String tripPlanId, String commentId) =>
      '/trips-plan/$tripPlanId/comments/$commentId';

  // Community
  static const String publicPosts = '/community/public-posts';
  static String itinerariesByAuthor(String authorId) =>
      '/community/itineraries/$authorId';
  static const String createPost = '/community/create/post';
  static String editPost(String postId) => '/community/edit/post/$postId';
  static String likeUnlikePost(String postId) =>
      '/community/liked-and-unliked/post/$postId';
  static String savePost(String postId) => '/community/saved/post/$postId';
  static String deletePost(String postId) =>
      '/community/delete-own-post/$postId';
  static const String recommendedGuides = '/community/recommend-travel-guide';
  static const String followersGuides =
      '/community/get-followers-travel-guide';

  // Favourites
  static const String favourites = '/favourites';
}
