import 'dart:async';

import 'package:every_door/generated/l10n/app_localizations.dart';
import 'package:every_door/helpers/tags/element_kind.dart';
import 'package:every_door/models/amenity.dart';
import 'package:every_door/models/osm_element.dart';
import 'package:every_door/models/preset.dart';
import 'package:every_door/providers/changes.dart';
import 'package:every_door/providers/presets.dart';
import 'package:every_door/screens/editor.dart';
import 'package:every_door/screens/editor/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class RecordingChanges extends ChangesProvider {
  OsmChange? saved;

  @override
  Future<void> saveChange(OsmChange change) {
    saved = change.copy();
    // Stop after capturing the object, before unrelated persistence and map work.
    throw _SaveIntercepted();
  }
}

class _SaveIntercepted implements Exception {}

class FakePresets extends Fake implements PresetProvider {
  @override
  Future<Preset> getPresetForTags(Map<String, String> tags,
          {bool isArea = false, Locale? locale}) =>
      // The save handler does not depend on preset loading.
      Completer<Preset>().future;
}

void main() {
  setUp(ElementKind.reset);

  for (final bottomSheet in [false, true]) {
    testWidgets(
        '${bottomSheet ? 'bottom' : 'full'} editor passes the manual date to save',
        (tester) async {
      final change = OsmChange(OsmElement(
        source: 'osm',
        id: const OsmId(OsmElementType.node, 1),
        version: 1,
        timestamp: DateTime.utc(2020),
        tags: {'amenity': 'cafe'},
        center: const LatLng(0, 0),
      ));
      change['check_date'] = '2020-01-01';
      final changes = RecordingChanges();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          changesProvider.overrideWith(() => changes),
          presetProvider.overrideWith((ref) => FakePresets()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: bottomSheet
              ? BottomEditorPane(element: change, fields: const [])
              : PoiEditorPage(amenity: change),
        ),
      ));

      final finder = bottomSheet
          ? find.byType(BottomEditorPane)
          : find.byType(PoiEditorPage);
      final dynamic state = tester.state(finder);
      expect(() => state.saveAndClose(), throwsA(isA<_SaveIntercepted>()));
      expect(changes.saved?['check_date'], '2020-01-01');
      await tester.pump(const Duration(milliseconds: 1));
    });
  }
}
