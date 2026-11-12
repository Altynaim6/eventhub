import 'package:eventhub/features/auth/bloc/auth_bloc.dart';
import 'package:eventhub/features/auth/screens/login_screen.dart';
import 'package:eventhub/ui/event_hub_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_management_widget_test.dart' show SessionBloc;

void main() {
  testWidgets(
    'login scrolls above the keyboard and stays readable on wide windows',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        BlocProvider<AuthBloc>(
          create: (_) => SessionBloc('user'),
          child: MaterialApp(
            theme: eventHubTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const LoginScreen(),
          ),
        ),
      );

      final login = find.widgetWithText(FilledButton, 'Login');
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      expect(login.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField).first);
      expect(field.width, lessThanOrEqualTo(520));
      expect(field.center.dx, closeTo(720, 1));
      expect(tester.takeException(), isNull);
    },
  );
}
