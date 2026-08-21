part of 'audio_cubit.dart';

class AudioState extends Equatable {
  const AudioState({
    required this.effectPlayer,
    required this.bgm,
    this.volume = 1,
  });

  final AudioPlayer effectPlayer;

  final Bgm bgm;

  final double volume;

  AudioState copyWith({double? volume}) {
    return AudioState(
      effectPlayer: effectPlayer,
      bgm: bgm,
      volume: volume ?? this.volume,
    );
  }

  @override
  List<Object> get props => [effectPlayer, bgm, volume];
}
