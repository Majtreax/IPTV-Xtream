import 'package:flutter/material.dart';
import 'package:iptv_xtream/app/theme.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(color: kAccentPurple, strokeWidth: 3),
      ),
    );
  }
}
