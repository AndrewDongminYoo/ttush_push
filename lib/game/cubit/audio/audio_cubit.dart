import 'package:audioplayers/audioplayers.dart';
import 'package:equatable/equatable.dart';
import 'package:flame_audio/bgm.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'audio_state.dart';

class AudioCubit extends Cubit<AudioState> {
  AudioCubit({required AudioPlayer audioPlayer, required Bgm backgroundMusic})
    : super(AudioState(effectPlayer: audioPlayer, bgm: backgroundMusic));

  AudioCubit.test({
    required AudioPlayer effectPlayer,
    required Bgm bgm,
    double volume = 1.0,
  }) : super(AudioState(effectPlayer: effectPlayer, bgm: bgm, volume: volume));

  Future<void> _changeVolume(double volume) async {
    await state.effectPlayer.setVolume(volume);
    await state.bgm.audioPlayer.setVolume(volume);
    if (!isClosed) {
      emit(state.copyWith(volume: volume));
    }
  }

  Future<void> toggleVolume() async {
    if (state.volume == 0) {
      return _changeVolume(1);
    }
    return _changeVolume(0);
  }

  @override
  Future<void> close() async {
    await state.effectPlayer.dispose();
    await state.bgm.dispose();
    return super.close();
  }
}
