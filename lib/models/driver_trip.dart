enum BoardingOutcome { boarded, denied, duplicate, full, unknown, expired }

extension BoardingOutcomeText on BoardingOutcome {
  String get label => switch (this) {
    BoardingOutcome.boarded => 'Boarded',
    BoardingOutcome.denied => 'Not funded',
    BoardingOutcome.duplicate => 'Already boarded',
    BoardingOutcome.full => 'Bus full',
    BoardingOutcome.unknown => 'Not registered',
    BoardingOutcome.expired => 'Funding expired',
  };
}

class TripEntry {
  final String number;
  final String name;
  final String stop;
  final DateTime time;
  final BoardingOutcome outcome;
  final bool manual;

  const TripEntry({
    required this.number,
    required this.name,
    required this.stop,
    required this.time,
    required this.outcome,
    required this.manual,
  });

  Map<String, dynamic> toMap() => {
    'number': number,
    'name': name,
    'stop': stop,
    'time': time.toIso8601String(),
    'outcome': outcome.name,
    'manual': manual,
  };

  factory TripEntry.fromMap(Map<String, dynamic> data) => TripEntry(
    number: data['number'] as String,
    name: data['name'] as String,
    stop: data['stop'] as String,
    time: DateTime.parse(data['time'] as String),
    outcome: BoardingOutcome.values.byName(data['outcome'] as String),
    manual: data['manual'] as bool,
  );
}

class TripNote {
  final String category;
  final String text;
  final DateTime time;
  const TripNote({
    required this.category,
    required this.text,
    required this.time,
  });
  Map<String, dynamic> toMap() => {
    'category': category,
    'text': text,
    'time': time.toIso8601String(),
  };
  factory TripNote.fromMap(Map<String, dynamic> data) => TripNote(
    category: data['category'] as String,
    text: data['text'] as String,
    time: DateTime.parse(data['time'] as String),
  );
}

class DriverTrip {
  final String id;
  final String driverUid;
  final String driverName;
  final String bus;
  final String route;
  final int capacity;
  final List<String> stops;
  final int stopIndex;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<TripEntry> entries;
  final List<TripNote> notes;

  DriverTrip({
    required this.id,
    required this.driverUid,
    required this.driverName,
    required this.bus,
    required this.route,
    required this.capacity,
    required List<String> stops,
    required this.startedAt,
    this.stopIndex = 0,
    this.endedAt,
    List<TripEntry> entries = const [],
    List<TripNote> notes = const [],
  }) : stops = List.unmodifiable(stops),
       entries = List.unmodifiable(entries),
       notes = List.unmodifiable(notes);

  bool get active => endedAt == null;
  int get boarded =>
      entries.where((e) => e.outcome == BoardingOutcome.boarded).length;
  int get denied =>
      entries.where((e) => e.outcome != BoardingOutcome.boarded).length;
  int get remaining => (capacity - boarded).clamp(0, capacity).toInt();
  String get currentStop => stops[stopIndex];

  DriverTrip copyWith({
    int? stopIndex,
    DateTime? endedAt,
    List<TripEntry>? entries,
    List<TripNote>? notes,
  }) => DriverTrip(
    id: id,
    driverUid: driverUid,
    driverName: driverName,
    bus: bus,
    route: route,
    capacity: capacity,
    stops: stops,
    startedAt: startedAt,
    stopIndex: stopIndex ?? this.stopIndex,
    endedAt: endedAt ?? this.endedAt,
    entries: entries ?? this.entries,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'driverUid': driverUid,
    'driverName': driverName,
    'bus': bus,
    'route': route,
    'capacity': capacity,
    'stops': stops,
    'stopIndex': stopIndex,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'entries': entries.map((e) => e.toMap()).toList(),
    'notes': notes.map((e) => e.toMap()).toList(),
  };

  factory DriverTrip.fromMap(Map<String, dynamic> data) {
    final stops = List<String>.from(data['stops'] as List);
    final capacity = data['capacity'] as int;
    final index = data['stopIndex'] as int;
    if (stops.isEmpty || capacity < 1 || index < 0 || index >= stops.length) {
      throw const FormatException('Invalid saved trip.');
    }
    return DriverTrip(
      id: data['id'] as String,
      driverUid: data['driverUid'] as String,
      driverName: data['driverName'] as String,
      bus: data['bus'] as String,
      route: data['route'] as String,
      capacity: capacity,
      stops: stops,
      stopIndex: index,
      startedAt: DateTime.parse(data['startedAt'] as String),
      endedAt: data['endedAt'] == null
          ? null
          : DateTime.parse(data['endedAt'] as String),
      entries: (data['entries'] as List)
          .map((e) => TripEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      notes: (data['notes'] as List)
          .map((e) => TripNote.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
