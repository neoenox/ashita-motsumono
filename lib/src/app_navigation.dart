// lib/src/app_navigation.dart
// プラットフォームごとの標準操作感を保った画面遷移を提供する。

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 現在のプラットフォームに適したページルートを生成する。
///
/// [Navigator.pushReplacement] のスタック動作を維持する箇所でも同じ判定を
/// 再利用できるよう、ルート生成を分離している。
PageRoute<T> adaptivePageRoute<T>(
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
      );
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return MaterialPageRoute<T>(
        builder: builder,
        fullscreenDialog: fullscreenDialog,
      );
  }
}

Future<T?> pushAdaptive<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  return Navigator.of(
    context,
  ).push<T>(adaptivePageRoute<T>(builder, fullscreenDialog: fullscreenDialog));
}
