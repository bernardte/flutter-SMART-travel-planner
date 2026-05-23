abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final String userName;
  final List<String> trips;
  final String? userProfilePictureUrl;

  HomeLoaded({required this.userName, required this.trips, this.userProfilePictureUrl });
}

class HomeError extends HomeState {
  final String message;

  HomeError(this.message);
}
