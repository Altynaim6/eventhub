import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/event_discovery_filters.dart';

/// Filters the existing live list without opening additional Firestore listeners.
class EventDiscoveryCubit extends Cubit<EventDiscoveryFilters> {
  EventDiscoveryCubit() : super(const EventDiscoveryFilters());
  void _update({
    String? query,
    String? category,
    bool replaceCategory = false,
    EventDateFilter? dateFilter,
    DateTime? start,
    DateTime? end,
    EventSort? sort,
  }) {
    emit(
      EventDiscoveryFilters(
        query: query ?? state.query,
        category: replaceCategory ? category : state.category,
        dateFilter: dateFilter ?? state.dateFilter,
        startDate: dateFilter == null ? state.startDate : start,
        endDate: dateFilter == null ? state.endDate : end,
        sort: sort ?? state.sort,
      ),
    );
  }

  void setQuery(String query) => _update(query: query);
  void setCategory(String? category) =>
      _update(category: category, replaceCategory: true);
  void setSort(EventSort sort) => _update(sort: sort);
  void setDateFilter(EventDateFilter filter) {
    if (filter == EventDateFilter.custom) return;
    _update(dateFilter: filter);
  }

  void setDateRange(DateTime start, DateTime end) {
    final first = start.toLocal();
    final last = end.toLocal();
    final from = DateTime(first.year, first.month, first.day);
    final to = DateTime(last.year, last.month, last.day);
    if (to.isBefore(from)) {
      throw ArgumentError('Date range end must not precede start');
    }
    _update(dateFilter: EventDateFilter.custom, start: from, end: to);
  }

  void reset() => emit(const EventDiscoveryFilters());
}
