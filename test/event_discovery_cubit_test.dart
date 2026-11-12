import 'package:flutter_test/flutter_test.dart';
import 'package:eventhub/features/events/bloc/event_discovery_cubit.dart';
import 'package:eventhub/features/events/models/event_discovery_filters.dart';

void main() {
  test(
    'filter changes preserve other criteria and reset clears everything',
    () async {
      final cubit = EventDiscoveryCubit();
      cubit.setDateRange(DateTime(2030, 6, 10), DateTime(2030, 6, 11));
      cubit.setQuery('Campus');
      cubit.setCategory('Education');
      cubit.setSort(EventSort.title);
      expect(cubit.state.startDate, DateTime(2030, 6, 10));
      expect(cubit.state.endDate, DateTime(2030, 6, 11));
      expect(cubit.state.query, 'Campus');
      expect(cubit.state.isDefault, false);
      cubit.setDateFilter(EventDateFilter.today);
      expect(cubit.state.startDate, isNull);
      expect(cubit.state.query, 'Campus');
      cubit.setCategory(null);
      expect(cubit.state.category, isNull);
      cubit.reset();
      expect(cubit.state, const EventDiscoveryFilters());
      await cubit.close();
    },
  );
  test('invalid custom range is rejected without changing state', () async {
    final cubit = EventDiscoveryCubit();
    expect(
      () => cubit.setDateRange(DateTime(2030, 6, 11), DateTime(2030, 6, 10)),
      throwsArgumentError,
    );
    expect(cubit.state, const EventDiscoveryFilters());
    cubit.setDateFilter(EventDateFilter.custom);
    expect(cubit.state, const EventDiscoveryFilters());
    await cubit.close();
  });
}
