import 'dart:async';

import '../models/event_model.dart';

/// Joins only registered event documents, keeping subscriptions across ID updates.
Stream<List<EventModel>> watchReferencedEvents(
  Stream<Set<String>> ids,
  Stream<EventModel?> Function(String id) watch,
) {
  final subscriptions = <String, StreamSubscription<EventModel?>>{};
  final tokens = <String, Object>{};
  final values = <String, EventModel?>{};
  final pending = <String>{};
  StreamSubscription<Set<String>>? idSubscription;
  late StreamController<List<EventModel>> controller;
  bool closed = false;
  void publish() {
    if (closed || pending.isNotEmpty) return;
    final events = values.values.whereType<EventModel>().toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    controller.add(List.unmodifiable(events));
  }

  void fail(Object error, StackTrace stack) {
    if (!closed) controller.addError(error, stack);
  }

  controller = StreamController<List<EventModel>>(
    onListen: () {
      idSubscription = ids.listen((next) {
        for (final id in tokens.keys.toList()) {
          if (!next.contains(id)) {
            tokens.remove(id);
            values.remove(id);
            pending.remove(id);
            final old = subscriptions.remove(id);
            if (old != null) unawaited(old.cancel().catchError(fail));
          }
        }
        final added = next.difference(tokens.keys.toSet());
        pending.addAll(added);
        for (final id in added) {
          final token = Object();
          tokens[id] = token;
          try {
            subscriptions[id] = watch(id).listen(
              (event) {
                if (closed || tokens[id] != token) return;
                values[id] = event;
                pending.remove(id);
                publish();
              },
              onError: (Object error, StackTrace stack) {
                if (closed || tokens[id] != token) return;

                pending.remove(id);
                fail(error, stack);
              },
            );
          } catch (error, stack) {
            pending.remove(id);
            fail(error, stack);
          }
        }
        publish();
      }, onError: fail);
    },
    onCancel: () async {
      closed = true;
      await idSubscription?.cancel();
      await Future.wait(subscriptions.values.map((s) => s.cancel()));
      subscriptions.clear();
      tokens.clear();
      values.clear();
    },
  );
  return controller.stream;
}
