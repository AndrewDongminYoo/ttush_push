part of 'preload_cubit.dart';

/// State for [PreloadCubit].
class PreloadState extends Equatable {
  /// Create a [PreloadState] with initial conditions.
  const PreloadState.initial({required this.images, required this.audio})
    : totalCount = 0,
      loadedCount = 0,
      currentLabel = '';

  const PreloadState._({
    required this.images,
    required this.audio,
    required this.loadedCount,
    required this.currentLabel,
    required this.totalCount,
  });

  /// The image cache populated during preloading.
  final Images images;

  /// The audio cache populated during preloading.
  final AudioCache audio;

  /// The total count of load phases to be completed
  final int totalCount;

  /// The count of load phases that were completed so far
  final int loadedCount;

  /// A description of what is being loaded
  final String currentLabel;

  double get progress => totalCount == 0 ? 0 : loadedCount / totalCount;

  bool get isComplete => progress == 1.0;

  @override
  List<Object?> get props => [
    images,
    audio,
    totalCount,
    loadedCount,
    currentLabel,
  ];

  PreloadState copyWith({
    int? loadedCount,
    String? currentLabel,
    int? totalCount,
  }) {
    return PreloadState._(
      images: images,
      audio: audio,
      loadedCount: loadedCount ?? this.loadedCount,
      currentLabel: currentLabel ?? this.currentLabel,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
