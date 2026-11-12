import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/profile/models/user_profile.dart';

void main() {
  test('missing profile falls back to authenticated identity metadata', () {
    final date = DateTime(2026, 11, 11);
    final profile = UserProfile.fromMap(
      'uid',
      null,
      authName: 'Alice',
      email: 'alice@example.com',
      authCreatedAt: date,
    );
    expect(profile.name, 'Alice');
    expect(profile.createdAt, date);
    expect(profile.userId, 'uid');
  });
  test(
    'stored name is used but profile document cannot override auth email',
    () {
      final profile = UserProfile.fromMap('uid', {
        'name': 'Saved name',
        'email': 'forged@example.com',
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      }, email: 'real@example.com');
      expect(profile.name, 'Saved name');
      expect(profile.email, 'real@example.com');
    },
  );
  test('validates trimmed Cyrillic name and code-point length', () {
    expect(UserProfile.validatedName('  Айдана  '), 'Айдана');
    expect(UserProfile.nameError('  '), isNotNull);
    expect(UserProfile.nameError(List.filled(101, 'A').join()), isNotNull);
    expect(UserProfile.nameError(String.fromCharCode(0x1F642) * 100), isNull);
  });
}
