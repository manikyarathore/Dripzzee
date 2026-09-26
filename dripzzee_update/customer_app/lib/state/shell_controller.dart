import 'package:flutter/foundation.dart';

enum ShellTab { home, search, saved, orders }

/// Lets any screen switch the bottom-navigation tab.
class ShellController extends ChangeNotifier {
  ShellTab _tab = ShellTab.home;
  ShellTab get tab => _tab;

  void goTo(ShellTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }
}
