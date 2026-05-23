import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/home/bloc/Home_state.dart';

class HomeCubit extends Cubit<HomeState> {
    HomeCubit() : super(HomeInitial());

    Future<void> LoadHomeData() async {
      emit(HomeLoading());
      try{

      }catch(error){
        emit(HomeError(error.toString()));
      }
    }
}