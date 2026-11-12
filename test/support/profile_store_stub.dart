import 'dart:async';

import 'package:eventhub/features/profile/models/user_profile.dart';
import 'package:eventhub/features/profile/repositories/profile_repository.dart';

const sampleProfile = UserProfile(
  userId: 'organizer',
  name: 'Alice',
  email: 'alice@example.com',
);

class ProfileStoreStub implements ProfileStore {
  final updates = StreamController<UserProfile>.broadcast();
  Completer<void> saveResult = Completer<void>();
  Completer<void> resetResult = Completer<void>();
  Completer<void> logoutResult = Completer<void>();
  int saves = 0;
  int resets = 0;
  int logouts = 0;
  int subscriptions = 0;
  String? name;
  void Function()? onLogout;
  @override
  Stream<UserProfile> watchProfile() {
    subscriptions++;
    return updates.stream;
  }

  @override
  Future<void> updateName(String value) async {
    saves++;
    name = value;
    await saveResult.future;
  }

  @override
  Future<void> resetPassword() async {
    resets++;
    await resetResult.future;
  }

  @override
  Future<void> logout() async {
    logouts++;
    await logoutResult.future;
    onLogout?.call();
  }

  Future<void> dispose() async {
    for (final result in [saveResult, resetResult, logoutResult]) {
      if (!result.isCompleted) result.complete();
    }
    await updates.close();
  }
}
