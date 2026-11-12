import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_model.dart';
import '../models/participant.dart';
import '../repositories/event_repository.dart';

enum ParticipantsStatus { loading, ready, denied, missing, error }

class ParticipantsState {
  final ParticipantsStatus status;
  final EventModel? event;
  final List<Participant> participants;
  final String? error;
  const ParticipantsState({
    this.status = ParticipantsStatus.loading,
    this.event,
    this.participants = const [],
    this.error,
  });
}

class ParticipantsCubit extends Cubit<ParticipantsState> {
  final EventStore repository;
  final String eventId;
  final String userId;
  StreamSubscription<EventModel?>? _eventSubscription;
  StreamSubscription<List<Participant>>? _participantsSubscription;
  int _generation = 0;
  int _listGeneration = 0;
  bool _reloading = false;
  ParticipantsCubit(this.repository, this.eventId, this.userId)
    : super(const ParticipantsState()) {
    reload();
  }

  Future<void> reload() async {
    if (_reloading || isClosed) return;
    _reloading = true;
    final generation = ++_generation;
    ++_listGeneration;
    emit(const ParticipantsState());
    try {
      await _eventSubscription?.cancel();
      await _participantsSubscription?.cancel();
      _participantsSubscription = null;
      if (isClosed) return;
      _eventSubscription = repository.watchEvent(eventId).listen((event) {
        if (isClosed || generation != _generation) return;
        if (event == null || event.organizerId != userId) {
          ++_listGeneration;
          final previous = _participantsSubscription;
          _participantsSubscription = null;
          if (previous != null) unawaited(previous.cancel());
          emit(
            ParticipantsState(
              status: event == null
                  ? ParticipantsStatus.missing
                  : ParticipantsStatus.denied,
            ),
          );
          return;
        }
        emit(
          ParticipantsState(
            status: _participantsSubscription == null
                ? ParticipantsStatus.loading
                : state.status,
            event: event,
            participants: state.participants,
            error: state.error,
          ),
        );
        if (_participantsSubscription != null) return;
        final listGeneration = ++_listGeneration;
        try {
          _participantsSubscription = repository
              .watchParticipants(eventId)
              .listen(
                (participants) {
                  if (isClosed ||
                      generation != _generation ||
                      listGeneration != _listGeneration) {
                    return;
                  }
                  emit(
                    ParticipantsState(
                      status: ParticipantsStatus.ready,
                      event: state.event,
                      participants: List.unmodifiable(participants),
                    ),
                  );
                },
                onError: (Object error) {
                  if (!isClosed &&
                      generation == _generation &&
                      listGeneration == _listGeneration) {
                    emit(
                      ParticipantsState(
                        status: ParticipantsStatus.error,
                        event: state.event,
                        error: error.toString(),
                      ),
                    );
                  }
                },
              );
        } catch (error) {
          _fail(error, generation);
        }
      }, onError: (Object error) => _fail(error, generation));
    } catch (error) {
      _fail(error, generation);
    } finally {
      _reloading = false;
    }
  }

  void _fail(Object error, int generation) {
    if (isClosed || generation != _generation) return;
    ++_listGeneration;
    final previous = _participantsSubscription;
    _participantsSubscription = null;
    if (previous != null) unawaited(previous.cancel());
    emit(
      ParticipantsState(
        status: ParticipantsStatus.error,
        error: error.toString(),
      ),
    );
  }

  @override
  Future<void> close() async {
    ++_generation;
    ++_listGeneration;
    final closing = super.close();
    final eventCancelled = _eventSubscription?.cancel();
    final participantsCancelled = _participantsSubscription?.cancel();
    await Future.wait([closing, ?eventCancelled, ?participantsCancelled]);
  }
}
