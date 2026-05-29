// lib/screens/auth/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/snackbar.dart';
part 'login_form.dart';
part 'signup_form.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                ),

                const SizedBox(height: 32),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('TravelBuddy',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 8),
                Text('Plan smarter, travel better', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                    ),
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: const Color(0xFF1F2937),
                    unselectedLabelColor: Colors.grey,
                    tabs: const [Tab(text: 'Login'), Tab(text: 'Sign Up')],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    controller: _tabController,
                    children: const [_LoginForm(), _SignupForm()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
