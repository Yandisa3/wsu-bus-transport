import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/shared_trip.dart';
import '../models/user_profile.dart';
import '../screens/shared_boarding_screen.dart';
import '../screens/shared_trip_history_screen.dart';
import '../screens/shared_trips_screen.dart';
import '../screens/trip_map_screen.dart';
import '../services/shared_trip_service.dart';
import 'portal_shell.dart';

class SharedManagerOverview extends StatefulWidget {
  final UserProfile profile;
  final bool signingOut;

  const SharedManagerOverview({
    super.key,
    required this.profile,
    required this.signingOut,
  });

  @override
  State<SharedManagerOverview> createState() => _SharedManagerOverviewState();
}

class _SharedManagerOverviewState extends State<SharedManagerOverview> {
  final _service = SharedTripService();
  late Stream<List<SharedTrip>> _activeTrips;

  @override
  void initState() {
    super.initState();
    _activeTrips = _service.watchActiveTrips();
  }

  void _open(Widget screen) {
    if (widget.signingOut) return;

    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PortalHeading(
          eyebrow: 'Transport operations',
          title: 'Fleet overview',
          subtitle: 'Monitor active buses, drivers and boarding records.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: widget.signingOut
                  ? null
                  : () => _open(SharedTripsScreen(profile: widget.profile)),
              icon: const Icon(Icons.directions_bus_outlined),
              label: const Text('Active trips'),
            ),
            OutlinedButton.icon(
              onPressed: widget.signingOut
                  ? null
                  : () =>
                        _open(SharedTripHistoryScreen(profile: widget.profile)),
              icon: const Icon(Icons.history),
              label: const Text('Completed trips'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<SharedTrip>>(
          stream: _activeTrips,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.error is FirebaseException
                        ? 'Unable to load trips: '
                              '${(snapshot.error as FirebaseException).code}. '
                              'Check your connection and account permissions.'
                        : 'Unable to read trip records. '
                              'A record may contain invalid information.',
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _activeTrips = _service.watchActiveTrips();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final trips = snapshot.data!;
            final drivers = trips.map((trip) => trip.driverUid).toSet();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricGrid(
                  items: [
                    PortalMetric(
                      'Active trips',
                      '${trips.length}',
                      Icons.route_outlined,
                    ),
                    PortalMetric(
                      'Drivers on these trips',
                      '${drivers.length}',
                      Icons.person_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Trip status does not guarantee a recent GPS update. '
                  'Open the map to check location freshness.',
                ),
                const SizedBox(height: 16),
                if (trips.isEmpty)
                  const EmptyPanel(
                    title: 'No active trips',
                    message: 'New driver trips will appear here.',
                    icon: Icons.directions_bus_outlined,
                  ),
                ...trips.map(
                  (trip) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            trip.route,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('Bus: ${trip.bus}'),
                          Text('Driver: ${trip.driverName}'),
                          const SizedBox(height: 12),
                          _SharedTripCounter(
                            key: ValueKey(trip.id),
                            trip: trip,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: widget.signingOut
                                    ? null
                                    : () => _open(TripMapScreen(trip: trip)),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('View map'),
                              ),
                              OutlinedButton.icon(
                                onPressed: widget.signingOut
                                    ? null
                                    : () => _open(
                                        SharedBoardingScreen(
                                          trip: trip,
                                          profile: widget.profile,
                                        ),
                                      ),
                                icon: const Icon(Icons.people_outline),
                                label: const Text('Boarding records'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Boarding eligibility still uses sample students. '
          'Counts represent accepted boardings, not current occupancy.',
        ),
      ],
    );
  }
}

class _SharedTripCounter extends StatefulWidget {
  final SharedTrip trip;

  const _SharedTripCounter({super.key, required this.trip});

  @override
  State<_SharedTripCounter> createState() => _SharedTripCounterState();
}

class _SharedTripCounterState extends State<_SharedTripCounter> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _counter;

  @override
  void initState() {
    super.initState();

    _counter = FirebaseFirestore.instance
        .collection('shared_trips')
        .doc(widget.trip.id)
        .collection('boarding_state')
        .doc('current')
        .snapshots(includeMetadataChanges: true);
  }

  @override
  Widget build(BuildContext context) {
    final capacity = widget.trip.capacity;

    if (capacity == null) {
      return const Text(
        'Older trip: no capacity counter. Open its boarding records.',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _counter,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Boarding count unavailable.');
        }

        if (!snapshot.hasData) {
          return const Text('Loading boarding count...');
        }

        final document = snapshot.data!;
        final cached = document.metadata.isFromCache;
        final pending = document.metadata.hasPendingWrites;

        if (!document.exists && cached) {
          return const Text('Waiting for the server boarding count.');
        }
        final data = document.data();
        final Object? count;

        if (!document.exists) {
          count = 0;
        } else if (data == null) {
          count = null;
        } else {
          count = data['count'];
        }

        if (count is! int || count < 0 || count > capacity) {
          return const Text(
            'Invalid boarding counter. Administrator review is needed.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accepted boardings: $count / $capacity'),
            Text('Boarding places remaining: ${capacity - count}'),
            if (cached || pending)
              const Text('Cached or pending count; awaiting confirmation.'),
          ],
        );
      },
    );
  }
}
