import 'package:audioplayers/audioplayers.dart';
import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttush_push/loading/loading.dart';

void main() {
  group('PreloadState', () {
    PreloadState initialState() {
      return PreloadState.initial(
        images: Images(),
        audio: AudioCache(prefix: ''),
      );
    }

    test('initial', () {
      final state = initialState();
      expect(state.totalCount, 0);
      expect(state.loadedCount, 0);
      expect(state.currentLabel, '');
    });

    group('progress', () {
      test('when not started is zero', () {
        final state = initialState();
        expect(state.progress, 0);
      });

      test('after started', () {
        final state = initialState().copyWith(
          totalCount: 2,
          loadedCount: 1,
        );
        expect(state.progress, 0.5);
      });
    });

    group('isComplete', () {
      test('when not started is zero', () {
        final state = initialState();
        expect(state.isComplete, false);
      });

      test('after started', () {
        final state = initialState().copyWith(
          totalCount: 2,
          loadedCount: 1,
        );
        expect(state.isComplete, false);

        final stateComplete = state.copyWith(loadedCount: 2);
        expect(stateComplete.isComplete, true);
      });
    });
  });
}
