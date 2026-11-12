import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ui/event_hub_theme.dart';
import 'ui/screen_components.dart';

import 'firebase_options.dart';

import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/home_screen.dart';

import 'features/profile/repositories/profile_repository.dart';
import 'features/events/bloc/event_bloc.dart';
import 'features/events/repositories/event_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const EventHubApp());
}

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProfileStore>(
      create: (_) => ProfileRepository(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => AuthBloc(AuthRepository())),
          BlocProvider<EventBloc>(create: (_) => EventBloc(EventRepository())),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'EventHub',
          theme: eventHubTheme(),
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              debugPrint('AUTH STATE: ${state.runtimeType}');

              if (state is AuthAuthenticated) {
                return const HomeScreen();
              }

              if (state is AuthInitial) {
                return const Scaffold(
                  body: Center(
                    child: StatusPanel.loading(title: 'Loading your account'),
                  ),
                );
              }

              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}
