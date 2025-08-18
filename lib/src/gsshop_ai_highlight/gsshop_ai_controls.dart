import 'dart:async';
import 'dart:io';

import 'package:chewie/src/center_play_button.dart';
import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/helpers/utils.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../chewie_player.dart';
import 'gsshop_ai_progress_bar.dart';

class GSSHOPAiHighlightControls extends StatefulWidget {
  const GSSHOPAiHighlightControls({
    this.showPlayButton = true,
    Key? key,
  }) : super(key: key);

  final bool showPlayButton;

  @override
  State<StatefulWidget> createState() {
    return _GSSHOPAiHighlightControlsState();
  }
}

class _GSSHOPAiHighlightControlsState extends State<GSSHOPAiHighlightControls>
    with SingleTickerProviderStateMixin {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  Timer? _bufferingDisplayTimer;
  Duration? _dragPosition;
  Offset? _dragGlobalPosition;
  bool _dragging = false;
  bool _displayTapped = false;
  bool isCompleted = false;
  bool _displayBufferingIndicator = false;
  bool _fullScreenProgressTouch = false;

  final double barHeight = 48.0 * 1.5;
  final double marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;

  // We know that _chewieController is set in didChangeDependencies
  ChewieController get chewieController => _chewieController!;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    notifier = Provider.of<PlayerNotifier>(context, listen: true);
    if (notifier.hideStuff) {
      _fullScreenProgressTouch = true;
    } else {
      _fullScreenProgressTouch = false;
    }

    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.only(
              bottom: chewieController.isFullScreen
                  ? 0.0
                  : _chewieController?.innerBottomPadding ?? 0.0),
          child: MouseRegion(
            onHover: (_) {
              _cancelAndRestartTimer();
            },
            child: GestureDetector(
              onTap: () => _cancelAndRestartTimer(),
              child: AbsorbPointer(
                absorbing: notifier.hideStuff,
                child: Stack(
                  children: [
                    // if (_displayBufferingIndicator)
                    //   const Center(
                    //     child: CircularProgressIndicator(),
                    //   )
                    // else
                    _buildHitArea(),

                    if (chewieController.leftTime == null ||
                        chewieController.leftTime == '') ...[
                      Positioned(
                        left: 8.0,
                        bottom: chewieController.isFullScreen
                            ? Platform.isIOS
                                ? 62.0
                                : 44.0
                            : 2.0,
                        child: _buildLeftTime(),
                      )
                    ],

                    Positioned(
                      right: 6.0,
                      bottom: chewieController.isFullScreen
                          ? Platform.isIOS
                              ? 70.0
                              : 44.0
                          : 10.0,
                      child: Row(
                        children: [
                          _buildMuteButton(controller),
                          if (chewieController.allowFullScreen)
                            _buildExpandButton(),
                        ],
                      ),
                    ),

                    if (_dragging &&
                        _dragPosition != null &&
                        _dragGlobalPosition != null)
                      _buildPositionOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (chewieController.isFullScreen)
          Positioned(
            bottom: Platform.isIOS ? 40.0 : 16.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: notifier.hideStuff ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: _buildProgressBar(),
            ),
          )
        else
          Positioned(
            bottom: 0.0,
            left: 0,
            right: 0,
            child: _buildProgressBar(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    // 컨트롤러가 연결된 이후에만 리스너 제거
    if (_chewieController != null) {
      controller.removeListener(_updateState);
    }
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _bufferingDisplayTimer?.cancel();
    _bufferingDisplayTimer = null;
  }

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (oldController != chewieController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  GestureDetector _buildMuteButton(
    VideoPlayerController controller,
  ) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();

        if (_latestValue.volume == 0) {
          _latestVolume == 1.0;
          controller.setVolume(1.0);
          if (chewieController.volumeOnFunction != null) {
            chewieController.volumeOnFunction!();
          }
        } else {
          _latestVolume = controller.value.volume;
          if (chewieController.volumeOffFunction != null) {
            chewieController.volumeOffFunction!();
          }

          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: 36,
          width: 36,
          color: const Color.fromARGB(0, 255, 255, 255),
          child: Center(
            child: _latestValue.volume > 0.0
                ? SvgPicture.asset(
                    'assets/svg/icon/player/volume_up.svg',
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    width: 20,
                    height: 20,
                  )
                : SvgPicture.asset(
                    'assets/svg/icon/player/volume_down.svg',
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    width: 20,
                    height: 20,
                  ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: Container(
        width: 36.0,
        height: 36.0,
        color: const Color.fromARGB(0, 255, 255, 255),
        child: AnimatedOpacity(
          opacity: notifier.hideStuff ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 36.0,
            height: 36.0,
            child: Center(
              child: chewieController.isFullScreen
                  ? SvgPicture.asset(
                      'assets/svg/icon/player/zoom_out.svg',
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      width: 20,
                      height: 20,
                    )
                  : SvgPicture.asset(
                      'assets/svg/icon/player/zoom_in.svg',
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      width: 20,
                      height: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    final bool showPlayButton =
        widget.showPlayButton && !_dragging && !notifier.hideStuff;

    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          if (_displayTapped) {
            setState(() {
              notifier.hideStuff = true;
            });
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          setState(() {
            notifier.hideStuff = true;
          });
        }
      },
      child: AnimatedOpacity(
        opacity: showPlayButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black.withAlpha(38),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CenterPlayButton(
                backgroundColor: const Color(0xff191923).withAlpha(97),
                iconColor: Colors.white,
                isFinished: false,
                isPlaying: controller.value.isPlaying,
                show: showPlayButton,
                onPressed: _playPause,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Future<void> _onSpeedButtonTap() async {
  //   _hideTimer?.cancel();

  //   final chosenSpeed = await showModalBottomSheet<double>(
  //     context: context,
  //     isScrollControlled: true,
  //     useRootNavigator: chewieController.useRootNavigator,
  //     builder: (context) => PlaybackSpeedDialog(
  //       speeds: chewieController.playbackSpeeds,
  //       selected: _latestValue.playbackSpeed,
  //     ),
  //   );

  //   if (chosenSpeed != null) {
  //     controller.setPlaybackSpeed(chosenSpeed);
  //   }

  //   if (_latestValue.isPlaying) {
  //     _startHideTimer();
  //   }
  // }

  Widget _buildLeftTime() {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    final fontSize = chewieController.isFullScreen ? 14.0 : 13.0;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: chewieController.isFullScreen
            ? const EdgeInsets.only(
                top: 16.0,
                bottom: 8.0,
              )
            : const EdgeInsets.only(
                bottom: 8.0,
              ),
        child: RichText(
          text: TextSpan(
            text: '${formatDuration(position)} ',
            children: <InlineSpan>[
              TextSpan(
                text: '/ ${formatDuration(duration)}',
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white.withAlpha(191),
                  fontWeight: FontWeight.normal,
                ),
              )
            ],
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildSubtitleToggle() {
  //   //if don't have subtitle hiden button
  //   if (chewieController.subtitle?.isEmpty ?? true) {
  //     return const SizedBox();
  //   }
  //   return GestureDetector(
  //     onTap: _onSubtitleTap,
  //     child: Container(
  //       height: barHeight,
  //       color: Colors.transparent,
  //       padding: const EdgeInsets.only(
  //         left: 12.0,
  //         right: 12.0,
  //       ),
  //       child: Icon(
  //         _subtitleOn
  //             ? Icons.closed_caption
  //             : Icons.closed_caption_off_outlined,
  //         color: _subtitleOn ? Colors.white : Colors.grey[700],
  //       ),
  //     ),
  //   );
  // }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      notifier.hideStuff = false;
      _displayTapped = true;
    });
  }

  Future<void> _initialize() async {
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }
  }

  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true;
      var isChange = chewieController.toggleFullScreenFunction?.call() ?? false;
      if (isChange) {
        chewieController.toggleFullScreen();

        _showAfterExpandCollapseTimer =
            Timer(const Duration(milliseconds: 300), () {
          setState(() {
            _cancelAndRestartTimer();
          });
        });
      }
    });
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
        if (chewieController.pauseFunction != null) {
          chewieController.pauseFunction!();
        }
      } else {
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          controller.initialize().then((_) {
            controller.play();
            if (chewieController.playFunction != null) {
              chewieController.playFunction!();
            }
          });
        } else {
          if (isFinished) {
            controller.seekTo(Duration.zero);
          }
          if (chewieController.playFunction != null) {
            chewieController.playFunction!();
          }
          controller.play();
        }
      }
    });
  }

  void _startHideTimer() {
    // final hideControlsTimer = chewieController.hideControlsTimer.isNegative
    //     ? ChewieController.defaultHideControlsTimer
    //     : chewieController.hideControlsTimer;
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          notifier.hideStuff = true;
        });
      }
    });
  }

  void _bufferingTimerTimeout() {
    _displayBufferingIndicator = true;
    if (mounted) {
      setState(() {});
    }
  }

  void _updateState() {
    if (!mounted) return;

    // display the progress bar indicator only after the buffering delay if it has been set
    if (chewieController.progressIndicatorDelay != null) {
      if (controller.value.isBuffering) {
        _bufferingDisplayTimer ??= Timer(
          chewieController.progressIndicatorDelay!,
          _bufferingTimerTimeout,
        );
      } else {
        _bufferingDisplayTimer?.cancel();
        _bufferingDisplayTimer = null;
        _displayBufferingIndicator = false;
      }
    } else {
      _displayBufferingIndicator = controller.value.isBuffering;
    }

    setState(() {
      _latestValue = controller.value;
    });
  }

  Widget _buildProgressBar() {
    return Container(
      height: 32.0,
      alignment: Alignment.bottomCenter,
      padding: chewieController.isFullScreen
          ? EdgeInsets.only(
              top: 0,
              bottom: 0.0,
              right: 8.0,
              left: 8.0,
            )
          : const EdgeInsets.only(
              top: 0,
              bottom: 0,
            ),
      child: AbsorbPointer(
        absorbing: _fullScreenProgressTouch,
        child: GSShopAiHighlightVideoProgressBar(
          controller,
          onDragStart: () {
            setState(() {
              _dragging = true;
            });

            _hideTimer?.cancel();
          },
          onDragUpdate: (DragUpdateDetails details) {
            final position = context.calcRelativePosition(
              controller.value.duration,
              details.globalPosition,
            );

            setState(() {
              _dragPosition = position;
              _dragGlobalPosition = details.globalPosition;
            });

            _hideTimer?.cancel();
          },
          onDragEnd: () {
            setState(() {
              _dragging = false;
              _dragPosition = null;
              _dragGlobalPosition = null;
            });

            _startHideTimer();
          },
          colors: chewieController.materialProgressColors ??
              ChewieProgressColors(
                playedColor: Theme.of(context).colorScheme.secondary,
                handleColor: Theme.of(context).colorScheme.secondary,
                bufferedColor: Color(0xffafb1c0),
                backgroundColor: Color(0xffeaecf5),
              ),
          isHandleVisible: !notifier.hideStuff || _dragging,
          alwaysDraggable: true,
        ),
      ),
    );
  }

  Widget _buildPositionOverlay() {
    if (_dragPosition == null || _dragGlobalPosition == null) {
      return const SizedBox.shrink();
    }
    final double screenWidth = adaptiveWidth(context);
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return const SizedBox.shrink();
    }

    final Offset localPosition = renderBox.globalToLocal(_dragGlobalPosition!);

    // 시간을 mm:ss 형식으로 포맷
    final int minutes = _dragPosition!.inMinutes;
    final int seconds = _dragPosition!.inSeconds % 60;
    final String timeText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // overlay의 너비 계산
    const double overlayWidth = 66.0;
    const double overlayHeight = 32.0;

    // 화면 경계 체크
    double left = localPosition.dx - overlayWidth / 2;
    left = left.clamp(10.0, screenWidth - overlayWidth - 10.0);
    double bottom = chewieController.isFullScreen ? 64.0 : 20.0;

    return Positioned(
      left: left,
      bottom: bottom,
      child: Container(
        width: overlayWidth,
        height: overlayHeight,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(120),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Center(
          child: Text(
            timeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  static double adaptiveWidth(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 1024.0) {
      return 1024.0;
    } else if (MediaQuery.sizeOf(context).width >= 768.0) {
      return 768.0;
    }
    return MediaQuery.sizeOf(context).width;
  }
}

extension RelativePositionExtensions on BuildContext {
  Duration calcRelativePosition(
    Duration videoDuration,
    Offset globalPosition,
  ) {
    final box = findRenderObject()! as RenderBox;
    final Offset tapPos = box.globalToLocal(globalPosition);
    final double relative = (tapPos.dx / box.size.width).clamp(0, 1);
    final Duration position = videoDuration * relative;
    return position;
  }
}
