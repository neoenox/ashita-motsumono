import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/entities.dart';
import 'app_settings.dart';
import 'document_intake_service.dart';
import 'extraction_service.dart';
import 'gemini_api_service.dart';
import 'image_file_service.dart';
import 'ocr_service.dart';
import 'verified_entitlement_cache.dart';

sealed class OcrPickResult {}

class OcrPickSuccess extends OcrPickResult {
  OcrPickSuccess({required this.document, required this.drafts});
  final DocumentRecord document;
  final List<ExtractionDraft> drafts;
}

/// AI解析のみ成功し、まだDocumentRecordとして永続化していない結果。
/// 永続化は呼び出し側がドラフト確認後に明示的に行うため、
/// 空IDのダミードキュメントではなく専用型で返す。
class OcrPickAiSuccess extends OcrPickResult {
  OcrPickAiSuccess({
    required this.imagePath,
    required this.ocrText,
    required this.drafts,
  });

  final String imagePath;
  final String ocrText;
  final List<ExtractionDraft> drafts;
}

class OcrPickEmpty extends OcrPickResult {}

class OcrPickDuplicate extends OcrPickResult {
  OcrPickDuplicate({required this.existingDocumentId});

  final String existingDocumentId;
}

class OcrPickNoCandidates extends OcrPickResult {
  OcrPickNoCandidates({required this.document, required this.ocrText});

  final DocumentRecord document;
  final String ocrText;
}

class OcrPickError extends OcrPickResult {
  OcrPickError(this.message);

  final String message;
}

@visibleForTesting
OcrPickResult ocrPickResultFromIntakeResult(IntakeResult result) {
  return switch (result) {
    IntakeSuccess(document: final document, drafts: final drafts) =>
      OcrPickSuccess(document: document, drafts: drafts),
    IntakeDuplicate(existingDocumentId: final existingDocumentId) =>
      OcrPickDuplicate(existingDocumentId: existingDocumentId),
    IntakeNoCandidates(document: final document, ocrText: final ocrText) =>
      OcrPickNoCandidates(document: document, ocrText: ocrText),
    IntakeEmpty() => OcrPickEmpty(),
    IntakeError(message: final message) => OcrPickError(message),
  };
}

class OcrPickService {
  OcrPickService({
    required AppState appState,
    required AppSettings appSettings,
    ImagePicker? picker,
    ImageFileService? imageFileService,
    OcrService? ocrService,
    DocumentIntakeService? documentIntakeService,
  }) : _appState = appState,
       _appSettings = appSettings,
       _picker = picker ?? ImagePicker(),
       _imageFileService = imageFileService ?? ImageFileService(),
       _ocrService = ocrService ?? OcrService(),
       _documentIntakeService =
           documentIntakeService ??
           DocumentIntakeService(
             appState: appState,
             appSettings: appSettings,
             ocrService: ocrService,
             imageFileService: imageFileService,
           );

  final AppState _appState;
  final AppSettings _appSettings;
  final ImagePicker _picker;
  final ImageFileService _imageFileService;
  final OcrService _ocrService;
  final DocumentIntakeService _documentIntakeService;
  GeminiApiService? _geminiService;

  void setGeminiProxyUrl(String url) {
    _geminiService = GeminiApiService(proxyUrl: url);
  }

  Future<OcrPickResult?> pickAndProcess(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;
    return processPickedImage(picked, source: source);
  }

  Future<List<XFile>> pickMultipleImageFiles() {
    return _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
  }

  Future<OcrPickResult?> pickMultipleImages({
    IntakeProgressCallback? onProgress,
    IntakeCancellationToken? cancellationToken,
  }) async {
    final picked = await pickMultipleImageFiles();
    if (picked.isEmpty) return null;
    return processPickedImages(
      picked,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<OcrPickResult> processPickedImages(
    List<XFile> picked, {
    IntakeProgressCallback? onProgress,
    IntakeCancellationToken? cancellationToken,
  }) async {
    if (picked.isEmpty) {
      throw ArgumentError.value(picked, 'picked', '1件以上の画像が必要です');
    }

    if (picked.length == 1) {
      return processPickedImage(picked.single);
    }

    final result = await _documentIntakeService.importImages(
      sourcePaths: picked.map((file) => file.path).toList(growable: false),
      sourceType: 'gallery',
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    return ocrPickResultFromIntakeResult(result);
  }

  Future<OcrPickResult> processPickedImage(
    XFile picked, {
    ImageSource source = ImageSource.gallery,
  }) {
    return _processLocalImage(picked, source);
  }

  Future<OcrPickResult?> recoverLostImage() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) {
      throw OcrException('中断された画像選択を復旧できませんでした。', cause: response.exception);
    }
    final files = response.files;
    if (files == null || files.isEmpty) return null;
    return _processLocalImage(files.first, ImageSource.gallery);
  }

  Future<OcrPickResult> _processLocalImage(
    XFile picked,
    ImageSource source,
  ) async {
    if (await picked.length() > ImageFileService.maxImageBytes) {
      throw const OcrException('画像サイズが大きすぎます。5MB以下の画像を選択してください。');
    }
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

  Future<OcrPickResult?> pickAndProcessWithAi(
    String proxyUrl, {
    String? accessToken,
  }) async {
    final verifiedToken =
        accessToken ?? await VerifiedEntitlementCache.getAiToken();
    if (verifiedToken == null) {
      throw const OcrException('AI分析の購入情報を確認できませんでした。購入情報を復元してください。');
    }
    final gemini = _geminiService ?? GeminiApiService(proxyUrl: proxyUrl);
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;
    if (await picked.length() > ImageFileService.maxImageBytes) {
      throw const OcrException('画像サイズが大きすぎます。5MB以下の画像を選択してください。');
    }
    final imageFile = await _imageFileService.copyFromXFile(picked);
    try {
      final result = await gemini.analyzeImage(
        imageFile,
        accessToken: verifiedToken,
      );
      switch (result) {
        case GeminiSuccess(drafts: final drafts):
          return OcrPickAiSuccess(
            imagePath: imageFile.path,
            ocrText: 'AI分析\n${drafts.map((draft) => draft.title).join('\n')}',
            drafts: drafts,
          );
        case GeminiEmpty():
          await ImageFileService.deleteIfExists(imageFile.path);
          return OcrPickEmpty();
        case GeminiError(message: final message):
          throw OcrException(message);
      }
    } on Object {
      await ImageFileService.deleteIfExists(imageFile.path);
      rethrow;
    }
  }
}
