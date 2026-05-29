part of 'auth_screen.dart';

class _SignupForm extends ConsumerStatefulWidget {
  const _SignupForm();

  @override
  ConsumerState<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<_SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).register(
            name: _nameCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _kDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Join millions of smart travellers',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: _kDark, fontWeight: FontWeight.w500),
              decoration: _authFieldDecoration(
                label: 'Full Name',
                icon: Icons.person_rounded,
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _usernameCtrl,
              style: const TextStyle(color: _kDark, fontWeight: FontWeight.w500),
              decoration: _authFieldDecoration(
                label: 'Username',
                icon: Icons.alternate_email_rounded,
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter a username' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: _kDark, fontWeight: FontWeight.w500),
              decoration: _authFieldDecoration(
                label: 'Email Address',
                icon: Icons.email_rounded,
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: _kDark, fontWeight: FontWeight.w500),
              decoration: _authFieldDecoration(
                label: 'Password',
                icon: Icons.lock_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 24),

            _gradientButton(
              onPressed: _loading ? null : _submit,
              loading: _loading,
              label: 'Create Account',
              icon: Icons.rocket_launch_rounded,
            ),
            const SizedBox(height: 14),

            const Center(
              child: Text.rich(
                TextSpan(
                  text: 'By signing up, you agree to our ',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
