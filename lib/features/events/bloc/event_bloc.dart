import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_model.dart';
import '../repositories/event_repository.dart';
import 'event_event.dart';
import 'event_state.dart';

class EventBloc extends Bloc<EventEvent, EventState> {
  final EventRepository repository;

  StreamSubscription<List<EventModel>>? _eventsSubscription;

  List<EventModel> _currentEvents = [];

  EventBloc(this.repository) : super(const EventInitial()) {
    // LOAD EVENTS
    on<LoadEvents>((event, emit) async {
      emit(const EventLoading());

      await _eventsSubscription?.cancel();

      _eventsSubscription = repository.getEvents().listen(
        (events) {
          add(EventsUpdated(events));
        },
        onError: (Object error) {
          add(EventsStreamFailed(error.toString()));
        },
      );
    });

    // EVENTS UPDATED
    on<EventsUpdated>((event, emit) {
      _currentEvents = event.events;

      emit(EventLoaded(event.events));
    });

    // STREAM ERROR
    on<EventsStreamFailed>((event, emit) {
      emit(EventError(event.message));
    });

    // CREATE EVENT
    on<CreateEvent>((event, emit) async {
      emit(EventOperationInProgress(_currentEvents));

      try {
        await repository.createEvent(event.event);

        emit(
          EventOperationSuccess(
            message: 'Event created successfully!',
            events: _currentEvents,
          ),
        );
      } catch (e) {
        emit(EventError(e.toString()));
      }
    });

    // UPDATE EVENT
    on<UpdateEvent>((event, emit) async {
      emit(EventOperationInProgress(_currentEvents));

      try {
        await repository.updateEvent(event.event);

        emit(
          EventOperationSuccess(
            message: 'Event updated successfully!',
            events: _currentEvents,
          ),
        );
      } catch (e) {
        emit(EventError(e.toString()));
      }
    });

    // DELETE EVENT
    on<DeleteEvent>((event, emit) async {
      emit(EventOperationInProgress(_currentEvents));

      try {
        await repository.deleteEvent(event.eventId);

        emit(
          EventOperationSuccess(
            message: 'Event deleted successfully!',
            events: _currentEvents,
          ),
        );
      } catch (e) {
        emit(EventError(e.toString()));
      }
    });
  }

  @override
  Future<void> close() async {
    await _eventsSubscription?.cancel();
    await super.close();
  }
}