import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/release_event_model.dart';

void main() {
  group('ReleaseEventModel Tests', () {
    test('defaultEvents menyediakan daftar event Pokémon yang valid dan tidak kosong', () {
      final events = ReleaseEventModel.defaultEvents;
      expect(events.isNotEmpty, isTrue);

      final hasSetRelease = events.any((e) => e.isSetRelease);
      final hasTournament = events.any((e) => e.isTournament);

      expect(hasSetRelease, isTrue);
      expect(hasTournament, isTrue);
    });

    test('Serialization JSON bolak-balik berfungsi dengan benar', () {
      final event = ReleaseEventModel(
        id: 'test-event-1',
        title: 'Prismatic Evolutions Launch',
        eventType: 'set_release',
        eventDate: DateTime.utc(2026, 11, 15, 14, 0, 0),
        description: 'Special Eeveelution set',
        setId: 'sv8.5',
        location: 'Global',
      );

      final json = event.toJson();
      final parsed = ReleaseEventModel.fromJson(json);

      expect(parsed.id, equals(event.id));
      expect(parsed.title, equals(event.title));
      expect(parsed.eventType, equals(event.eventType));
      expect(parsed.eventDate, equals(event.eventDate));
      expect(parsed.setId, equals(event.setId));
      expect(parsed.location, equals(event.location));
      expect(parsed.isSetRelease, isTrue);
      expect(parsed.isTournament, isFalse);
    });

    test('Serialization Map SQLite bolak-balik berfungsi dengan benar', () {
      final event = ReleaseEventModel(
        id: 'test-event-2',
        title: 'Indonesia Regional Championship',
        eventType: 'tournament',
        eventDate: DateTime.utc(2026, 12, 1, 9, 0, 0),
        description: 'Turnamen Nasional',
        location: 'Jakarta',
      );

      final map = event.toMap();
      final parsed = ReleaseEventModel.fromMap(map);

      expect(parsed.id, equals(event.id));
      expect(parsed.title, equals(event.title));
      expect(parsed.isTournament, isTrue);
      expect(parsed.eventDate.millisecondsSinceEpoch, equals(event.eventDate.millisecondsSinceEpoch));
    });
  });
}
