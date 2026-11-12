import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_trip.dart';
import '../models/student.dart';

abstract interface class TripPersistence {
  Future<String?> read();
  Future<bool> write(String value);
}

class _PreferencesTrips implements TripPersistence {
  static const _key = 'demo_trips_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  @override
  Future<bool> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);
}

/// LOCAL DEMO ONLY. This is not a production boarding authorisation service.
/// A failed save does not update the in-memory accepted count.
class DemoTripStore extends ChangeNotifier {
  static final instance = DemoTripStore(persistence: _PreferencesTrips());
  final TripPersistence persistence;
  DemoTripStore({required this.persistence});

  List<DriverTrip> _trips = [];
  bool loaded = false;
  bool busy = false;
  String? loadError;
  Future<void>? _loading;
  List<DriverTrip> get trips => List.unmodifiable(_trips);

  DriverTrip? activeFor(String uid) {
    for (final trip in _trips.reversed) {
      if (trip.driverUid == uid && trip.active) {
        return trip;
      }
    }
    return null;
  }

  Future<void> load() {
    if (loaded) {
      return Future.value();
    }
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await persistence.read();
      final data = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
      final trips = data
          .map((e) => DriverTrip.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      final activeOwners = <String>{};
      for (final trip in trips.where((t) => t.active)) {
        if (!activeOwners.add(trip.driverUid)) {
          throw const FormatException('Multiple active trips.');
        }
      }
      _trips = trips;
      loaded = true;
      loadError = null;
    } catch (_) {
      loadError =
          'Saved trips could not be loaded. Retry before starting a trip.';
    } finally {
      _loading = null;
      notifyListeners();
    }
  }

  void _ready() {
    if (!loaded) {
      throw StateError('Load saved trips first.');
    }
    if (busy) {
      throw StateError('A save is in progress. Please wait.');
    }
  }

  Future<void> _commit(List<DriverTrip> next) async {
    _ready();
    busy = true;
    notifyListeners();
    try {
      final saved = await persistence.write(
        jsonEncode(next.map((t) => t.toMap()).toList()),
      );
      if (!saved) {
        throw StateError('Could not save. Please try again.');
      }
      _trips = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  DriverTrip _active(String uid, String id) {
    _ready();
    final trip = activeFor(uid);
    if (trip == null || trip.id != id) {
      throw StateError('This trip is no longer active.');
    }
    return trip;
  }

  Future<void> _replace(DriverTrip trip) =>
      _commit(_trips.map((t) => t.id == trip.id ? trip : t).toList());

  Future<void> start({
    required String uid,
    required String driverName,
    required String bus,
    required String route,
    required int capacity,
    required List<String> stops,
  }) async {
    _ready();
    if (uid.isEmpty ||
        bus.trim().isEmpty ||
        route.trim().isEmpty ||
        capacity < 1 ||
        capacity > 100 ||
        stops.isEmpty ||
        stops.any((s) => s.trim().isEmpty)) {
      throw ArgumentError(
        'Enter a bus, route, stops and capacity from 1 to 100.',
      );
    }
    if (activeFor(uid) != null) {
      throw StateError('Finish your active trip first.');
    }
    final now = DateTime.now();
    final prefix = '$uid-${now.microsecondsSinceEpoch}';
    var id = prefix;
    var suffix = 1;
    while (_trips.any((trip) => trip.id == id)) {
      id = '$prefix-${suffix++}';
    }
    await _commit([
      ..._trips,
      DriverTrip(
        id: id,
        driverUid: uid,
        driverName: driverName,
        bus: bus.trim(),
        route: route.trim(),
        capacity: capacity,
        stops: stops,
        startedAt: now,
      ),
    ]);
  }

  Future<void> setStop(String uid, String id, int index) async {
    final trip = _active(uid, id);
    if (index < 0 || index >= trip.stops.length) {
      throw ArgumentError('Invalid stop.');
    }
    await _replace(trip.copyWith(stopIndex: index));
  }

  Future<void> end(String uid, String id) async {
    final trip = _active(uid, id);
    await _replace(trip.copyWith(endedAt: DateTime.now()));
  }

  Future<void> addNote(
    String uid,
    String id,
    String category,
    String text,
  ) async {
    final trip = _active(uid, id);
    if (text.trim().isEmpty || text.trim().length > 500) {
      throw ArgumentError('Enter a note of 1 to 500 characters.');
    }
    await _replace(
      trip.copyWith(
        notes: [
          ...trip.notes,
          TripNote(category: category, text: text.trim(), time: DateTime.now()),
        ],
      ),
    );
  }

  Future<TripEntry> board({
    required String uid,
    required String tripId,
    required String number,
    required bool manual,
    required List<Student> students,
    DateTime? now,
  }) async {
    final trip = _active(uid, tripId);
    final time = now ?? DateTime.now();
    Student? student;
    for (final candidate in students) {
      if (candidate.studentNumber == number) {
        student = candidate;
        break;
      }
    }
    final duplicate = trip.entries.any(
      (e) => e.number == number && e.outcome == BoardingOutcome.boarded,
    );
    final outcome = duplicate
        ? BoardingOutcome.duplicate
        : student == null
        ? BoardingOutcome.unknown
        : !student.isFunded
        ? BoardingOutcome.denied
        : student.fundingExpiry != null &&
              !time.isBefore(student.fundingExpiry!)
        ? BoardingOutcome.expired
        : trip.boarded >= trip.capacity
        ? BoardingOutcome.full
        : BoardingOutcome.boarded;
    final entry = TripEntry(
      number: number,
      name: student?.name ?? 'Unknown student',
      stop: trip.currentStop,
      time: time,
      outcome: outcome,
      manual: manual,
    );
    await _replace(trip.copyWith(entries: [...trip.entries, entry]));
    return entry;
  }
}
