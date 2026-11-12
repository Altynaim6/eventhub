import 'dart:async';

import '../../../ui/screen_components.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../bloc/event_operation_bloc.dart';
import '../bloc/event_discovery_cubit.dart';
import '../models/event_discovery_filters.dart';
import '../models/event_model.dart';
import '../screens/event_details_screen.dart';
import 'event_card.dart';

class EventDiscoveryView extends StatelessWidget {
  const EventDiscoveryView({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => EventDiscoveryCubit(),
    child: const _DiscoveryContent(),
  );
}

class _DiscoveryContent extends StatefulWidget {
  const _DiscoveryContent();
  @override
  State<_DiscoveryContent> createState() => _DiscoveryContentState();
}

class _DiscoveryContentState extends State<_DiscoveryContent> {
  final _search = TextEditingController();
  late final Timer _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          context.read<EventDiscoveryCubit>().state.dateFilter !=
              EventDateFilter.all) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  Future<void> _selectRange(EventDiscoveryFilters filters) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      initialDateRange: filters.startDate != null && filters.endDate != null
          ? DateTimeRange(start: filters.startDate!, end: filters.endDate!)
          : null,
      currentDate: now,
    );
    if (mounted && range != null) {
      context.read<EventDiscoveryCubit>().setDateRange(range.start, range.end);
    }
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,

      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<EventDiscoveryCubit, EventDiscoveryFilters>(
    listener: (context, filters) {
      if (_search.text != filters.query) _search.text = filters.query;
    },
    builder: (context, filters) => BlocBuilder<EventBloc, EventState>(
      builder: (context, state) {
        final cubit = context.read<EventDiscoveryCubit>();
        final all = state is EventLoaded ? state.events : const <EventModel>[];
        final visible = filters.apply(all);
        final categories = <String>{
          'Technology',
          'Education',
          'Business',
          'Culture',
          'Sports',
          'Other',
          ...all.map((event) => event.category),
          ?filters.category,
        }.toList()..sort();
        final category = _dropdown<String>('Category', filters.category ?? '', [
          const DropdownMenuItem(value: '', child: Text('All categories')),
          ...categories
              .where((c) => c.isNotEmpty)
              .map((c) => DropdownMenuItem(value: c, child: Text(c))),
        ], (value) => cubit.setCategory(value == '' ? null : value));
        final date = _dropdown<EventDateFilter>(
          'Date',
          filters.dateFilter,
          const [
            DropdownMenuItem(
              value: EventDateFilter.all,
              child: Text('All dates'),
            ),
            DropdownMenuItem(
              value: EventDateFilter.upcoming,
              child: Text('Upcoming'),
            ),
            DropdownMenuItem(
              value: EventDateFilter.today,
              child: Text('Today'),
            ),
            DropdownMenuItem(
              value: EventDateFilter.nextSevenDays,
              child: Text('Next 7 days'),
            ),
            DropdownMenuItem(
              value: EventDateFilter.custom,
              child: Text('Custom range'),
            ),
          ],
          (value) {
            if (value == EventDateFilter.custom) {
              _selectRange(filters);
            } else if (value != null) {
              cubit.setDateFilter(value);
            }
          },
        );
        final sort = _dropdown<EventSort>(
          'Sort by',
          filters.sort,
          const [
            DropdownMenuItem(
              value: EventSort.dateAscending,
              child: Text('Date: earliest first'),
            ),
            DropdownMenuItem(
              value: EventSort.dateDescending,
              child: Text('Date: latest first'),
            ),
            DropdownMenuItem(value: EventSort.title, child: Text('Title: A–Z')),
            DropdownMenuItem(
              value: EventSort.availablePlaces,
              child: Text('Most places available'),
            ),
          ],
          (value) {
            if (value != null) cubit.setSort(value);
          },
        );
        Widget? message;
        if (state is EventError) {
          message = StatusPanel(
            title: 'Unable to load events',
            icon: Icons.error_outline,
            detail: state.message,
            onRetry: () => context.read<EventBloc>().add(const LoadEvents()),
          );
        } else if (state is! EventLoaded) {
          message = const StatusPanel.loading(title: 'Loading events');
        } else if (all.isEmpty) {
          message = const StatusPanel(
            title: 'No events yet',
            icon: Icons.event_outlined,
          );
        } else if (visible.isEmpty) {
          message = const StatusPanel(
            title: 'No events match your search and filters',
            icon: Icons.search_off,
          );
        }
        return ContentWidth(
          child: CustomScrollView(
            key: const PageStorageKey('discovery'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Discover Events',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        onChanged: cubit.setQuery,
                        decoration: InputDecoration(
                          labelText: 'Search title or location',
                          prefixIcon: const Icon(Icons.search),

                          suffixIcon: filters.query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => cubit.setQuery(''),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 650) {
                            return Row(
                              children: [
                                Expanded(child: category),
                                const SizedBox(width: 12),
                                Expanded(child: date),
                                const SizedBox(width: 12),
                                Expanded(child: sort),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              category,
                              const SizedBox(height: 12),
                              date,
                              const SizedBox(height: 12),
                              sort,
                            ],
                          );
                        },
                      ),
                      if (filters.dateFilter == EventDateFilter.custom &&
                          filters.startDate != null &&
                          filters.endDate != null)
                        TextButton.icon(
                          onPressed: () => _selectRange(filters),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            '${_date(filters.startDate!)} – ${_date(filters.endDate!)}',
                          ),
                        ),
                      if (!filters.isDefault)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: cubit.reset,
                            icon: const Icon(Icons.filter_alt_off),
                            label: const Text('Reset filters'),
                          ),
                        ),
                      if (state is EventLoaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('${visible.length} events found'),
                        ),
                    ],
                  ),
                ),
              ),
              if (message != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: message),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final event = visible[index];
                      return EventCard(
                        key: ValueKey(event.id),
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider(
                              create: (_) => EventOperationBloc(
                                context.read<EventBloc>().repository,
                              ),
                              child: EventDetailsScreen(event: event),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
