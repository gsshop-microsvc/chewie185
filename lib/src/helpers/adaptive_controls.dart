import 'package:flutter/material.dart';

import '../gsshop_live/gsshop_live_controls.dart';
import '../cupertino/cupertino_controls.dart';
import '../material/material_controls.dart';
import '../../src/chewie_player.dart';

class AdaptiveControls extends StatelessWidget {
  const AdaptiveControls({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var chewieController = ChewieController.of(context);
    switch (chewieController.playerType) {
      case PlayerType.cupertino:
        return const CupertinoControls(
          backgroundColor: Color.fromRGBO(41, 41, 41, 0.7),
          iconColor: Color.fromARGB(255, 200, 200, 200),
        );
      case PlayerType.material:
        return const MaterialControls();
      default:
        return const GsshopLiveControls();
    }
  }
}
