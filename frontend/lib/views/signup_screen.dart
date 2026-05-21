import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/config/service_locator.dart';
import 'package:frontend/core/helpers/ui/app_feedback.dart';
import 'package:frontend/viewmodels/auth/signup/signup_bloc.dart';
import 'package:frontend/viewmodels/auth/signup/signup_event.dart';
import 'package:frontend/viewmodels/auth/signup/signup_state.dart';
import 'package:frontend/views/login_screen.dart';
import 'package:frontend/data/repository/auth/signup_repository.dart';
import 'package:frontend/widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _handleSignup(BuildContext context) async {
    context.read<SignupBloc>().add(
      SignupSubmittedEvent(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SignupBloc(getIt<SignupRepository>()),
      child: BlocConsumer<SignupBloc, SignupState>(
        listener: _listener,
        builder: (context, state) {
          final isLoading = state is SignupLoading;
          return _buildSignupForm(context, isLoading);
        },
      ),
    );
  }

  void _listener(BuildContext context, SignupState state) {
    if (state is SignupSuccess) {
      AppFeedback.success(context, state.message);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (state is SignupFailure) {
      AppFeedback.error(context, state.errorMessage);
    }
  }

  Widget _buildSignupForm(BuildContext context, bool isLoading) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add,
                    size: 80,
                    color: Color(0xFF0288D1),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF01579B),
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomTextFieldWidget(
                    controller: _nameController,
                    label: "Name",
                    icon: Icons.person_outline,
                    obscureText: false,
                  ),
                  const SizedBox(height: 16),
                  CustomTextFieldWidget(
                    controller: _usernameController,
                    label: "Username",
                    icon: Icons.account_circle_outlined,
                    obscureText: false,
                  ),
                  const SizedBox(height: 16),
                  CustomTextFieldWidget(
                    controller: _emailController,
                    label: "Email",
                    icon: Icons.email_outlined,
                    obscureText: false,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  CustomTextFieldWidget(
                    controller: _passwordController,
                    label: "Password",
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : () => _handleSignup(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0288D1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ?  const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),

                              SizedBox(width: 12),

                              Text(
                                "Signing Up...",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text('Sign Up', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: Color(0xFF0288D1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
