import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';

class EventRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EventRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  // CREATE: Create a new event
  Future<String> createEvent(EventModel event) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to create an event');
    }

    if (event.title.trim().isEmpty) {
      throw Exception('Event title cannot be empty');
    }

    if (event.capacity <= 0) {
      throw Exception('Event capacity must be greater than zero');
    }

    final data = event.toFirestore();

    // Never trust organizerId provided by the UI.
    data['organizerId'] = user.uid;

    final document = await _events.add(data);

    return document.id;
  }

  // READ: Get all events in real time
  Stream<List<EventModel>> getEvents() {
    return _events
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();
    });
  }

  // READ: Get one event by ID
  Future<EventModel?> getEventById(String eventId) async {
    final document = await _events.doc(eventId).get();

    if (!document.exists) {
      return null;
    }

    return EventModel.fromFirestore(document);
  }

  // READ: Get events created by current user
  Stream<List<EventModel>> getMyEvents() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _events
        .where('organizerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      events.sort((a, b) => a.date.compareTo(b.date));

      return events;
    });
  }

  // UPDATE: Edit an existing event
  Future<void> updateEvent(EventModel event) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in');
    }

    final document = await _events.doc(event.id).get();

    if (!document.exists) {
      throw Exception('Event not found');
    }

    final existingEvent = EventModel.fromFirestore(document);

    if (existingEvent.organizerId != user.uid) {
      throw Exception('You can only edit your own events');
    }

    if (event.title.trim().isEmpty) {
      throw Exception('Event title cannot be empty');
    }

    if (event.capacity <= 0) {
      throw Exception('Event capacity must be greater than zero');
    }

    await _events.doc(event.id).update({
      'title': event.title,
      'description': event.description,
      'category': event.category,
      'date': Timestamp.fromDate(event.date),
      'location': event.location,
      'capacity': event.capacity,
    });
  }

  // DELETE: Delete an event
  Future<void> deleteEvent(String eventId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in');
    }

    final document = await _events.doc(eventId).get();

    if (!document.exists) {
      throw Exception('Event not found');
    }

    final event = EventModel.fromFirestore(document);

    if (event.organizerId != user.uid) {
      throw Exception('You can only delete your own events');
    }

    await _events.doc(eventId).delete();
  }
}