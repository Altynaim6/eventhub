import 'package:equatable/equatable.dart';

import 'event_model.dart';

enum EventSort { dateAscending, dateDescending, title, availablePlaces }

enum EventDateFilter { all, upcoming, today, nextSevenDays, custom }

class EventDiscoveryFilters extends Equatable {
  final String query;
  final String? category;
  final EventDateFilter dateFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final EventSort sort;
  const EventDiscoveryFilters({
    this.query = '',
    this.category,
    this.dateFilter = EventDateFilter.all,
    this.startDate,
    this.endDate,
    this.sort = EventSort.dateAscending,
  });

  bool get isDefault =>
      query.isEmpty &&
      category == null &&
      dateFilter == EventDateFilter.all &&
      sort == EventSort.dateAscending;

  List<EventModel> apply(Iterable<EventModel> source, {DateTime? now}) {
    final clock = (now ?? DateTime.now()).toLocal();
    DateTime day(DateTime date) {
      final local = date.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    DateTime afterDays(DateTime date, int days) =>
        DateTime(date.year, date.month, date.day + days);
    final today = day(clock);
    final start = switch (dateFilter) {
      EventDateFilter.all => null,
      EventDateFilter.upcoming => clock,
      EventDateFilter.today || EventDateFilter.nextSevenDays => today,
      EventDateFilter.custom => startDate == null ? null : day(startDate!),
    };
    final end = switch (dateFilter) {
      EventDateFilter.today => afterDays(today, 1),
      EventDateFilter.nextSevenDays => afterDays(today, 7),
      EventDateFilter.custom =>
        endDate == null ? null : afterDays(day(endDate!), 1),
      _ => null,
    };
    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final events = source.where((event) {
      final title = event.title.toLowerCase();
      final location = event.location.toLowerCase();
      return words.every(
            (word) => title.contains(word) || location.contains(word),
          ) &&
          (category == null || event.category == category) &&
          (start == null || !event.date.isBefore(start)) &&
          (end == null || event.date.isBefore(end));
    }).toList();
    events.sort((a, b) {
      final primary = switch (sort) {
        EventSort.dateAscending => a.date.compareTo(b.date),
        EventSort.dateDescending => b.date.compareTo(a.date),
        EventSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        EventSort.availablePlaces => b.availablePlaces.compareTo(
          a.availablePlaces,
        ),
      };
      if (primary != 0) return primary;
      final date = a.date.compareTo(b.date);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return List.unmodifiable(events);
  }

  @override
  List<Object?> get props => [
    query,
    category,
    dateFilter,
    startDate,
    endDate,
    sort,
  ];
}
