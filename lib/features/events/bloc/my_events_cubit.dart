import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_model.dart';
import '../repositories/event_repository.dart';

class MyEventList {
  final List<EventModel> events;
  final bool loading;
  final String? error;
  const MyEventList({this.events = const [], this.loading = true, this.error});
}

class MyEventsState {
  final MyEventList created;
  final MyEventList registered;
  final Set<String> cancelling;
  final int noticeId;
  final String? notice;
  const MyEventsState({
    this.created = const MyEventList(),
    this.registered = const MyEventList(),
    this.cancelling = const {},
    this.noticeId = 0,
    this.notice,
  });
  MyEventsState copyWith({
    MyEventList? created,
    MyEventList? registered,
    Set<String>? cancelling,
    int? noticeId,
    String? notice,
  }) => MyEventsState(
    created: created ?? this.created,
    registered: registered ?? this.registered,
    cancelling: cancelling ?? this.cancelling,
    noticeId: noticeId ?? this.noticeId,
    notice: notice ?? this.notice,
  );
}

class MyEventsCubit extends Cubit<MyEventsState> {
  final EventStore repository;
  final List<StreamSubscription<List<EventModel>>> _subscriptions = [];
  bool _subscribing = false;
  int _generation = 0;
  MyEventsCubit(this.repository) : super(const MyEventsState()) {
    reload();
  }

  Future<void> reload() async {
    if (_subscribing || isClosed) return;
    _subscribing = true;
    final generation = ++_generation;
    emit(
      state.copyWith(
        created: const MyEventList(),
        registered: const MyEventList(),
      ),
    );
    try {
      await Future.wait(_subscriptions.map((s) => s.cancel()));
      _subscriptions.clear();
      if (isClosed) return;
      void connect(bool created, Stream<List<EventModel>> Function() source) {
        void update(MyEventList list) {
          if (isClosed || generation != _generation) return;
          emit(
            created
                ? state.copyWith(created: list)
                : state.copyWith(registered: list),
          );
        }

        try {
          _subscriptions.add(
            source().listen(
              (events) {
                update(
                  MyEventList(
                    events: List.unmodifiable(events),
                    loading: false,
                  ),
                );
              },
              onError: (Object error) {
                final old = created ? state.created : state.registered;
                update(
                  MyEventList(
                    events: old.events,
                    loading: false,
                    error: error.toString(),
                  ),
                );
              },
            ),
          );
        } catch (error) {
          update(MyEventList(loading: false, error: error.toString()));
        }
      }

      connect(true, repository.getMyEvents);
      connect(false, repository.getRegisteredEvents);
    } finally {
      _subscribing = false;
    }
  }

  Future<void> cancel(String eventId) async {
    if (isClosed || state.cancelling.contains(eventId)) return;
    emit(
      state.copyWith(
        cancelling: Set.unmodifiable({...state.cancelling, eventId}),
      ),
    );
    String notice;
    try {
      await repository.cancelRegistration(eventId);
      notice = 'Registration cancelled';
    } catch (error) {
      notice = error.toString();
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        cancelling: Set.unmodifiable({...state.cancelling}..remove(eventId)),
        noticeId: state.noticeId + 1,
        notice: notice,
      ),
    );
  }

  @override
  Future<void> close() async {
    ++_generation;
    await super.close();
    await Future.wait(_subscriptions.map((s) => s.cancel()));
  }
}
