import 'package:flutter_test/flutter_test.dart';

import 'package:riogram/models/decentralization_models.dart';

void main() {
  group('DecentralizationResearchCatalog', () {
    test('contains roadmap items for each track', () {
      expect(DecentralizationResearchCatalog.items, isNotEmpty);
      for (final track in DecentralizationTrack.values) {
        final items = DecentralizationResearchCatalog.byTrack(track);
        expect(items.every((item) => item.track == track), isTrue);
      }
    });

    test('labels are non-empty', () {
      for (final phase in DecentralizationPhase.values) {
        expect(
          DecentralizationResearchCatalog.phaseLabel(phase),
          isNotEmpty,
        );
      }
      for (final track in DecentralizationTrack.values) {
        expect(
          DecentralizationResearchCatalog.trackLabel(track),
          isNotEmpty,
        );
      }
    });
  });
}
