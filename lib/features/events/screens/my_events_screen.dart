import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ui/screen_components.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_operation_bloc.dart';
import '../bloc/my_events_cubit.dart';
import '../models/event_model.dart';
import '../widgets/event_card.dart';
import 'event_details_screen.dart';

class MyEventsScreen extends StatelessWidget {
  const MyEventsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Events')),
        body: const Center(child: Text('Please log in to view your events')),
      );
    }
    return BlocProvider(
      key: ValueKey(auth.userId),
      create: (_) => MyEventsCubit(context.read<EventBloc>().repository),
      child: const _MyEventsView(),
    );
  }
}

class _MyEventsView extends StatelessWidget {
  const _MyEventsView();
  void _details(BuildContext context, EventModel event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              EventOperationBloc(context.read<EventBloc>().repository),
          child: EventDetailsScreen(event: event),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, EventModel event) async {
    final cubit = context.read<MyEventsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration?'),
        content: Text('Cancel your registration for "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Registration'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
    if (confirmed == true && !cubit.isClosed) await cubit.cancel(event.id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: BlocListener<MyEventsCubit, MyEventsState>(
        listenWhen: (previous, current) =>
            previous.noticeId != current.noticeId,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.notice!)));
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('My Events'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Created'),
                Tab(text: 'Registered'),
              ],
            ),
          ),
          body: ContentWidth(
            child: BlocBuilder<MyEventsCubit, MyEventsState>(
              builder: (context, state) => TabBarView(
                children: [
                  _list(context, state.created, state, true),
                  _list(context, state.registered, state, false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    MyEventList list,
    MyEventsState state,
    bool created,
  ) {
    if (list.loading) {
      return const Center(
        child: StatusPanel.loading(title: 'Loading your events'),
      );
    }
    if (list.error != null) {
      return Center(
        child: SingleChildScrollView(
          child: StatusPanel(
            title: 'Unable to load your events',
            icon: Icons.error_outline,
            detail: list.error,
            onRetry: context.read<MyEventsCubit>().reload,
          ),
        ),
      );
    }
    if (list.events.isEmpty) {
      return Center(
        child: StatusPanel(
          title: created
              ? 'You have not created any events yet'
              : 'You have no event registrations',
          icon: Icons.event_outlined,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.events.length,
      itemBuilder: (context, index) {
        final event = list.events[index];
        final busy = state.cancelling.contains(event.id);
        return Column(
          key: ValueKey('${created ? 'created' : 'registered'}/${event.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EventCard(event: event, onTap: () => _details(context, event)),
            if (created)
              OutlinedButton.icon(
                onPressed: () => _details(context, event),
                icon: const Icon(Icons.settings),
                label: const Text('Manage Event'),
              )
            else
              OutlinedButton.icon(
                onPressed: busy ? null : () => _cancel(context, event),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(busy ? 'Cancelling...' : 'Cancel Registration'),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
