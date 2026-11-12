import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/models/event_model.dart';

void main() {
  test(
    'legacy documents have zero participants and all capacity available',
    () {
      final values = <String, dynamic>{
        'title': 'Title',
        'description': 'Description',
        'category': 'Other',
        'location': 'Bishkek',
        'date': Timestamp.fromDate(DateTime(2030)),
        'capacity': 5,
        'organizerId': 'owner',
      };
      final legacy = EventModel.fromMap('legacy', values);
      expect(legacy.registeredCount, 0);
      expect(legacy.availablePlaces, 5);
      final populated = EventModel.fromMap('populated', {
        ...values,
        'registeredCount': 3,
      });
      expect(populated.availablePlaces, 2);
      expect(populated.toFirestore()['registeredCount'], 3);
    },
  );
}
