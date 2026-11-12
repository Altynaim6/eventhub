import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/event_model.dart';
import '../models/participant.dart';
import 'registered_events_stream.dart';

abstract interface class EventStore {
  Stream<List<EventModel>> getEvents();
  Stream<List<EventModel>> getMyEvents();
  Stream<List<EventModel>> getRegisteredEvents();
  Future<String> createEvent(EventModel event);
  Future<void> updateEvent(EventModel event);
  Future<void> deleteEvent(String eventId);
  Stream<EventModel?> watchEvent(String eventId);
  Stream<bool> watchRegistration(String eventId);
  Stream<List<Participant>> watchParticipants(String eventId);
  Future<void> registerForEvent(String eventId);
  Future<void> cancelRegistration(String eventId);
}

class EventRepository implements EventStore {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EventRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  // CREATE: Create a new event
  @override
  Future<String> createEvent(EventModel event) async {
    final user = _auth.currentUser;
    debugPrint('REGISTERED EVENTS USER: ${user?.uid}');

    if (user == null) {
      throw Exception('You must be logged in to create an event');
    }

    _validate(event);

    final data = event.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['registeredCount'] = 0;
    data['title'] = event.title.trim();
    data['description'] = event.description.trim();
    data['location'] = event.location.trim();

    // Never trust organizerId provided by the UI.
    data['organizerId'] = user.uid;

    final document = await _events.add(data);

    return document.id;
  }

  // READ: Get all events in real time
  @override
  Stream<List<EventModel>> getEvents() {
    return _events.orderBy('date').snapshots().map((snapshot) {
      debugPrint(
        'REGISTERED EVENTS DOCUMENTS: ${snapshot.docs.length}',
      );
      return snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
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
  @override
  Stream<List<EventModel>> getMyEvents() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _events.where('organizerId', isEqualTo: user.uid).snapshots().map((
      snapshot,
    ) {
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      events.sort((a, b) => a.date.compareTo(b.date));

      return events;
    });
  }

  @override
  Stream<List<EventModel>> getRegisteredEvents() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    final ids = _firestore
        .collectionGroup('registrations')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) {
                final parts = doc.reference.path.split('/');
                return parts.length == 4 && parts[0] == 'events';
              })
              .map((doc) => doc.reference.parent.parent!.id)
              .toSet();
        });
    return watchReferencedEvents(ids, watchEvent);
  }

  // UPDATE: Edit an existing event
  @override
  Future<void> updateEvent(EventModel event) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in');
    }

    _validate(event);
    final ref = _events.doc(event.id);
    await _firestore.runTransaction((transaction) async {
      final document = await transaction.get(ref);
      if (!document.exists) throw StateError('Event not found');
      final stored = EventModel.fromFirestore(document);
      if (stored.organizerId != user.uid) {
        throw StateError('You can only edit your own events');
      }
      if (event.capacity < stored.registeredCount) {
        throw StateError('Capacity cannot be below the participant count');
      }
      transaction.update(ref, {
        'title': event.title.trim(),
        'description': event.description.trim(),
        'category': event.category,
        'date': Timestamp.fromDate(event.date),
        'location': event.location.trim(),
        'capacity': event.capacity,
      });
    });
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in');
    final ref = _events.doc(eventId);
    await _firestore.runTransaction((transaction) async {
      final document = await transaction.get(ref);
      if (!document.exists) throw StateError('Event not found');
      final stored = EventModel.fromFirestore(document);
      if (stored.organizerId != user.uid) {
        throw StateError('You can only delete your own events');
      }
      if (stored.registeredCount != 0) {
        throw StateError('An event with participants cannot be deleted');
      }
      transaction.delete(ref);
    });
  }

  @override
  Stream<EventModel?> watchEvent(String eventId) => _events
      .doc(eventId)
      .snapshots()
      .map((doc) => doc.exists ? EventModel.fromFirestore(doc) : null);

  @override
  Stream<bool> watchRegistration(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);
    return _events
        .doc(eventId)
        .collection('registrations')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Stream<List<Participant>> watchParticipants(String eventId) async* {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in');
    final event = await getEventById(eventId);
    if (event == null) throw StateError('Event not found');
    if (event.organizerId != user.uid) {
      throw StateError('Only the organizer can view participants');
    }
    yield* _events.doc(eventId).collection('registrations').snapshots().map((
      snapshot,
    ) {
      final participants =
          snapshot.docs
              .map((doc) => Participant.fromMap(doc.id, doc.data()))
              .toList()
            ..sort(Participant.compare);
      return List<Participant>.unmodifiable(participants);
    });
  }

  @override
  Future<void> registerForEvent(String eventId) =>
      _changeRegistration(eventId, true);

  @override
  Future<void> cancelRegistration(String eventId) =>
      _changeRegistration(eventId, false);

  Future<void> _changeRegistration(String eventId, bool register) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in');
    final eventRef = _events.doc(eventId);
    // A UID document is the unique registration key, including concurrent clients.
    final registrationRef = eventRef.collection('registrations').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final eventDoc = await transaction.get(eventRef);
      final registration = await transaction.get(registrationRef);
      if (!eventDoc.exists) throw StateError('Event not found');
      final stored = EventModel.fromFirestore(eventDoc);
      if (register) {
        if (registration.exists) throw StateError('You are already registered');
        if (!stored.date.isAfter(DateTime.now())) {
          throw StateError('Registration is closed');
        }
        if (stored.availablePlaces == 0) throw StateError('Event is full');
        transaction.set(registrationRef, {
          'userId': user.uid,
          'registeredAt': FieldValue.serverTimestamp(),
          if (user.displayName?.trim().isNotEmpty == true)
            'displayName': String.fromCharCodes(
              user.displayName!.trim().runes.take(100),
            ),
        });
      } else {
        if (!registration.exists) throw StateError('You are not registered');
        if (stored.registeredCount <= 0) {
          throw StateError('Invalid participant count');
        }
        transaction.delete(registrationRef);
      }
      transaction.update(eventRef, {
        'registeredCount': stored.registeredCount + (register ? 1 : -1),
      });
    });
  }

  void _validate(EventModel event) {
    if (event.title.trim().isEmpty ||
        event.description.trim().isEmpty ||
        event.location.trim().isEmpty ||
        event.category.trim().isEmpty) {
      throw ArgumentError('Please fill in all event fields');
    }
    if (event.capacity <= 0) throw ArgumentError('Capacity must be positive');
    if (!event.date.isAfter(DateTime.now())) {
      throw ArgumentError('Event date must be in the future');
    }
  }
}
