import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'router.dart';
import 'theme.dart';

class MyOSApp extends StatelessWidget {
  const MyOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The system bars share the canvas colour so the workspace reads as one
    // continuous surface rather than a card floating in an OS chrome.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MyOSTheme.systemUi,
      child: MaterialApp.router(
        title: 'MyOS',
        debugShowCheckedModeBanner: false,
        theme: MyOSTheme.dark,
        routerConfig: router,
        builder: (context, child) {
          // Clamp text scaling: the dashboard is a dense ledger and a 1.3x
          // system scale breaks the fixed-height rows.
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: scale.clamp(1.0, 1.2),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
