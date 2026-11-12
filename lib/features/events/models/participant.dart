import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Participant extends Equatable {
  final String userId;
  final String? displayName;
  final DateTime? registeredAt;
  const Participant({
    required this.userId,
    this.displayName,
    this.registeredAt,
  });
  String get label =>
      displayName?.trim().isNotEmpty == true ? displayName! : userId;

  factory Participant.fromMap(String id, Map<String, dynamic> data) =>
      Participant(
        userId: id,
        displayName: data['displayName'] as String?,
        registeredAt: (data['registeredAt'] as Timestamp?)?.toDate(),
      );

  static int compare(Participant a, Participant b) {
    final first = a.registeredAt;
    final second = b.registeredAt;
    if (first == null && second != null) return 1;
    if (first != null && second == null) return -1;
    final date = first == null ? 0 : first.compareTo(second!);
    return date != 0 ? date : a.userId.compareTo(b.userId);
  }

  @override
  List<Object?> get props => [userId, displayName, registeredAt];
}
