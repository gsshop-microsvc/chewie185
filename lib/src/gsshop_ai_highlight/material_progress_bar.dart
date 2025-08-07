import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class GSShopAiHighlightVideoProgressBar extends StatelessWidget {
  GSShopAiHighlightVideoProgressBar(
    this.controller, {
    this.height = kToolbarHeight,
    ChewieProgressColors? colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.isHandleVisible = false,
    this.alwaysDraggable = false,
    Key? key,
  })  : colors = colors ?? ChewieProgressColors(),
        super(key: key);

  final double height;
  final VideoPlayerController controller;
  final ChewieProgressColors colors;
  final Function()? onDragStart;
  final Function()? onDragEnd;
  final Function(DragUpdateDetails)? onDragUpdate;
  final bool isHandleVisible;
  final bool alwaysDraggable;
  @override
  Widget build(BuildContext context) {
    return VideoProgressBar(
      controller,
      barHeight: 2,
      handleHeight: 7,
      drawShadow: true,
      colors: colors,
      onDragEnd: onDragEnd,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      draggableProgressBar: isHandleVisible,
      isHandleVisible: isHandleVisible,
      alwaysDraggable: alwaysDraggable,
    );
  }
}
