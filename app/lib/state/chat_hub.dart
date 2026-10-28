import 'package:flutter/foundation.dart';

import 'group_chat.dart';
import 'session.dart';

/// Keeps the user's city group connected for the whole session, so the chat opens instantly
/// and the tab badge counts new messages live.
class ChatHub extends ChangeNotifier {
  ChatHub._();
  static final instance = ChatHub._();

  GroupChat? group;

  String? get city => AppSession.instance.profile?.chatCity;

  void sync() {
    final c = city;
    if (group?.city == c) return;
    group?.removeListener(notifyListeners);
    group?.dispose();
    group = null;
    if (c != null) {
      group = GroupChat(c)..addListener(notifyListeners);
      group!.start();
    }
    notifyListeners();
  }

  Future<void> setCity(String c) async {
    await AppSession.instance.updateProfile({'chat_city': c});
    sync();
  }

  void stop() {
    group?.removeListener(notifyListeners);
    group?.dispose();
    group = null;
  }
}
