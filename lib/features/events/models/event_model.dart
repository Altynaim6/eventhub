import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class EventModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime date;
  final String location;
  final int capacity;
  final String organizerId;
  final DateTime? createdAt;
  final int registeredCount;

  int get availablePlaces => (capacity - registeredCount).clamp(0, capacity);

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.location,
    required this.capacity,
    required this.organizerId,
    this.createdAt,
    this.registeredCount = 0,
  });

  // Convert Firestore document to EventModel
  factory EventModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    if (data == null) {
      throw StateError('Event document ${doc.id} does not exist');
    }

    return EventModel.fromMap(doc.id, data);
  }

  factory EventModel.fromMap(String id, Map<String, dynamic> data) {
    return EventModel(
      id: id,
      title: data['title'] as String,
      description: data['description'] as String,
      category: data['category'] as String,
      date: (data['date'] as Timestamp).toDate(),
      location: data['location'] as String,
      capacity: (data['capacity'] as num).toInt(),
      organizerId: data['organizerId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      registeredCount: (data['registeredCount'] as num?)?.toInt() ?? 0,
    );
  }

  // Convert EventModel to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'date': Timestamp.fromDate(date),
      'location': location,
      'capacity': capacity,
      'registeredCount': registeredCount,
      'organizerId': organizerId,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    category,
    date,
    location,
    capacity,
    organizerId,
    createdAt,
    registeredCount,
  ];
}
