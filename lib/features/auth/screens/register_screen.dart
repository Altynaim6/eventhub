import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ui/screen_components.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void register() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmController.text;

    // Check empty fields
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showErrorSnackBar(context, 'Please fill in all fields');
      return;
    }

    // Check password length
    if (password.length < 6) {
      showErrorSnackBar(context, 'Password must be at least 6 characters');
      return;
    }

    // Check passwords match
    if (password != confirmPassword) {
      showErrorSnackBar(context, 'Passwords do not match');
      return;
    }

    // Send registration event to AuthBloc
    context.read<AuthBloc>().add(
      AuthRegisterRequested(name: name, email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), centerTitle: true),

      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Registration successful
          if (state is AuthAuthenticated) {
            debugPrint('Registration successful!');
            debugPrint('Navigating to HomeScreen...');

            // Close RegisterScreen and return to root route.
            // main.dart will display HomeScreen.
            Navigator.of(context).popUntil((route) => route.isFirst);
          }

          // Registration error
          if (state is AuthError) {
            debugPrint('Registration error: ${state.message}');

            showErrorSnackBar(context, state.message);
          }
        },

        child: ContentWidth(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Registration icon
                Icon(
                  Icons.person_add_alt_1,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Create Your Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const SizedBox(height: 24),

                // Full name
                TextField(
                  controller: nameController,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),

                const SizedBox(height: 16),

                // Email
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),

                const SizedBox(height: 16),

                // Confirm password
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),

                const SizedBox(height: 32),

                // Register button
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;

                    return FilledButton(
                      onPressed: isLoading ? null : register,
                      child: Text(
                        isLoading ? 'Creating account…' : 'Create Account',
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Back to login
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
