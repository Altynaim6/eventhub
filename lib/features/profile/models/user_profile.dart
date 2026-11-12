import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String userId;
  final String name;
  final String? email;
  final DateTime? createdAt;
  final bool emailVerified;
  final bool canResetPassword;
  const UserProfile({
    required this.userId,
    required this.name,
    this.email,
    this.createdAt,
    this.emailVerified = false,
    this.canResetPassword = true,
  });

  factory UserProfile.fromMap(
    String userId,
    Map<String, dynamic>? data, {
    String? authName,
    String? email,
    DateTime? authCreatedAt,
    bool emailVerified = false,
    bool canResetPassword = true,
  }) => UserProfile(
    userId: userId,
    name: data?['name'] as String? ?? authName ?? '',
    email: email,
    createdAt: authCreatedAt ?? (data?['createdAt'] as Timestamp?)?.toDate(),
    emailVerified: emailVerified,
    canResetPassword: canResetPassword,
  );

  static String? nameError(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Please enter your name';
    if (name.runes.length > 100) return 'Name must be at most 100 characters';
    return null;
  }

  static String validatedName(String value) {
    final error = nameError(value);
    if (error != null) throw ArgumentError(error);
    return value.trim();
  }

  @override
  List<Object?> get props => [
    userId,
    name,
    email,
    createdAt,
    emailVerified,
    canResetPassword,
  ];
}
