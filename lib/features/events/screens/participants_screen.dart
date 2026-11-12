import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ui/screen_components.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/event_bloc.dart';
import '../bloc/participants_cubit.dart';

class ParticipantsScreen extends StatelessWidget {
  final String eventId;
  const ParticipantsScreen({super.key, required this.eventId});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Participants')),
        body: const Center(child: Text('Please log in to view participants')),
      );
    }
    return BlocProvider(
      key: ValueKey('$eventId/${auth.userId}'),
      create: (_) => ParticipantsCubit(
        context.read<EventBloc>().repository,
        eventId,
        auth.userId,
      ),
      child: const _ParticipantsView(),
    );
  }
}

class _ParticipantsView extends StatelessWidget {
  const _ParticipantsView();
  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Participants')),
    body: ContentWidth(
      child: BlocBuilder<ParticipantsCubit, ParticipantsState>(
        builder: (context, state) {
          switch (state.status) {
            case ParticipantsStatus.loading:
              return const Center(
                child: StatusPanel.loading(title: 'Loading participants'),
              );
            case ParticipantsStatus.denied:
              return const Center(
                child: StatusPanel(
                  title: 'Only the organizer can view participants',
                  icon: Icons.lock_outline,
                ),
              );
            case ParticipantsStatus.missing:
              return const Center(
                child: StatusPanel(
                  title: 'Event no longer exists',
                  icon: Icons.event_busy_outlined,
                ),
              );
            case ParticipantsStatus.error:
              return Center(
                child: SingleChildScrollView(
                  child: StatusPanel(
                    title: 'Unable to load participants',
                    detail: state.error,
                    icon: Icons.error_outline,
                    onRetry: context.read<ParticipantsCubit>().reload,
                  ),
                ),
              );
            case ParticipantsStatus.ready:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${state.event!.title}\nParticipants: ${state.participants.length} / ${state.event!.capacity}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: state.participants.isEmpty
                        ? const Center(
                            child: StatusPanel(
                              title: 'No participants yet',
                              icon: Icons.people_outline,
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.participants.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final participant = state.participants[index];
                              return ListTile(
                                key: ValueKey(participant.userId),
                                leading: const Icon(Icons.person_outline),
                                title: Text(participant.label),
                                subtitle: Text(
                                  'ID: ${participant.userId}\nRegistered: ${participant.registeredAt == null ? 'Date unavailable' : _date(participant.registeredAt!)}',
                                ),
                                isThreeLine: true,
                              );
                            },
                          ),
                  ),
                ],
              );
          }
        },
      ),
    ),
  );
}
