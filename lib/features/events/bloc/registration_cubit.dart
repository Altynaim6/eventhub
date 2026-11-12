import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_model.dart';
import '../repositories/event_repository.dart';

class RegistrationState {
  final EventModel? event;
  final bool? registered;
  final bool loading;
  final bool busy;
  final String? error;
  const RegistrationState({
    this.event,
    this.registered,
    this.loading = true,
    this.busy = false,
    this.error,
  });
}

/// Route-scoped live event/registration data, separate from editor navigation.
class RegistrationCubit extends Cubit<RegistrationState> {
  final EventStore repository;
  final String eventId;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  RegistrationCubit(this.repository, this.eventId)
    : super(const RegistrationState()) {
    _subscriptions.add(
      repository.watchEvent(eventId).listen((event) {
        if (!isClosed) {
          emit(
            RegistrationState(
              event: event,
              registered: state.registered,
              loading: false,
              busy: state.busy,
            ),
          );
        }
      }, onError: _onError),
    );
    _subscriptions.add(
      repository.watchRegistration(eventId).listen((registered) {
        if (!isClosed) {
          emit(
            RegistrationState(
              event: state.event,
              registered: registered,
              loading: state.loading,
              busy: state.busy,
            ),
          );
        }
      }, onError: _onError),
    );
  }

  void _onError(Object error) {
    if (!isClosed) {
      emit(
        RegistrationState(
          event: state.event,
          registered: state.registered,
          loading: false,
          busy: state.busy,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> setRegistered(bool register) async {
    if (state.busy ||
        state.loading ||
        state.registered == null ||
        state.event == null) {
      return;
    }
    emit(
      RegistrationState(
        event: state.event,
        registered: state.registered,
        loading: false,
        busy: true,
      ),
    );
    try {
      if (register) {
        await repository.registerForEvent(eventId);
      } else {
        await repository.cancelRegistration(eventId);
      }
      if (!isClosed) {
        emit(
          RegistrationState(
            event: state.event,
            registered: register,
            loading: false,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          RegistrationState(
            event: state.event,
            registered: state.registered,
            loading: false,
            error: error.toString(),
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
