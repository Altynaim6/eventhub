import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

abstract interface class ProfileStore {
  Stream<UserProfile> watchProfile();
  Future<void> updateName(String name);
  Future<void> resetPassword();
  Future<void> logout();
}

class ProfileRepository implements ProfileStore {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  ProfileRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;
  User _user() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please log in first');
    return user;
  }

  @override
  Stream<UserProfile> watchProfile() async* {
    final user = _user();
    yield* _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map(
          (doc) => UserProfile.fromMap(
            user.uid,
            doc.data(),
            authName: user.displayName,
            email: user.email,
            authCreatedAt: user.metadata.creationTime,
            emailVerified: user.emailVerified,
            canResetPassword: user.providerData.any(
              (provider) => provider.providerId == 'password',
            ),
          ),
        );
  }

  @override
  Future<void> updateName(String name) async {
    final valid = UserProfile.validatedName(name);
    final user = _user();
    final ref = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.exists) {
        tx.update(ref, {'name': valid});
      } else {
        tx.set(ref, {
          'name': valid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
    if (_user().uid != user.uid) {
      throw StateError('Session changed. Please reopen your profile');
    }
    try {
      await user.updateDisplayName(valid);
    } catch (_) {
      throw StateError(
        'Profile saved, but account name synchronization failed. Please save again',
      );
    }
  }

  @override
  Future<void> resetPassword() async {
    final user = _user();
    final email = user.email;
    if (email == null ||
        !user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      throw StateError('Password reset is unavailable for this account');
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> logout() => _auth.signOut();
}
