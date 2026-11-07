import 'package:equatable/equatable.dart';

import '../models/event_model.dart';

abstract class EventState extends Equatable {
  const EventState();

  @override
  List<Object?> get props => [];
}

// Initial state
class EventInitial extends EventState {
  const EventInitial();
}

// Loading events
class EventLoading extends EventState {
  const EventLoading();
}

// Events loaded successfully
class EventLoaded extends EventState {
  final List<EventModel> events;

  const EventLoaded(this.events);

  @override
  List<Object?> get props => [events];
}

// Creating, updating or deleting an event
class EventOperationInProgress extends EventState {
  final List<EventModel> events;

  const EventOperationInProgress(this.events);

  @override
  List<Object?> get props => [events];
}

// CRUD operation completed successfully
class EventOperationSuccess extends EventState {
  final String message;
  final List<EventModel> events;

  const EventOperationSuccess({
    required this.message,
    required this.events,
  });

  @override
  List<Object?> get props => [message, events];
}

// Error state
class EventError extends EventState {
  final String message;

  const EventError(this.message);

  @override
  List<Object?> get props => [message];
}