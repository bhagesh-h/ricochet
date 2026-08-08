/// Motion timing placeholders — tune in one place after design review.
abstract final class AiMotionTokens {
  static const testConnectionMinSuccess = Duration(milliseconds: 400);
  static const progressStepMin = Duration(milliseconds: 300);
  static const ghostNodeStagger = Duration(milliseconds: 80);
  static const panelSlide = Duration(milliseconds: 280);
  static const latencyThresholdSlow = Duration(seconds: 3);
  static const latencyThresholdVerySlow = Duration(seconds: 10);
}
