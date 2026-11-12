import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/models/event_discovery_filters.dart';

import 'support/discovery_events.dart';

void main() {
  test('case-insensitive substring and multiword search matches title or location including Cyrillic', () {
    final source = [
      discoveryEvent('1', title: 'Илим күнү', location: 'БИШКЕК'),
      discoveryEvent('2', title: 'Музыка', location: 'Ош'),
    ];
    expect(
      const EventDiscoveryFilters(query: '  ИЛИМ   Бишкек ')
          .apply(source)
          .map((e) => e.id),
      ['1'],
    );
    expect(
      const EventDiscoveryFilters(query: 'КҮНҮ').apply(source).map((e) => e.id),
      ['1'],
    );
    expect(
      const EventDiscoveryFilters(query: 'ош').apply(source).map((e) => e.id),
      ['2'],
    );
    expect(const EventDiscoveryFilters(query: '').apply(source), hasLength(2));
    expect(
      const EventDiscoveryFilters(query: 'unknown').apply(source),
      isEmpty,
    );
  });
  test('query, category and date combine without mutating source', () {
    final source = [
      discoveryEvent('1'),
      discoveryEvent('2', category: 'Music'),
      discoveryEvent('3', location: 'Osh'),
    ];
    final filters = EventDiscoveryFilters(
      query: 'Bishkek',
      category: 'Education',
      dateFilter: EventDateFilter.custom,
      startDate: DateTime(2030, 6, 10),
      endDate: DateTime(2030, 6, 10),
    );
    expect(filters.apply(source).map((e) => e.id), ['1']);
    expect(source.map((e) => e.id), ['1', '2', '3']);
    expect(() => filters.apply(source).clear(), throwsUnsupportedError);
  });
  test('today includes local day boundaries and excludes next midnight', () {
    final now = DateTime(2030, 6, 10, 14);
    final source = [
      discoveryEvent('start', date: DateTime(2030, 6, 10)),
      discoveryEvent('end', date: DateTime(2030, 6, 10, 23, 59, 59, 999, 999)),
      discoveryEvent('before', date: DateTime(2030, 6, 9, 23, 59)),
      discoveryEvent('after', date: DateTime(2030, 6, 11)),
    ];
    expect(
      const EventDiscoveryFilters(dateFilter: EventDateFilter.today)
          .apply(source, now: now)
          .map((e) => e.id),
      ['start', 'end'],
    );
  });
  test(
    'upcoming compares instants, next seven days includes today plus six days',
    () {
      final now = DateTime(2030, 6, 10, 14);
      final source = [
        discoveryEvent('past', date: DateTime(2030, 6, 10, 13)),
        discoveryEvent('now', date: now.toUtc()),
        discoveryEvent('six', date: DateTime(2030, 6, 16, 23, 59)),
        discoveryEvent('seven', date: DateTime(2030, 6, 17)),
      ];
      expect(
        const EventDiscoveryFilters(dateFilter: EventDateFilter.upcoming)
            .apply(source, now: now)
            .map((e) => e.id),
        ['now', 'six', 'seven'],
      );
      expect(
        const EventDiscoveryFilters(dateFilter: EventDateFilter.nextSevenDays)
            .apply(source, now: now)
            .map((e) => e.id),
        ['past', 'now', 'six'],
      );
    },
  );
  test('custom range includes entire final day and works across month/year boundary', () {
    final source = [
      discoveryEvent('1', date: DateTime(2030, 12, 31)),
      discoveryEvent('2', date: DateTime(2031, 1, 1, 23, 59, 59)),
      discoveryEvent('3', date: DateTime(2031, 1, 2)),
    ];
    expect(
      EventDiscoveryFilters(
        dateFilter: EventDateFilter.custom,
        startDate: DateTime(2030, 12, 31),
        endDate: DateTime(2031, 1, 1),
      ).apply(source).map((e) => e.id),
      ['1', '2'],
    );
  });
  test('all sort modes are deterministic with stable UID tie-breaks', () {
    final source = [
      discoveryEvent('b', title: 'Beta', capacity: 20, count: 1),
      discoveryEvent('a', title: 'Alpha', date: DateTime(2030, 6, 9)),
      discoveryEvent('c', title: 'Beta', capacity: 20, count: 1),
    ];
    expect(const EventDiscoveryFilters().apply(source).map((e) => e.id), [
      'a',
      'b',
      'c',
    ]);
    expect(
      const EventDiscoveryFilters(sort: EventSort.dateDescending)
          .apply(source)
          .map((e) => e.id),
      ['b', 'c', 'a'],
    );
    expect(
      const EventDiscoveryFilters(sort: EventSort.title)
          .apply(source)
          .map((e) => e.id),
      ['a', 'b', 'c'],
    );
    expect(
      const EventDiscoveryFilters(sort: EventSort.availablePlaces)
          .apply(source)
          .map((e) => e.id),
      ['b', 'c', 'a'],
    );
  });
}
