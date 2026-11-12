import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ui/screen_components.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_operation_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import 'create_event_screen.dart';
import 'participants_screen.dart';
import '../widgets/event_registration_panel.dart';

import '../models/event_model.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late EventModel event = widget.event;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<EventModel>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) =>
              EventOperationBloc(context.read<EventBloc>().repository),
          child: CreateEventScreen(event: event),
        ),
      ),
    );
    if (mounted && updated != null) setState(() => event = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      context.read<EventOperationBloc>().add(DeleteEvent(event.id));
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final owner = auth is AuthAuthenticated && auth.userId == event.organizerId;
    final busy =
        context.watch<EventOperationBloc>().state is EventOperationInProgress;
    return BlocListener<EventOperationBloc, EventState>(
      listener: (context, state) {
        if (state is EventOperationSuccess) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
          Navigator.of(context).pop();
        } else if (state is EventError) {
          showErrorSnackBar(context, state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Event Details'),
          centerTitle: true,
          actions: owner
              ? [
                  IconButton(
                    tooltip: 'Participants',
                    onPressed: busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ParticipantsScreen(eventId: event.id),
                            ),
                          ),
                    icon: const Icon(Icons.people_outline),
                  ),
                  IconButton(
                    tooltip: 'Edit Event',
                    onPressed: busy ? null : _edit,
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Delete Event',
                    onPressed: busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]
              : null,
        ),

        body: ContentWidth(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event icon
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.event_available,
                    size: 90,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Event title
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Category
                Chip(
                  label: Text(event.category),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                ),

                const SizedBox(height: 28),

                // Date
                _buildInfoRow(
                  context,
                  Icons.calendar_month,
                  'Date & Time',
                  _formatDate(event.date),
                ),

                const SizedBox(height: 20),

                // Location
                _buildInfoRow(
                  context,
                  Icons.location_on_outlined,
                  'Location',
                  event.location,
                ),

                const SizedBox(height: 20),

                // Capacity
                _buildInfoRow(
                  context,
                  Icons.people_outline,
                  'Maximum Participants',
                  '${event.capacity} people',
                ),

                const SizedBox(height: 30),

                // Description
                const Text(
                  'About this Event',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Text(
                  event.description,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ContentWidth(
              maxWidth: 640,
              child: EventRegistrationPanel(eventId: event.id),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),

              const SizedBox(height: 5),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
