class OverlayService {
  OverlayService._();
  static final instance = OverlayService._();

  Future<void> show() async {
    // start overlay if needed
  }

  Future<void> react(String tag) async {
    // map tag to your overlay action (dance/eat/sleep)
  }
}

Future<void> triggerReaction(String tag) => OverlayService.instance.react(tag);
