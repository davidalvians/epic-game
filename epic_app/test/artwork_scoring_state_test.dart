import 'package:epic_app/data/repositories/artwork_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active scoring marker prevents a parallel retry for the same artwork',
      () {
    const artworkId = 'artwork-under-test';

    expect(ArtworkRepository.isScoringActive(artworkId), isFalse);

    ArtworkRepository.markScoringActive(artworkId);
    expect(ArtworkRepository.isScoringActive(artworkId), isTrue);

    ArtworkRepository.markScoringFinished(artworkId);
    expect(ArtworkRepository.isScoringActive(artworkId), isFalse);
  });
}
