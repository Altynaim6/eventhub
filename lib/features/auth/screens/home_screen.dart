import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ui/screen_components.dart';
import '../../events/bloc/event_bloc.dart';
import '../../events/bloc/event_operation_bloc.dart';
import '../../events/bloc/event_event.dart';

import '../../events/screens/create_event_screen.dart';
import '../../events/screens/my_events_screen.dart';
import '../../events/widgets/event_discovery_view.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selected = 0;
  int _createVersion = 0;
  final _visited = {0};

  @override
  void initState() {
    super.initState();

    context.read<EventBloc>().add(const LoadEvents());
  }

  void _select(int index) {
    if (_selected == index) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = index;
      _visited.add(index);
    });
  }

  void _onCreated() {
    final wasCreating = _selected == 2;
    setState(() => _createVersion++);
    if (wasCreating) _select(0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      Scaffold(
        appBar: AppBar(title: const Text('EventHub')),
        body: const EventDiscoveryView(),
      ),
      const MyEventsScreen(),
      BlocProvider(
        key: ValueKey(_createVersion),
        create: (context) =>
            EventOperationBloc(context.read<EventBloc>().repository),
        child: CreateEventScreen(onCreated: _onCreated),
      ),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: _selected == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _selected,
          children: [
            for (var index = 0; index < pages.length; index++)
              if (_visited.contains(index))
                TickerMode(enabled: index == _selected, child: pages[index])
              else
                const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: ContentWidth(
            child: NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note),
                  label: 'My Events',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Create Event',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
