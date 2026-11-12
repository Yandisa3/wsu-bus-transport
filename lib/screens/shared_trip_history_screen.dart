import 'package:flutter/material.dart';

import '../models/shared_trip.dart';
import '../models/user_profile.dart';
import '../services/shared_trip_service.dart';
import 'shared_boarding_screen.dart';

class SharedTripHistoryScreen extends StatefulWidget {
  final UserProfile profile;

  const SharedTripHistoryScreen({super.key, required this.profile});

  @override
  State<SharedTripHistoryScreen> createState() =>
      _SharedTripHistoryScreenState();
}

class _SharedTripHistoryScreenState extends State<SharedTripHistoryScreen> {
  final _service = SharedTripService();
  late Stream<List<SharedTrip>> _history;

  @override
  void initState() {
    super.initState();
    _history = _service.watchCompletedTrips();
  }

  void _retry() {
    setState(() {
      _history = _service.watchCompletedTrips();
    });
  }

  String _formatTime(DateTime? value) {
    if (value == null) return 'Unavailable';

    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);

    return '$date, $time';
  }

  bool _canViewBoardings(SharedTrip trip) {
    return widget.profile.role == UserRole.manager ||
        (widget.profile.role == UserRole.driver &&
            trip.driverUid == widget.profile.uid);
  }

  Widget _tripCard(SharedTrip trip) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trip.route, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Bus: ${trip.bus}'),
            Text('Driver: ${trip.driverName}'),
            const SizedBox(height: 8),
            Text('Started: ${_formatTime(trip.startedAt)}'),
            Text('Ended: ${_formatTime(trip.endedAt)}'),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.check_circle_outline, size: 18),
                label: Text('Completed'),
              ),
            ),
            if (_canViewBoardings(trip)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SharedBoardingScreen(
                        trip: trip,
                        profile: widget.profile,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people_outline),
                label: const Text('View passenger list'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completed bus trips')),
      body: StreamBuilder<List<SharedTrip>>(
        stream: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load trip history. Check your connection. '
                      'The history query may also need a Firestore index.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = snapshot.data!;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Recent bus operations',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The latest 50 completed trips. Use the bus, driver '
                    'and times to identify a trip when reporting a lost item.',
                  ),
                  const SizedBox(height: 20),
                  if (trips.isEmpty) const Text('No completed trips yet.'),
                  ...trips.map(_tripCard),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
