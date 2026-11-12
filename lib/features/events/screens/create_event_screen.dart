import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

import '../../../ui/screen_components.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/event_operation_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../models/event_model.dart';

class CreateEventScreen extends StatefulWidget {
  final EventModel? event;

  final VoidCallback? onCreated;

  const CreateEventScreen({super.key, this.event, this.onCreated});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();

  final List<String> _categories = [
    'Technology',
    'Education',
    'Business',
    'Culture',
    'Sports',
    'Other',
  ];

  String _selectedCategory = 'Technology';
  DateTime? _selectedDate;

  bool get _editing => widget.event != null;
  EventModel? _submitted;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event == null) return;
    _titleController.text = event.title;
    _descriptionController.text = event.description;
    _locationController.text = event.location;
    _capacityController.text = event.capacity.toString();
    _selectedCategory = event.category;
    if (!_categories.contains(event.category)) _categories.add(event.category);
    _selectedDate = event.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _createEvent() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event date and time')),
      );
      return;
    }

    if (!_selectedDate!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event date must be in the future')),
      );
      return;
    }

    final auth = context.read<AuthBloc>().state;

    if (auth is! AuthAuthenticated) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    if (_editing && widget.event!.organizerId != auth.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own events')),
      );
      return;
    }

    final event = EventModel(
      id: widget.event?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      date: _selectedDate!,
      location: _locationController.text.trim(),
      capacity: int.parse(_capacityController.text.trim()),
      organizerId: widget.event?.organizerId ?? auth.userId,
      createdAt: widget.event?.createdAt,
      registeredCount: widget.event?.registeredCount ?? 0,
    );

    _submitted = event;
    context.read<EventOperationBloc>().add(
      _editing ? UpdateEvent(event) : CreateEvent(event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Event' : 'Create Event'),
        centerTitle: true,
      ),
      body: BlocListener<EventOperationBloc, EventState>(
        listener: (context, state) {
          if (state is EventOperationSuccess) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));

            final onCreated = widget.onCreated;
            if (onCreated != null && !_editing) {
              onCreated();
            } else {
              Navigator.of(context).pop(_submitted);
            }
          }

          if (state is EventError) {
            showErrorSnackBar(context, state.message);
          }
        },
        child: ContentWidth(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter event title';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter description';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: _selectDateTime,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date & Time'
                          : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year} '
                                '${_selectedDate!.hour.toString().padLeft(2, '0')}:'
                                '${_selectedDate!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter location';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Participants',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    validator: (value) {
                      final capacity = int.tryParse(value?.trim() ?? '');

                      if (capacity == null || capacity <= 0) {
                        return 'Enter a valid number greater than 0';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 28),

                  BlocBuilder<EventOperationBloc, EventState>(
                    builder: (context, state) {
                      final isLoading = state is EventOperationInProgress;

                      return ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : _createEvent,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                            isLoading
                                ? 'Saving...'
                                : (_editing ? 'Save Changes' : 'Create Event'),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
