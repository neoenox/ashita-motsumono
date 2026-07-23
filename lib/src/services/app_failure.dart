// lib/src/services/app_failure.dart
// アプリ内のエラーを分類するsealed class
// なぜ存在するか: エラー発生時にユーザーに適切なアクションを提示するため
// 関連ファイル: ocr_service.dart, notification_service.dart, purchase_provider.dart

/// アプリ内で発生するエラーの分類
sealed class AppFailure {
  const AppFailure();

  /// エラーに応じたユーザー向けメッセージ
  String get userMessage;

  /// エラーに応じた推奨アクション
  String? get suggestedAction;
}

/// OCR処理失敗
class OcrFailure extends AppFailure {
  const OcrFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String get userMessage => 'テキストの読み取りに失敗しました';

  @override
  String get suggestedAction => '別の画像を選択するか、手動で入力してください';
}

/// カメラ/写真アクセス権限拒否
class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({required this.permissionType});

  final String permissionType;

  @override
  String get userMessage => '$permissionTypeの権限が拒否されました';

  @override
  String get suggestedAction => '設定から権限を許可してください';
}

/// DB保存失敗
class DatabaseFailure extends AppFailure {
  const DatabaseFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String get userMessage => 'データの保存に失敗しました';

  @override
  String get suggestedAction => '入力内容を維持して再試行してください';
}

/// 通知スケジュール失敗
class NotificationScheduleFailure extends AppFailure {
  const NotificationScheduleFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String get userMessage => '通知の設定に失敗しました';

  @override
  String get suggestedAction => '通知なしでもアプリは利用できます';
}

/// 課金接続失敗
class BillingUnavailableFailure extends AppFailure {
  const BillingUnavailableFailure({this.cause});

  final Object? cause;

  @override
  String get userMessage => '課金サービスに接続できません';

  @override
  String get suggestedAction => '後で再試行してください。アプリ本体は利用可能です';
}

/// 購入保留中
class PurchasePendingFailure extends AppFailure {
  const PurchasePendingFailure();

  @override
  String get userMessage => '決済を確認中です';

  @override
  String get suggestedAction => 'しばらくお待ちください';
}

/// ネットワークエラー
class NetworkFailure extends AppFailure {
  const NetworkFailure({this.cause});

  final Object? cause;

  @override
  String get userMessage => 'ネットワークに接続できません';

  @override
  String get suggestedAction => '接続を確認して再試行してください';
}

/// 画像読み込み失敗
class ImageReadFailure extends AppFailure {
  const ImageReadFailure({required this.path, this.cause});

  final String path;
  final Object? cause;

  @override
  String get userMessage => '画像を読み込めませんでした';

  @override
  String get suggestedAction => '別の画像を選択してください';
}

/// Gemini APIエラー
class GeminiApiFailure extends AppFailure {
  const GeminiApiFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String get userMessage => 'AI解析に失敗しました';

  @override
  String get suggestedAction => '手動で入力するか、再試行してください';
}

/// 一般的な予期しないエラー
class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String get userMessage => '予期しないエラーが発生しました';

  @override
  String get suggestedAction => 'アプリを再起動してください';
}
