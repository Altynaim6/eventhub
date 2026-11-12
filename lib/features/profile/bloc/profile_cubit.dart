import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../events/repositories/event_repository.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class ProfileData {
  final UserProfile? profile;
  final String? error;
  const ProfileData({this.profile, this.error});
}

class ProfileCount {
  final int? count;
  final int? participants;
  final String? error;
  const ProfileCount({this.count, this.participants, this.error});
}

enum ProfileAction { save, resetPassword, logout }

class ProfileState {
  final ProfileData data;
  final ProfileCount created;
  final ProfileCount registered;
  final ProfileAction? busy;
  final int noticeId;
  final String? notice;
  final ProfileAction? success;
  const ProfileState({
    this.data = const ProfileData(),
    this.created = const ProfileCount(),
    this.registered = const ProfileCount(),
    this.busy,
    this.noticeId = 0,
    this.notice,
    this.success,
  });
  ProfileState copyWith({
    ProfileData? data,
    ProfileCount? created,
    ProfileCount? registered,
    ProfileAction? busy,
    bool clearBusy = false,
    int? noticeId,
    String? notice,
    ProfileAction? success,
    bool clearSuccess = false,
  }) => ProfileState(
    data: data ?? this.data,
    created: created ?? this.created,
    registered: registered ?? this.registered,
    busy: clearBusy ? null : busy ?? this.busy,
    noticeId: noticeId ?? this.noticeId,
    notice: notice ?? this.notice,
    success: clearSuccess ? null : success ?? this.success,
  );
}

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileStore profiles;
  final EventStore events;
  final String userId;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _generation = 0;
  bool _reloading = false;
  ProfileCubit(this.profiles, this.events, this.userId)
    : super(const ProfileState()) {
    reload();
  }
  Future<void> reload() async {
    if (_reloading || isClosed) return;
    _reloading = true;
    final generation = ++_generation;
    emit(
      state.copyWith(
        data: const ProfileData(),
        created: const ProfileCount(),
        registered: const ProfileCount(),
      ),
    );
    try {
      await Future.wait(_subscriptions.map((s) => s.cancel()));
      _subscriptions.clear();
      if (isClosed) return;
      void connect<T>(
        Stream<T> Function() source,
        void Function(T) onData,
        void Function(Object) onError,
      ) {
        try {
          _subscriptions.add(
            source().listen(
              (value) {
                if (!isClosed && generation == _generation) onData(value);
              },
              onError: (Object error) {
                if (!isClosed && generation == _generation) onError(error);
              },
            ),
          );
        } catch (error) {
          if (!isClosed) onError(error);
        }
      }

      connect(
        profiles.watchProfile,
        (profile) {
          emit(
            state.copyWith(
              data: profile.userId == userId
                  ? ProfileData(profile: profile)
                  : const ProfileData(
                      error: 'Session changed. Please reopen your profile',
                    ),
            ),
          );
        },
        (error) =>
            emit(state.copyWith(data: ProfileData(error: error.toString()))),
      );
      connect(
        events.getMyEvents,
        (list) => emit(
          state.copyWith(
            created: ProfileCount(
              count: list.length,
              participants: list.fold<int>(
                0,
                (sum, event) => sum + event.registeredCount,
              ),
            ),
          ),
        ),
        (error) => emit(
          state.copyWith(created: ProfileCount(error: error.toString())),
        ),
      );
      connect(
        events.getRegisteredEvents,
        (list) =>
            emit(state.copyWith(registered: ProfileCount(count: list.length))),
        (error) => emit(
          state.copyWith(registered: ProfileCount(error: error.toString())),
        ),
      );
    } finally {
      _reloading = false;
    }
  }

  Future<void> saveName(String name) => _run(
    ProfileAction.save,
    () => profiles.updateName(UserProfile.validatedName(name)),
    'Profile saved',
  );
  Future<void> resetPassword() => _run(
    ProfileAction.resetPassword,
    profiles.resetPassword,
    'Password reset email sent. Check your inbox and spam folder',
  );
  Future<void> logout() =>
      _run(ProfileAction.logout, profiles.logout, 'Signed out');
  Future<void> _run(
    ProfileAction action,
    Future<void> Function() run,
    String notice,
  ) async {
    if (isClosed ||
        state.busy != null ||
        (action != ProfileAction.logout && state.data.profile == null)) {
      return;
    }
    emit(state.copyWith(busy: action, clearSuccess: true));
    try {
      await run();
      if (!isClosed) {
        emit(
          state.copyWith(
            clearBusy: true,
            noticeId: state.noticeId + 1,
            notice: notice,
            success: action,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            clearBusy: true,
            noticeId: state.noticeId + 1,
            notice: error.toString(),
            clearSuccess: true,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    final closing = super.close();
    final cancelled = _subscriptions.map((s) => s.cancel()).toList();
    await Future.wait([closing, ...cancelled]);
  }
}
