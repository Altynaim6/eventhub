import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/bloc/auth_state.dart';
import 'package:eventhub/features/auth/screens/home_screen.dart';
import 'package:eventhub/features/events/bloc/event_bloc.dart';
import 'package:eventhub/features/profile/models/user_profile.dart';
import 'package:eventhub/features/profile/repositories/profile_repository.dart';

import 'event_management_widget_test.dart' show SessionBloc;
import 'event_bloc_test.dart' show sample;
import 'support/discovery_events.dart';
import 'support/my_store.dart';
import 'support/profile_store_stub.dart';

class ProfileSession extends SessionBloc {
  ProfileSession() : super('organizer');
  void signOut() => emit(AuthUnauthenticated());
}

void main() {
  late ProfileStoreStub profiles;
  late MyStore events;
  late ProfileSession auth;
  Future<void> open(
    WidgetTester tester, {
    UserProfile profile = sampleProfile,
  }) async {
    profiles = ProfileStoreStub();
    events = MyStore();
    auth = ProfileSession();
    profiles.onLogout = () {
      if (!auth.isClosed) auth.signOut();
    };
    await tester.pumpWidget(
      RepositoryProvider<ProfileStore>.value(
        value: profiles,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider(create: (_) => EventBloc(events)),
          ],
          child: MaterialApp(
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => state is AuthAuthenticated
                  ? const HomeScreen()
                  : const Scaffold(body: Text('Logged out')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    profiles.updates.add(profile);
    events.created.add([discoveryEvent('hosted', count: 3)]);
    events.registered.add([sample]);
    await tester.pumpAndSettle();
    addTearDown(() async {
      for (final result in [
        profiles.saveResult,
        profiles.resetResult,
        profiles.logoutResult,
      ]) {
        if (!result.isCompleted) result.complete();
      }
      await tester.pumpWidget(const SizedBox());
      await auth.close();
      await profiles.dispose();
      await events.dispose();
    });
  }

  Future<void> show(WidgetTester tester, String text) async {
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        250,
        scrollable: scrollable,
      );
    } else {
      await tester.ensureVisible(find.text(text));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'home profile shows identity, prefilled name and live statistics',
    (tester) async {
      await open(tester);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      await show(tester, 'Participants in your events');
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Participants in your events'),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      events.created.add([]);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Created events'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'name draft survives snapshots; saving keeps session and later drafts',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField), 'Updated Alice');
      profiles.updates.add(
        const UserProfile(
          userId: 'organizer',
          name: 'Remote',
          email: 'alice@example.com',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated Alice'), findsOneWidget);
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      expect(profiles.saves, 1);
      profiles.saveResult.complete();
      profiles.updates.add(
        const UserProfile(
          userId: 'organizer',
          name: 'Updated Alice',
          email: 'alice@example.com',
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.state, isA<AuthAuthenticated>());
      expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Unsaved');
      profiles.updates.add(sampleProfile);
      await tester.pumpAndSettle();
      expect(find.text('Unsaved'), findsOneWidget);
    },
  );
  testWidgets('empty name validation prevents write', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name'), findsOneWidget);
    expect(profiles.saves, 0);
  });
  testWidgets('reset confirmation sends once and preserves session', (
    tester,
  ) async {
    await open(tester);
    await show(tester, 'Reset Password');
    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('alice@example.com?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(profiles.resets, 0);
    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Email'));
    await tester.pumpAndSettle();
    expect(profiles.resets, 1);
    expect(find.text('Sending...'), findsOneWidget);
    profiles.resetResult.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Password reset email sent'), findsOneWidget);
    expect(auth.state, isA<AuthAuthenticated>());
  });
  testWidgets(
    'logout confirmation returns to login and disposes profile streams',
    (tester) async {
      await open(tester);
      await show(tester, 'Sign Out');
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(profiles.logouts, 0);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pumpAndSettle();
      profiles.logoutResult.complete();
      await tester.pumpAndSettle();
      expect(find.text('Logged out'), findsOneWidget);
      expect(find.text('alice@example.com'), findsNothing);
      expect(profiles.updates.hasListener, false);
      expect(events.created.hasListener, false);
    },
  );
  testWidgets(
    'unsupported provider disables reset and statistic errors remain visible',
    (tester) async {
      await open(
        tester,
        profile: const UserProfile(
          userId: 'organizer',
          name: 'Alice',
          email: 'alice@example.com',
          canResetPassword: false,
        ),
      );
      events.registered.addError(StateError('index missing'));
      await tester.pumpAndSettle();
      await show(tester, 'Reset Password');
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Reset Password'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('index missing'), findsOneWidget);
      expect(auth.state, isA<AuthAuthenticated>());
    },
  );
}
