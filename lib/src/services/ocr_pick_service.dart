// lib/src/services/ocr_pick_service.dart
// 画像選択・OCR認識・文書保存・抽出候補生成を統括するサービス。
// AddTodoScreen._pickAndOcr からOCR関連ロジックを分離するために作成。
// 関連: services/ocr_service.dart, services/extraction_service.dart,
//       services/image_file_service.dart, screens/add_todo_screen.dart

import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/entities.dart';
import 'app_settings.dart';
import 'extraction_service.dart';
import 'gemini_api_service.dart';
import 'image_file_service.dart';
import 'ocr_service.dart';

/// OCRピック処理の結果
sealed class OcrPickResult {}

/// OCR成功: 文書と抽出候補を含む
class OcrPickSuccess extends OcrPickResult {
  OcrPickSuccess({required this.document, required this.drafts});

  final DocumentRecord document;
  final List<ExtractionDraft> drafts;
}

/// OCR結果が空文字だった
class OcrPickEmpty extends OcrPickResult {}

/// 画像選択・OCR認識・文書保存・抽出候補生成を統括するサービス。
///
/// スクリーンはこのサービスを呼び出し、結果に応じてナビゲーションとエラー表示だけを行う。
class OcrPickService {
  OcrPickService({
    required AppState appState,
    required AppSettings appSettings,
    ImagePicker? picker,
    ImageFileService? imageFileService,
    OcrService? ocrService,
  }) : _appState = appState,
       _appSettings = appSettings,
       _picker = picker ?? ImagePicker(),
       _imageFileService = imageFileService ?? ImageFileService(),
       _ocrService = ocrService ?? OcrService();

  final AppState _appState;
  final AppSettings _appSettings;
  final ImagePicker _picker;
  final ImageFileService _imageFileService;
  final OcrService _ocrService;
  GeminiApiService? _geminiService;

  void setGeminiProxyUrl(String url) {
    _geminiService = GeminiApiService(proxyUrl: url);
  }

  /// 画像を選択し、OCR認識・文書保存・抽出を実行する。
  ///
  /// 戻り値:
  /// - ユーザーが選択をキャンセル → `null`
  /// - OCRテキストが空 → `OcrPickEmpty`
  /// - 成功 → `OcrPickSuccess`
  /// - OCRエラー → `OcrException` をスロー
  Future<OcrPickResult?> pickAndProcess(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 92);
    if (picked == null) return null;

    final imageFile = await _imageFileService.copyFromXFile(picked);
    try {
      final ocrText = await _ocrService.recognize(imageFile);
      if (ocrText.trim().isEmpty) {
        await ImageFileService.deleteIfExists(imageFile.path);
        return OcrPickEmpty();
      }

      final document = await _appState.addDocument(
        sourceType: source == ImageSource.camera ? 'camera' : 'gallery',
        localImagePath: imageFile.path,
        ocrText: ocrText,
      );

      final drafts = ExtractionService.extractMany(
        ocrText,
        learnedItemLabels: _appSettings.learnedItemLabels,
      );

      return OcrPickSuccess(document: document, drafts: drafts);
    } on Object {
      await ImageFileService.deleteIfExists(imageFile.path);
      rethrow;
    }
  }

  /// 画像を選択し、Gemini API で解析して構造化 Todo を抽出する。
  ///
  /// [proxyUrl] には Cloudflare Workers プロキシの URL を指定する。
  /// 戻り値は [pickAndProcess] と同様。
  Future<OcrPickResult?> pickAndProcessWithAi(String proxyUrl) async {
    final gemini = _geminiService ?? GeminiApiService(proxyUrl: proxyUrl);
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (picked == null) return null;

    final imageFile = await _imageFileService.copyFromXFile(picked);
    try {
      final result = await gemini.analyzeImage(imageFile);

      final now = DateTime.now();
      return switch (result) {
        GeminiSuccess(drafts: final drafts) => OcrPickSuccess(
          document: DocumentRecord(
            id: '',
            sourceType: 'camera',
            ocrText: 'AI分析\n${drafts.map((d) => d.title).join('\n')}',
            createdAt: now,
            updatedAt: now,
          ),
          drafts: drafts,
        ),
        GeminiEmpty() => OcrPickEmpty(),
        GeminiError(message: final msg) => throw OcrException(msg),
      };
    } on Object {
      await ImageFileService.deleteIfExists(imageFile.path);
      rethrow;
    }
  }
}
