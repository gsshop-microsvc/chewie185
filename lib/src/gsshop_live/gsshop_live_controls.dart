import 'dart:async';

import 'package:flutter_svg/svg.dart';
import 'package:chewie/src/center_play_button.dart';
import 'package:chewie/src/helpers/utils.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'widgets/product_live_player_timer.dart';
import '../chewie_player.dart';

class GsshopLiveControls extends StatefulWidget {
  const GsshopLiveControls({
    this.showPlayButton = true,
    super.key,
  });

  final bool showPlayButton;

  @override
  State<StatefulWidget> createState() {
    return _MaterialControlsState();
  }
}

class _MaterialControlsState extends State<GsshopLiveControls>
    with SingleTickerProviderStateMixin {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  Timer? _bufferingDisplayTimer;

  final barHeight = 48.0 * 1.5;
  final marginSize = 5.0;

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

    return ValueListenableBuilder(
        valueListenable: chewieController.miniPlayerNotifier!,
        builder: (context, value, _) {
          return value
              ? Container()
              : GestureDetector(
                  onTap: () {
                    _cancelAndRestartTimer();
                  },
                  child: AbsorbPointer(
                    absorbing: notifier.hideStuff,
                    child: Stack(
                      children: [
                        _buildHitArea(),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            _buildBottomBar(context),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
        });
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
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

  AnimatedOpacity _buildBottomBar(
    BuildContext context,
  ) {
    final iconColor = Theme.of(context).textTheme.labelLarge!.color;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: SafeArea(
        bottom: chewieController.isFullScreen,
        minimum: chewieController.controlsSafeAreaMinimum,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (chewieController.leftTime == null ||
                      chewieController.leftTime == '') ...[
                    const SizedBox(
                      width: 12,
                    ),
                    _buildPosition(iconColor),
                  ],
                  const Spacer(),
                  if (chewieController.allowMuting)
                    _buildMuteButton(controller),
                  if (chewieController.allowFullScreen) _buildExpandButton(),
                  Container(
                    width: 12.0,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: chewieController.isFullScreen ? 20.0 : 10.0,
            ),
          ],
        ),
      ),
    );
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
        duration: const Duration(milliseconds: 150),
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
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 36.0,
          height: 36.0,
          color: const Color.fromARGB(0, 255, 255, 255),
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
    );
  }

  Widget _buildHitArea() {
    final bool showPlayButton = !notifier.hideStuff;

    return GestureDetector(
      onTap: () {
        notifier.hideStuff = true;
      },
      child: AnimatedOpacity(
        opacity: showPlayButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: const Color.fromARGB(38, 0, 0, 0),
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
              const SizedBox(
                height: 4.0,
              ),
              if (chewieController.leftTime != null)
                ProductLivePlayerTimer(
                  leftTime: chewieController.leftTime!,
                  show: showPlayButton,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    return RichText(
      text: TextSpan(
        text: '${formatDuration(position)} ',
        children: <InlineSpan>[
          TextSpan(
            text: '/ ${formatDuration(duration)}',
            style: const TextStyle(
              fontSize: 14.0,
              color: Color.fromARGB(171, 255, 255, 255),
              fontWeight: FontWeight.normal,
            ),
          )
        ],
        style: const TextStyle(
          fontSize: 14.0,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();

    if (controller.value.isPlaying) {
      _startHideTimer();
    }

    notifier.hideStuff = false;
  }

  Future<void> _initialize() async {
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        notifier.hideStuff = false;
      });
    }
  }

  void _onExpandCollapse() {
    if (mounted) {
      setState(() {
        notifier.hideStuff = true;
        var isChange = chewieController.toggleFullScreenFunction();
        if (isChange) {
          chewieController.toggleFullScreen();

          _showAfterExpandCollapseTimer =
              Timer(const Duration(milliseconds: 200), () {
            _cancelAndRestartTimer();
          });
        }
      });
    }
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    if (mounted) {
      setState(() {
        if (controller.value.isPlaying) {
          notifier.hideStuff = false;
          _hideTimer?.cancel();
          controller.pause();
          if (chewieController.pauseFunction != null) {
            chewieController.pauseFunction!();
          }
        } else {
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
            controller.play().then((e) {
              _startHideTimer();
            });
          }
        }
      });
    }
  }

  void _startHideTimer() {
    final hideControlsTimer = chewieController.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : chewieController.hideControlsTimer;
    _hideTimer = Timer(hideControlsTimer, () {
      notifier.hideStuff = true;
    });
  }

  void _bufferingTimerTimeout() {
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
      }
    } else {}

    if (chewieController.hideStuff == false && !controller.value.isPlaying) {
      _hideTimer?.cancel();
    }

    if (mounted) {
      setState(() {
        _latestValue = controller.value;
      });
    }
  }
}
