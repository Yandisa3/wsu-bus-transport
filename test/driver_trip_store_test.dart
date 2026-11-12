import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bus_transport_app/models/driver_trip.dart';
import 'package:bus_transport_app/models/student.dart';
import 'package:bus_transport_app/services/demo_trip_store.dart';

class MemoryTrips implements TripPersistence {
  String? data;
  bool failWrites = false;
  bool throwOnWrite = false;
  Completer<bool>? gate;

  @override
  Future<String?> read() async => data;

  @override
  Future<bool> write(String value) async {
    if (throwOnWrite) {
      throw StateError('Device storage unavailable.');
    }
    final accepted = gate == null ? !failWrites : await gate!.future;
    if (accepted) {
      data = value;
    }
    return accepted;
  }
}

const students = [
  Student(studentNumber: '221012345', name: 'Funded One', isFunded: true),
  Student(studentNumber: '221054321', name: 'Funded Two', isFunded: true),
  Student(studentNumber: '221099999', name: 'Not Funded', isFunded: false),
];

Future<void> startTrip(
  DemoTripStore store, {
  String uid = 'driver-1',
  int capacity = 2,
}) => store.start(
  uid: uid,
  driverName: 'Test Driver',
  bus: 'Bus 01',
  route: 'Residence to campus',
  capacity: capacity,
  stops: ['St Patrix', 'Anthill'],
);

Future<TripEntry> checkStudent(
  DemoTripStore store,
  String number, {
  String uid = 'driver-1',
}) => store.board(
  uid: uid,
  tripId: store.activeFor(uid)!.id,
  number: number,
  manual: true,
  students: students,
);

void main() {
  late MemoryTrips persistence;
  late DemoTripStore store;

  setUp(() async {
    persistence = MemoryTrips();
    store = DemoTripStore(persistence: persistence);
    await store.load();
  });

  tearDown(() => store.dispose());

  test(
    'boarding requires an active trip owned by the signed-in driver',
    () async {
      await expectLater(
        store.board(
          uid: 'driver-1',
          tripId: 'missing',
          number: '221012345',
          manual: true,
          students: students,
        ),
        throwsStateError,
      );
      await startTrip(store);
      final id = store.activeFor('driver-1')!.id;
      await startTrip(store, uid: 'driver-2');
      await expectLater(
        store.board(
          uid: 'driver-2',
          tripId: id,
          number: '221012345',
          manual: true,
          students: students,
        ),
        throwsStateError,
      );
      await expectLater(store.end('driver-2', id), throwsStateError);
      expect(store.activeFor('driver-1')!.boarded, 0);
    },
  );

  test(
    'one active trip per driver; a failed second start keeps the first',
    () async {
      await startTrip(store);
      final id = store.activeFor('driver-1')!.id;
      await expectLater(startTrip(store), throwsStateError);
      expect(store.trips, hasLength(1));
      expect(store.activeFor('driver-1')!.id, id);
    },
  );

  test('denied and unknown attempts never consume a place', () async {
    await startTrip(store);
    expect(
      (await checkStudent(store, '221099999')).outcome,
      BoardingOutcome.denied,
    );
    expect(
      (await checkStudent(store, '999999999')).outcome,
      BoardingOutcome.unknown,
    );
    expect(
      (await checkStudent(store, '221012345')).outcome,
      BoardingOutcome.boarded,
    );
    final trip = store.activeFor('driver-1')!;
    expect(trip.boarded, 1);
    expect(trip.denied, 2);
    expect(trip.remaining, 1);
  });

  test('funding expires at the exact boundary', () async {
    await startTrip(store);
    final expiry = DateTime.utc(2030, 1, 1);
    final result = await store.board(
      uid: 'driver-1',
      tripId: store.activeFor('driver-1')!.id,
      number: '221000001',
      manual: false,
      now: expiry,
      students: [
        Student(
          studentNumber: '221000001',
          name: 'Expired',
          isFunded: true,
          fundingExpiry: expiry,
        ),
      ],
    );
    expect(result.outcome, BoardingOutcome.expired);
    expect(store.activeFor('driver-1')!.boarded, 0);
  });

  test(
    'capacity is enforced and repeated scans cannot increase the count',
    () async {
      await startTrip(store, capacity: 1);
      await checkStudent(store, '221012345');
      expect(
        (await checkStudent(store, '221012345')).outcome,
        BoardingOutcome.duplicate,
      );
      expect(
        (await checkStudent(store, '221054321')).outcome,
        BoardingOutcome.full,
      );
      expect(store.activeFor('driver-1')!.boarded, 1);
      expect(store.activeFor('driver-1')!.remaining, 0);
      expect(store.activeFor('driver-1')!.denied, 2);
    },
  );

  test(
    'restart restores stop, notes and accepted passengers without re-admission',
    () async {
      await startTrip(store);
      final id = store.activeFor('driver-1')!.id;
      await store.setStop('driver-1', id, 1);
      await store.addNote('driver-1', id, 'Delay', 'Ten minute delay');
      await checkStudent(store, '221012345');
      final restored = DemoTripStore(persistence: persistence);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.activeFor('driver-1')!.currentStop, 'Anthill');
      expect(
        restored.activeFor('driver-1')!.notes.single.text,
        'Ten minute delay',
      );
      expect(
        (await checkStudent(restored, '221012345')).outcome,
        BoardingOutcome.duplicate,
      );
      expect(restored.activeFor('driver-1')!.boarded, 1);
      expect(restored.activeFor('driver-1')!.entries.first.stop, 'Anthill');
    },
  );

  test(
    'a rejected save leaves both counts and persisted data unchanged',
    () async {
      await startTrip(store);
      final before = persistence.data;
      persistence.failWrites = true;
      await expectLater(checkStudent(store, '221012345'), throwsStateError);
      expect(store.activeFor('driver-1')!.entries, isEmpty);
      expect(persistence.data, before);
      expect(store.busy, isFalse);
      persistence.failWrites = false;
      expect(
        (await checkStudent(store, '221012345')).outcome,
        BoardingOutcome.boarded,
      );
      expect(store.activeFor('driver-1')!.boarded, 1);
    },
  );

  test(
    'a storage exception releases busy state and keeps the active trip',
    () async {
      await startTrip(store);
      final id = store.activeFor('driver-1')!.id;
      persistence.throwOnWrite = true;
      await expectLater(store.end('driver-1', id), throwsStateError);
      expect(store.busy, isFalse);
      expect(store.activeFor('driver-1')!.id, id);
    },
  );

  test(
    'rapid submissions cannot bypass capacity while a write is pending',
    () async {
      await startTrip(store, capacity: 1);
      persistence.gate = Completer<bool>();
      final first = checkStudent(store, '221012345');
      expect(store.busy, isTrue);
      await expectLater(checkStudent(store, '221054321'), throwsStateError);
      expect(store.activeFor('driver-1')!.boarded, 0);
      persistence.gate!.complete(true);
      await first;
      expect(store.activeFor('driver-1')!.boarded, 1);
      expect(store.activeFor('driver-1')!.entries, hasLength(1));
    },
  );

  test(
    'completed trips are immutable and a new trip starts a new count',
    () async {
      await startTrip(store);
      final oldId = store.activeFor('driver-1')!.id;
      await checkStudent(store, '221012345');
      await store.end('driver-1', oldId);
      expect(store.activeFor('driver-1'), isNull);
      await expectLater(
        store.addNote('driver-1', oldId, 'Other', 'Late edit'),
        throwsStateError,
      );
      await startTrip(store);
      expect(store.activeFor('driver-1')!.boarded, 0);
      expect(
        (await checkStudent(store, '221012345')).outcome,
        BoardingOutcome.boarded,
      );
      expect(store.trips.first.boarded, 1);
      expect(store.trips.first.active, isFalse);
    },
  );

  test(
    'changing the stop directory cannot rewrite a trip already started',
    () async {
      final stops = ['St Patrix', 'Anthill'];
      await store.start(
        uid: 'driver-1',
        driverName: 'Driver',
        bus: 'Bus 01',
        route: 'Campus',
        capacity: 2,
        stops: stops,
      );
      stops.clear();
      final trip = store.activeFor('driver-1')!;
      expect(trip.stops, ['St Patrix', 'Anthill']);
      await expectLater(
        store.setStop('driver-1', trip.id, 9),
        throwsArgumentError,
      );
      expect(store.activeFor('driver-1')!.currentStop, 'St Patrix');
    },
  );

  test(
    'damaged saved data blocks new trips and is not silently overwritten',
    () async {
      persistence.data = '{damaged';
      final restored = DemoTripStore(persistence: persistence);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.loaded, isFalse);
      expect(restored.loadError, isNotNull);
      await expectLater(startTrip(restored), throwsStateError);
      expect(persistence.data, '{damaged');
      persistence.data = '[]';
      await restored.load();
      expect(restored.loaded, isTrue);
      expect(restored.loadError, isNull);
    },
  );

  test(
    'conflicting saved active trips are rejected instead of choosing one',
    () async {
      await startTrip(store);
      final first = store.activeFor('driver-1')!.toMap();
      persistence.data = jsonEncode([
        first,
        {...first, 'id': 'conflicting-trip'},
      ]);
      final restored = DemoTripStore(persistence: persistence);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.loaded, isFalse);
      expect(restored.loadError, isNotNull);
    },
  );
}
