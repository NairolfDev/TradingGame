import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

extension MotionSafe on Widget {
  /// Like `.animate()`, but honors the system "reduce motion" setting by
  /// jumping straight to the end state (Apple: make motion optional).
  Animate motionSafe(BuildContext context, {List<Effect>? effects}) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return animate(
      effects: effects,
      autoPlay: !reduce,
      value: reduce ? 1.0 : null,
    );
  }
}
