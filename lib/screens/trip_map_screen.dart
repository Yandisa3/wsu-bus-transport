import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shared_trip.dart';
import '../services/trip_location_service.dart';

class TripMapScreen extends StatefulWidget {
  final SharedTrip trip;

  const TripMapScreen({super.key, required this.trip});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen>
    with WidgetsBindingObserver {
  final _service = TripLocationService();
  final _mapController = MapController();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _tripStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _locationStream;

  Timer? _publisher;
  Timer? _clock;

  bool _sharing = false;
  bool _starting = false;
  bool _sending = false;
  int _generation = 0;
  String? _message;

  bool get _isTripDriver =>
      FirebaseAuth.instance.currentUser?.uid == widget.trip.driverUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tripStream = _service
        .tripRef(widget.trip.id)
        .snapshots(includeMetadataChanges: true);

    _locationStream = _service
        .locationRef(widget.trip.id)
        .snapshots(includeMetadataChanges: true);

    // Refresh the displayed age even when no new GPS update arrives.
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _stopSharing();
    }
  }

  void _stopSharing() {
    _generation++;
    _publisher?.cancel();
    _publisher = null;

    if (mounted) {
      setState(() => _sharing = false);
    }
  }

  Future<void> _startSharing() async {
    if (_starting || _sharing || !_isTripDriver) return;

    final generation = ++_generation;

    setState(() {
      _starting = true;
      _message = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on your device location, then try again.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw StateError(
          'Allow location access in your browser or device settings.',
        );
      }

      if (!mounted || generation != _generation) return;

      setState(() => _sharing = true);

      _publisher = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_publishPosition());
      });

      unawaited(_publishPosition());
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is StateError
              ? error.message.toString()
              : 'Unable to start location sharing. Check location permissions.';
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _publishPosition() async {
    if (!_sharing || _sending) return;

    final generation = _generation;
    _sending = true;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!mounted || !_sharing || generation != _generation) return;

      await _service.publish(widget.trip.id, position);

      if (mounted && generation == _generation) {
        setState(() => _message = null);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        _stopSharing();

        setState(() {
          _message =
              'Location sharing stopped. Check GPS, internet and '
              'that this trip is still active, then start sharing again.';
        });
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _openCredits() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
      );

      if (!opened) throw StateError('Could not open link.');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map credits: openstreetmap.org/copyright'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sharing = false;
    _generation++;
    _publisher?.cancel();
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  Widget _statusPage(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.trip.bus} location')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _tripStream,
        builder: (context, tripSnapshot) {
          if (tripSnapshot.hasError) {
            return _statusPage(
              'Unable to check this trip. Reopen the page when connected.',
            );
          }

          if (!tripSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tripData = tripSnapshot.data!.data();

          if (tripData == null || tripData['status'] != 'active') {
            return _statusPage(
              'This trip is no longer active. Return to the trip list.',
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _locationStream,
            builder: (context, locationSnapshot) {
              final document = locationSnapshot.data;
              final data = locationSnapshot.hasError ? null : document?.data();

              final latitude = (data?['latitude'] as num?)?.toDouble();
              final longitude = (data?['longitude'] as num?)?.toDouble();
              final accuracy = (data?['accuracy'] as num?)?.toDouble();
              final sampledAt = (data?['sampledAt'] as Timestamp?)?.toDate();
              final updatedAt = (data?['updatedAt'] as Timestamp?)?.toDate();

              final point = latitude == null || longitude == null
                  ? null
                  : LatLng(latitude, longitude);

              final now = DateTime.now();
              final sampleAge = sampledAt == null
                  ? null
                  : now.difference(sampledAt).inSeconds;
              final updateAge = updatedAt == null
                  ? null
                  : now.difference(updatedAt).inSeconds;

              final cached = document?.metadata.isFromCache ?? true;
              final pending = document?.metadata.hasPendingWrites ?? false;
              final tripCached = tripSnapshot.data!.metadata.isFromCache;

              final recent =
                  point != null &&
                  !cached &&
                  !pending &&
                  !tripCached &&
                  sampleAge != null &&
                  sampleAge >= -30 &&
                  sampleAge <= 60 &&
                  updateAge != null &&
                  updateAge >= -30 &&
                  updateAge <= 60;

              final status = locationSnapshot.hasError
                  ? 'Unable to read the driver location.'
                  : point == null
                  ? 'Waiting for the driver to share location.'
                  : cached || tripCached
                  ? 'Cached location — reconnect to check for updates.'
                  : pending
                  ? 'Confirming location update...'
                  : recent
                  ? 'Recent position — received '
                        '${updateAge < 0 ? 0 : updateAge}s ago.'
                  : 'Old or unconfirmed position — '
                        'the bus may have moved.';

              return SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.trip.route,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text('Driver: ${widget.trip.driverName}'),
                          const SizedBox(height: 8),
                          Text(status),
                          if (accuracy != null)
                            Text(
                              'Device-reported accuracy: '
                              'approximately ${accuracy.round()} m',
                            ),
                          if (_isTripDriver) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _starting
                                  ? null
                                  : _sharing
                                  ? _stopSharing
                                  : _startSharing,
                              icon: Icon(
                                _sharing
                                    ? Icons.location_off
                                    : Icons.my_location,
                              ),
                              label: Text(
                                _starting
                                    ? 'Checking permission...'
                                    : _sharing
                                    ? 'Stop sharing'
                                    : 'Share my location',
                              ),
                            ),
                            const Text(
                              'Shares this device location with transport '
                              'users. Keep this page open and the app in '
                              'the foreground.',
                            ),
                          ],
                          if (_message != null)
                            Text(
                              _message!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: LatLng(-33.0153, 27.9116),
                          initialZoom: 12,
                          minZoom: 3,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.bus_transport_app',
                          ),
                          if (point != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: point,
                                  width: 52,
                                  height: 52,
                                  child: Tooltip(
                                    message: recent
                                        ? 'Recently reported bus position'
                                        : 'Last reported position',
                                    child: Icon(
                                      Icons.directions_bus,
                                      size: 42,
                                      color: recent ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: _openCredits,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: OutlinedButton.icon(
                        onPressed: point == null
                            ? null
                            : () => _mapController.move(point, 16),
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Centre on reported position'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
