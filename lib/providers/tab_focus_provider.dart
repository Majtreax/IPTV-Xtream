import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabFocusController {
  final List<FocusNode> tabNodes;

  TabFocusController({
    required this.tabNodes,
  });

  void focusTab(int index) {
    if (index >= 0 && index < tabNodes.length) {
      tabNodes[index].requestFocus();
    }
  }
}

final tabFocusControllerProvider =
    StateProvider<TabFocusController?>((ref) => null);
