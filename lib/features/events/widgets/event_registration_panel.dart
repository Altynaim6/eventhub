import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/event_bloc.dart';
import '../bloc/registration_cubit.dart';

class EventRegistrationPanel extends StatelessWidget {
  final String eventId;
  const EventRegistrationPanel({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      return const Text('Please log in to register');
    }
    return BlocProvider(
      key: ValueKey('$eventId/${auth.userId}'),
      create: (_) =>
          RegistrationCubit(context.read<EventBloc>().repository, eventId),
      child: BlocBuilder<RegistrationCubit, RegistrationState>(
        builder: (context, state) {
          final event = state.event;
          final ready = !state.loading && state.registered != null;
          final registered = state.registered == true;
          final closed = event != null && !event.date.isAfter(DateTime.now());
          final full = event != null && event.availablePlaces == 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.error != null)
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              if (event != null)
                Text(
                  '${event.availablePlaces} places available • ${event.registeredCount} registered',
                ),
              if (ready && event == null && state.error == null)
                const Text('Event no longer exists'),
              if (registered) const Text('You are registered'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      !ready ||
                          state.busy ||
                          event == null ||
                          (!registered && (full || closed))
                      ? null
                      : () => context.read<RegistrationCubit>().setRegistered(
                          !registered,
                        ),
                  icon: const Icon(Icons.how_to_reg),
                  label: Text(
                    state.busy
                        ? 'Saving...'
                        : !ready
                        ? 'Loading registration...'
                        : registered
                        ? 'Cancel Registration'
                        : closed
                        ? 'Registration Closed'
                        : full
                        ? 'Event Full'
                        : 'Register for Event',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
