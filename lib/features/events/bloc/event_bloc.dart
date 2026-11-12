import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_model.dart';
import '../repositories/event_repository.dart';
import 'event_event.dart';
import 'event_state.dart';

/// Owns only the real-time list; write operations have route-scoped state.
class EventBloc extends Bloc<EventEvent, EventState> {
  final EventStore repository;
  StreamSubscription<List<EventModel>>? _eventsSubscription;
  bool _subscribing = false;
  bool _closing = false;
  int _generation = 0;

  EventBloc(this.repository) : super(const EventInitial()) {
    on<LoadEvents>((event, emit) async {
      if (_subscribing || _closing) return;
      if (_eventsSubscription != null && state is! EventError) return;
      _subscribing = true;
      final generation = ++_generation;
      emit(const EventLoading());
      try {
        await _eventsSubscription?.cancel();
        if (_closing) return;
        _eventsSubscription = repository.getEvents().listen(
          (events) {
            if (!_closing && generation == _generation) {
              add(EventsUpdated(List.unmodifiable(events)));
            }
          },
          onError: (Object error) {
            if (!_closing && generation == _generation) {
              add(EventsStreamFailed(error.toString()));
            }
          },
        );
      } catch (error) {
        if (!_closing) emit(EventError(error.toString()));
      } finally {
        _subscribing = false;
      }
    });
    on<EventsUpdated>((event, emit) => emit(EventLoaded(event.events)));
    on<EventsStreamFailed>((event, emit) => emit(EventError(event.message)));
  }

  @override
  Future<void> close() async {
    _closing = true;
    ++_generation;
    await _eventsSubscription?.cancel();
    await super.close();
  }
}
