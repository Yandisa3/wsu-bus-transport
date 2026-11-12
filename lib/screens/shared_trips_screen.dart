import 'package:flutter/material.dart';

import 'trip_map_screen.dart';
import '../models/shared_trip.dart';
import '../models/user_profile.dart';
import '../services/shared_trip_service.dart';
import 'shared_boarding_screen.dart';
import 'shared_trip_history_screen.dart';

class SharedTripsScreen extends StatefulWidget {
  final UserProfile profile;

  const SharedTripsScreen({super.key, required this.profile});

  @override
  State<SharedTripsScreen> createState() => _SharedTripsScreenState();
}

class _SharedTripsScreenState extends State<SharedTripsScreen> {
  final _service = SharedTripService();
  final _formKey = GlobalKey<FormState>();
  final _bus = TextEditingController();
  final _route = TextEditingController();
  final _capacity = TextEditingController(text: '60');

  late final Stream<List<SharedTrip>> _trips;
  bool _busy = false;
  String? _error;
  String? _pendingTripId;

  bool get _isDriver => widget.profile.role == UserRole.driver;

  @override
  void initState() {
    super.initState();
    _trips = _service.watchActiveTrips();
  }

  @override
  void dispose() {
    _capacity.dispose();
    _bus.dispose();
    _route.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    // Keep the same ID if the user needs to retry.
    _pendingTripId ??= _service.newTripId();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _service.startTrip(
        tripId: _pendingTripId!,
        bus: _bus.text,
        route: _route.text,
        capacity: int.parse(_capacity.text.trim()),
      );

      if (!mounted) return;

      _pendingTripId = null;
      _bus.clear();

      _route.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip shared successfully.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is StateError
              ? error.message.toString()
              : 'Could not confirm the trip was started. '
                    'Check your connection and retry with the same details.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end(SharedTrip trip) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this trip?'),
        content: Text(
          '${trip.bus} will disappear from the active-trip list. '
          'The completed trip will remain saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _service.endTrip(trip.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not confirm the trip was ended. '
              'Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _startForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Start your trip',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bus,
                readOnly: _busy || _pendingTripId != null,
                maxLength: 30,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Bus name or registration',
                  hintText: 'Bus 01',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.isEmpty || text.length > 30
                      ? 'Enter 1–30 characters.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _route,
                readOnly: _busy || _pendingTripId != null,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Route',
                  hintText: 'Residence to campus',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.isEmpty || text.length > 80
                      ? 'Enter 1–80 characters.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                readOnly: _busy || _pendingTripId != null,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Boarding limit',
                  helperText: 'Maximum accepted boardings for this trip.',
                ),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');

                  if (number == null || number < 1 || number > 100) {
                    return 'Enter a number from 1 to 100.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _busy
                      ? 'Please wait...'
                      : _pendingTripId != null
                      ? 'Retry starting trip'
                      : 'Start trip',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripCard(SharedTrip trip) {
    final ownedByDriver = _isDriver && trip.driverUid == widget.profile.uid;

    final start = trip.startedAt;
    final startLabel = start == null
        ? 'Confirming start time...'
        : 'Started ${TimeOfDay.fromDateTime(start.toLocal()).format(context)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.route, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Bus: ${trip.bus}'),
            Text('Driver: ${trip.driverName}'),
            Text(
              trip.capacity == null
                  ? 'Older trip: boarding limit not configured'
                  : 'Boarding limit: ${trip.capacity}',
            ),
            Text(startLabel),
            const SizedBox(height: 12),
            const Chip(
              avatar: Icon(Icons.directions_bus_outlined, size: 18),
              label: Text('Trip in progress'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TripMapScreen(trip: trip),
                        ),
                      );
                    },
              icon: const Icon(Icons.map_outlined),
              label: Text(ownedByDriver ? 'Location sharing' : 'Track bus'),
            ),
            if (ownedByDriver || widget.profile.role == UserRole.manager) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
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
                label: Text(
                  ownedByDriver ? 'Board students' : 'Passenger list',
                ),
              ),
            ],
            if (ownedByDriver) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _end(trip),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End trip'),
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
      appBar: AppBar(
        title: Text(_isDriver ? 'My trip' : 'Active bus trips'),
        actions: [
          IconButton(
            tooltip: 'Completed trips',
            icon: const Icon(Icons.history),
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SharedTripHistoryScreen(profile: widget.profile),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: StreamBuilder<List<SharedTrip>>(
        stream: _trips,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load shared trips. Check your connection '
                  'and account permissions, then reopen this page.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trips = _isDriver
              ? snapshot.data!
                    .where((trip) => trip.driverUid == widget.profile.uid)
                    .toList()
              : snapshot.data!;
          final hasOwnTrip = trips.any(
            (trip) => trip.driverUid == widget.profile.uid,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _isDriver
                        ? 'Your trip controls'
                        : 'See which buses are operating',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trip details and accepted boarding records are shared across accounts. '
                    'Open a trip to track its bus or review boarding.',
                  ),
                  const SizedBox(height: 20),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isDriver && !hasOwnTrip) _startForm(),
                  if (trips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No active trips at the moment.'),
                    ),
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
