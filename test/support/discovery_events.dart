import 'package:eventhub/features/events/models/event_model.dart';

EventModel discoveryEvent(
  String id, {
  String title = 'Campus Talk',
  String location = 'Bishkek',
  String category = 'Education',
  DateTime? date,
  int capacity = 10,
  int count = 0,
}) => EventModel(
  id: id,
  title: title,
  description: 'Description',
  category: category,
  date: date ?? DateTime(2030, 6, 10, 12),
  location: location,
  capacity: capacity,
  registeredCount: count,
  organizerId: 'organizer',
);
