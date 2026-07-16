import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/entities.dart';
import 'app_settings.dart';
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

class OcrPickEmpty extends OcrPickResult {}

class OcrPickService {
  OcrPickService({
    required AppState appState,
    required AppSettings appSettings,
    ImagePicker? picker,
    ImageFileService? imageFileService,
    OcrService? ocrService,
  })  : _appState = appState,
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

  Future<OcrPickResult?> pickAndProcess(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;
    return _processLocalImage(picked, source);
  }

  Future<OcrPickResult?> recoverLostImage() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) {
      throw OcrException(
        '中断された画像選択を復旧できませんでした。',
        cause: response.exception,
      );
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
    final verifiedToken = accessToken ?? await VerifiedEntitlementCache.getAiToken();
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
      final now = DateTime.now();
      switch (result) {
        case GeminiSuccess(drafts: final drafts):
          return OcrPickSuccess(
            document: DocumentRecord(
              id: '',
              sourceType: 'camera',
              localImagePath: imageFile.path,
              ocrText: 'AI分析\n${drafts.map((draft) => draft.title).join('\n')}',
              createdAt: now,
              updatedAt: now,
            ),
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
