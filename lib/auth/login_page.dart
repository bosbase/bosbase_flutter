import 'package:flutter/material.dart';
import '../bosbase_service.dart';
import '../config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _checkingAuto = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeSchemaInBackground();
    _autoLoginIfPossible();
  }

  Future<void> _initializeSchemaInBackground() async {
    try {
      await bosService.initializeSchemaWithSuperuser(
        AppConfig.adminEmail,
        AppConfig.adminPassword,
      );
    } catch (e) {
      // Debug log only; doesn't affect login/register functionality
      debugPrint('Initialization failed (not affecting login/register): $e');
    }
  }

  Future<void> _autoLoginIfPossible() async {
    setState(() => _checkingAuto = true);
    // If already authenticated, navigate directly to home
    if (bosService.isAuthenticated) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    // Try auto sign-in with locally stored credentials
    final ok = await bosService.tryAutoLogin();
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Auto sign-in failed; show the login form for manual input
      setState(() => _checkingAuto = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await bosService.authUser(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Log detailed error to console only; show friendly English message
      debugPrint('Sign in failed: $e');
      setState(() => _error = 'Sign in failed. Please check your email or password and try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
          children: [
            if (_checkingAuto)
              const Padding(
                padding: EdgeInsets.only(top: 32.0, bottom: 16.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Attempting auto sign-in…')
                  ],
                ),
              ),
            if (!_checkingAuto) ...[
            TextField(
              controller: _emailController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: true,
              readOnly: false,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _login(),
              enabled: true,
              readOnly: false,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
              child: const Text('No account? Register'),
            ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}