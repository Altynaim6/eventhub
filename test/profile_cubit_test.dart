import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/profile/bloc/profile_cubit.dart';
import 'package:eventhub/features/profile/models/user_profile.dart';

import 'event_bloc_test.dart' show sample, flushEvents;
import 'support/profile_store_stub.dart';
import 'support/my_store.dart';
import 'support/discovery_events.dart';

void main() {
  late ProfileStoreStub profiles;
  late MyStore events;
  late ProfileCubit cubit;
  setUp(() async {
    profiles = ProfileStoreStub();
    events = MyStore();
    cubit = ProfileCubit(profiles, events, 'organizer');
    await flushEvents();
  });
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await profiles.dispose();
    await events.dispose();
  });
  Future<void> ready() async {
    profiles.updates.add(sampleProfile);
    events.created.add([]);
    events.registered.add([]);
    await flushEvents();
  }

  test('profile and live statistics load independently and failures do not become zero', () async {
    profiles.updates.add(sampleProfile);
    events.created.add([discoveryEvent('1', count: 3)]);
    await flushEvents();
    expect(cubit.state.data.profile, sampleProfile);
    expect(cubit.state.created.count, 1);
    expect(cubit.state.created.participants, 3);
    expect(cubit.state.registered.count, isNull);
    events.registered.add([sample]);
    await flushEvents();
    expect(cubit.state.registered.count, 1);
    events.registered.addError(StateError('index missing'));
    await flushEvents();
    expect(cubit.state.registered.count, isNull);
    expect(cubit.state.registered.error, contains('index missing'));
    expect(cubit.state.data.profile, sampleProfile);
  });
  test('shared guard prevents duplicate and cross-operation submissions through snapshots', () async {
    await ready();
    final pending = cubit.saveName('  Updated  ');
    await cubit.saveName('Again');
    await cubit.resetPassword();
    await cubit.logout();
    profiles.updates.add(sampleProfile);
    events.created.add([]);
    await flushEvents();
    expect(profiles.saves, 1);
    expect(profiles.name, 'Updated');
    expect(profiles.resets, 0);
    expect(profiles.logouts, 0);
    expect(cubit.state.busy, ProfileAction.save);
    profiles.saveResult.complete();
    await pending;
    expect(cubit.state.busy, isNull);
    expect(cubit.state.success, ProfileAction.save);
  });
  test('invalid name is rejected before repository write; failures preserve identity and allow retry', () async {
    await ready();
    await cubit.saveName('   ');
    expect(profiles.saves, 0);
    final pending = cubit.saveName('Updated');
    profiles.saveResult.completeError(StateError('offline'));
    await pending;
    expect(cubit.state.data.profile, sampleProfile);
    expect(cubit.state.notice, contains('offline'));
    profiles.saveResult = Completer<void>()..complete();
    await cubit.saveName('Updated');
    expect(cubit.state.success, ProfileAction.save);
  });
  test(
    'password reset and logout complete without changing profile load state',
    () async {
      await ready();
      final pending = cubit.resetPassword();
      profiles.resetResult.complete();
      await pending;
      expect(cubit.state.success, ProfileAction.resetPassword);
      expect(cubit.state.data.profile, sampleProfile);
      final logout = cubit.logout();
      profiles.logoutResult.complete();
      await logout;
      expect(cubit.state.success, ProfileAction.logout);
    },
  );
  test(
    'profile error still allows logout and reload replaces streams',
    () async {
      profiles.updates.addError(StateError('denied'));
      await flushEvents();
      expect(cubit.state.data.profile, isNull);
      await Future.wait([cubit.reload(), cubit.reload()]);
      expect(profiles.subscriptions, 2);
      final pending = cubit.logout();
      profiles.logoutResult.complete();
      await pending;
      expect(cubit.state.success, ProfileAction.logout);
    },
  );
  test(
    'different user profile is not exposed; close ignores pending completions',
    () async {
      await ready();
      final pending = cubit.saveName('Updated');
      profiles.updates.add(const UserProfile(userId: 'other', name: 'Private'));
      await flushEvents();
      expect(cubit.state.data.profile, isNull);
      expect(cubit.state.data.error, contains('Session changed'));
      await cubit.close();
      expect(profiles.updates.hasListener, false);
      expect(events.created.hasListener, false);
      expect(events.registered.hasListener, false);
      profiles.saveResult.complete();
      await pending;
    },
  );
}
