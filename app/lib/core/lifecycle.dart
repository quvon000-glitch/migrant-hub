import 'package:flutter/widgets.dart';

/// Re-runs a callback when the app returns to the foreground after a while in the background.
mixin WidgetsBindingObserverMixin {
  _LifecycleHook? _hook;

  void bindLifecycle({required VoidCallback onResume}) {
    _hook ??= _LifecycleHook(onResume)..attach();
  }

  void unbindLifecycle() {
    _hook?.detach();
    _hook = null;
  }
}

class _LifecycleHook with WidgetsBindingObserver {
  _LifecycleHook(this.onResume);
  final VoidCallback onResume;
  DateTime _pausedAt = DateTime.now();

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && DateTime.now().difference(_pausedAt).inSeconds > 15) onResume();
  }
}
