import 'package:flutter/foundation.dart';

class HomeNavigationProvider extends ChangeNotifier {
  int? _requestedTab;

  int? get requestedTab => _requestedTab;

  void requestTab(int tabIndex) {
    _requestedTab = tabIndex;
    notifyListeners();
  }

  void clearRequest() {
    if (_requestedTab == null) return;
    _requestedTab = null;
    notifyListeners();
  }
}
