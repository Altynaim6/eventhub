import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/models/participant.dart';

void main() {
  test(
    'legacy participant uses document UID and tolerates missing date/name',
    () {
      final participant = Participant.fromMap('alice', {'userId': 'forged'});
      expect(participant.userId, 'alice');
      expect(participant.label, 'alice');
      expect(participant.registeredAt, isNull);
    },
  );
  test(
    'decodes dates and sorts unknown dates last with stable UID tie-break',
    () {
      final date = DateTime(2026, 11, 11, 9, 30);
      final alice = Participant.fromMap('alice', {
        'displayName': 'Alice',
        'registeredAt': Timestamp.fromDate(date),
      });
      final bob = Participant(userId: 'bob', registeredAt: date);
      final unknown = Participant.fromMap('unknown', {});
      final list = [unknown, bob, alice]..sort(Participant.compare);
      expect(list, [alice, bob, unknown]);
      expect(alice.label, 'Alice');
      expect(alice.registeredAt, date);
    },
  );
}
