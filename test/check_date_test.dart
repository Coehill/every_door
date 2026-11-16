import 'package:every_door/models/amenity.dart';
import 'package:every_door/models/osm_element.dart';
import 'package:latlong2/latlong.dart';
import 'package:test/test.dart';

void main() {
  OsmChange existing([String? date]) => OsmChange(OsmElement(
        source: 'osm',
        id: const OsmId(OsmElementType.node, 1),
        version: 1,
        timestamp: DateTime(2020),
        tags: {'amenity': 'cafe', if (date != null) 'check_date': date},
        center: const LatLng(0, 0),
      ));

  String today() => OsmChange.kDateFormat.format(DateTime.now());

  test('automatic checking preserves a manually edited date', () {
    final change = existing('2020-01-01');
    change['check_date'] = '2024-02-29';
    change.checkIfNeeded('2020-01-01');
    expect(change['check_date'], '2024-02-29');
    expect(change.copy()['check_date'], '2024-02-29');
    final restored = OsmChange.fromJson({
      ...change.element!.toJson(),
      ...change.toJson(),
    });
    expect(restored['check_date'], '2024-02-29');
    expect(restored.toElement(newId: 1).tags['check_date'], '2024-02-29');
  });

  test('automatic checking preserves a date skipped in the local time zone',
      () {
    final change = existing();
    change['check_date'] = '2011-12-30';
    change.checkIfNeeded(null);
    expect(change['check_date'], '2011-12-30');
  });

  test('automatic checking refreshes unchanged or missing dates', () {
    for (final date in [null, '2020-01-01']) {
      final change = existing(date);
      change['name'] = 'Cafe';
      change.checkIfNeeded(date);
      expect(change['check_date'], today());
    }
  });

  test('automatic checking refreshes an unchanged pending date', () {
    final change = existing();
    change['check_date'] = '2020-01-01';
    change.checkIfNeeded(change['check_date']);
    expect(change['check_date'], today());
  });

  test('automatic checking preserves an edit back to the original OSM date',
      () {
    final change = existing('2020-01-01');
    change['check_date'] = '2021-01-01';
    final originalCheckDate = change['check_date'];
    change['check_date'] = '2020-01-01';
    change.checkIfNeeded(originalCheckDate);
    expect(change['check_date'], '2020-01-01');
  });

  test('automatic checking replaces a future date', () {
    final now = DateTime.now();
    for (final date in [
      OsmChange.kDateFormat
          .format(DateTime.utc(now.year, now.month, now.day + 1)),
      '81030-04-01',
    ]) {
      final change = existing();
      change['check_date'] = date;
      change.checkIfNeeded(null);
      expect(change['check_date'], today(), reason: date);
    }
  });

  test('automatic checking replaces removed or invalid dates', () {
    for (final date in [
      null,
      'not a date',
      '2023-02-29',
      '2024-13-01',
      '2024-04-31',
      '2024-2-01',
      '2024-01-01T00:00:00',
    ]) {
      final change = existing('2020-01-01');
      change['check_date'] = date;
      change.checkIfNeeded('2020-01-01');
      expect(change['check_date'], today(), reason: '$date');
    }
  });
}
