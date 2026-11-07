import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  late final StreamSubscription<User?> _authSubscription;

  AuthBloc(this.repository) : super(AuthInitial()) {

    // Listen to Firebase authentication changes
    on<AuthUserChanged>((event, emit) {
      if (event.userId != null) {
        debugPrint('AUTH: User authenticated');

        emit(AuthAuthenticated(event.userId!));
      } else {
        debugPrint('AUTH: User unauthenticated');

        emit(AuthUnauthenticated());
      }
    });

    // LOGIN
    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());

      try {
        await repository.login(
          email: event.email,
          password: event.password,
        );

        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          debugPrint('LOGIN SUCCESS: ${user.uid}');

          emit(AuthAuthenticated(user.uid));
        } else {
          emit(const AuthError('Login failed'));
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('LOGIN ERROR: ${e.code} - ${e.message}');

        emit(AuthError(e.message ?? 'Login failed'));
      } catch (e) {
        debugPrint('LOGIN ERROR: $e');

        emit(AuthError(e.toString()));
      }
    });

    // REGISTER
    on<AuthRegisterRequested>((event, emit) async {
      emit(AuthLoading());

      try {
        debugPrint('Starting registration...');

        await repository.register(
          name: event.name,
          email: event.email,
          password: event.password,
        );

        debugPrint('Repository registration completed');

        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          debugPrint('REGISTRATION SUCCESS: ${user.uid}');

          emit(AuthAuthenticated(user.uid));
        } else {
          emit(const AuthError('Registration failed'));
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('REGISTRATION ERROR: ${e.code} - ${e.message}');

        emit(AuthError(e.message ?? 'Registration failed'));
      } catch (e) {
        debugPrint('REGISTRATION ERROR: $e');

        emit(AuthError(e.toString()));
      }
    });

    // LOGOUT
    on<AuthLogoutRequested>((event, emit) async {
      try {
        await repository.logout();

        debugPrint('LOGOUT SUCCESS');

        emit(AuthUnauthenticated());
      } catch (e) {
        debugPrint('LOGOUT ERROR: $e');

        emit(AuthError(e.toString()));
      }
    });

    // Firebase authentication listener
    _authSubscription = repository.authStateChanges.listen((user) {
      add(AuthUserChanged(user?.uid));
    });
  }

  @override
  Future<void> close() async {
    await _authSubscription.cancel();
    await super.close();
  }
}