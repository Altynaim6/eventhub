import 'package:equatable/equatable.dart';

import '../models/event_model.dart';

abstract class EventEvent extends Equatable {
  const EventEvent();

  @override
  List<Object?> get props => [];
}

// Load events from Firestore
class LoadEvents extends EventEvent {
  const LoadEvents();
}

// Receive updated events from Firestore
class EventsUpdated extends EventEvent {
  final List<EventModel> events;

  const EventsUpdated(this.events);

  @override
  List<Object?> get props => [events];
}

// Create a new event
class CreateEvent extends EventEvent {
  final EventModel event;

  const CreateEvent(this.event);

  @override
  List<Object?> get props => [event];
}

// Update an existing event
class UpdateEvent extends EventEvent {
  final EventModel event;

  const UpdateEvent(this.event);

  @override
  List<Object?> get props => [event];
}

// Delete an event
class DeleteEvent extends EventEvent {
  final String eventId;

  const DeleteEvent(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

// Internal event for Firestore stream errors
class EventsStreamFailed extends EventEvent {
  final String message;

  const EventsStreamFailed(this.message);

  @override
  List<Object?> get props => [message];
}