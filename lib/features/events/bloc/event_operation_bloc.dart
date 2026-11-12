import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/event_repository.dart';
import 'event_event.dart';
import 'event_state.dart';

/// One instance per editor route, independent of Firestore list updates.
class EventOperationBloc extends Bloc<EventEvent, EventState> {
  final EventStore repository;
  bool _busy = false;

  EventOperationBloc(this.repository) : super(const EventInitial()) {
    on<CreateEvent>(
      (event, emit) => _run(emit, () async {
        await repository.createEvent(event.event);
      }, 'Event created successfully!'),
    );
    on<UpdateEvent>(
      (event, emit) => _run(
        emit,
        () => repository.updateEvent(event.event),
        'Event updated successfully!',
      ),
    );
    on<DeleteEvent>(
      (event, emit) => _run(
        emit,
        () => repository.deleteEvent(event.eventId),
        'Event deleted successfully!',
      ),
    );
  }

  Future<void> _run(
    Emitter<EventState> emit,
    Future<void> Function() operation,
    String message,
  ) async {
    // Shared guard also prevents concurrent writes of different event types.
    if (_busy) return;
    _busy = true;
    emit(const EventOperationInProgress([]));
    try {
      await operation();
      if (!emit.isDone) {
        emit(EventOperationSuccess(message: message, events: const []));
      }
    } catch (error) {
      if (!emit.isDone) emit(EventError(error.toString()));
    } finally {
      _busy = false;
    }
  }
}
