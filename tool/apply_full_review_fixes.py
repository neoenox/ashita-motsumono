from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    if old in content:
        content = content.replace(old, new, 1)
        write(path, content)
        return
    if new in content:
        return
    raise RuntimeError(f"{path}: expected text was not found")


def replace_regex(path: str, pattern: str, replacement: str) -> None:
    content = read(path)
    updated, count = re.subn(pattern, lambda _: replacement, content, count=1, flags=re.S)
    if count == 1:
        write(path, updated)
        return
    if replacement in content:
        return
    raise RuntimeError(f"{path}: expected pattern was not found")


# Release artifacts must never be produced from an unvalidated or non-master ref.
replace_once(
    ".github/workflows/ci.yml",
    """  release-build:
    if: startsWith(github.ref, 'refs/tags/v') || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
""",
    """  release-build:
    needs: analyze-and-test
    if: >-
      needs.analyze-and-test.result == 'success' &&
      (
        startsWith(github.ref, 'refs/tags/v') ||
        (
          github.event_name == 'workflow_dispatch' &&
          github.ref == 'refs/heads/master'
        )
      )
    runs-on: ubuntu-latest
""",
)

# Post-delete cleanup must only cancel the todos captured by the delete operation.
replace_once(
    "lib/src/app_state_cleanup.dart",
    "        final cleanup = _runPostDeleteCleanup();\n",
    """        final cleanup = _runPostDeleteCleanup(
          todosToCancel.map((todo) => todo.id).toList(growable: false),
        );
""",
)
replace_once(
    "lib/src/app_state_cleanup.dart",
    """  Future<void> _runPostDeleteCleanup() async {
    await _runPostDeleteBestEffort(
      'notification cancellation',
      () => _notificationCoordinator.retryPending(const <AppTodo>[]),
    );
""",
    """  Future<void> _runPostDeleteCleanup(Iterable<String> todoIds) async {
    await _runPostDeleteBestEffort(
      'notification cancellation',
      () async {
        for (final todoId in todoIds) {
          await _notificationCoordinator.executeCanceledTodo(todoId);
        }
      },
    );
""",
)

# Preserve SQLite sidecar files when creating a corruption backup.
replace_regex(
    "lib/src/repositories/app_database.dart",
    r"""  Future<String\?> backupDatabaseFile\(\) async \{.*?\n  \}\n\n  Future<AppSnapshot> loadSnapshot\(\) async \{""",
    """  Future<String?> backupDatabaseFile() async {
    final source = databaseFile;
    if (source == null || !await source.exists()) return null;

    try {
      await customStatement('PRAGMA wal_checkpoint(FULL)');
    } on Object {
      // 破損時はcheckpointできない場合があるため、現存ファイルの退避を続行する。
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final backupBasePath = p.join(
      source.parent.path,
      'ashita_motsumono_corrupt_$stamp.db',
    );
    final copiedPaths = await backupDatabaseFilesAtPath(
      source.path,
      backupBasePath,
    );
    if (copiedPaths.isEmpty) return null;
    return copiedPaths.join('\\n');
  }

  @visibleForTesting
  static Future<List<String>> backupDatabaseFilesAtPath(
    String sourcePath,
    String backupBasePath,
  ) async {
    final copiedPaths = <String>[];
    for (final suffix in _databaseSuffixes) {
      final source = File('$sourcePath$suffix');
      if (!await source.exists()) continue;
      final destination = File('$backupBasePath$suffix');
      await source.copy(destination.path);
      copiedPaths.add(destination.path);
    }
    return copiedPaths;
  }

  Future<AppSnapshot> loadSnapshot() async {""",
)

replace_once(
    "lib/src/services/sensitive_data_cleaner.dart",
    """    r'^(crash(?:\\.previous)?\\.log|ashita_motsumono_(?:legacy_backup_.*\\.json|corrupt_.*\\.db))$',
""",
    """    r'^(crash(?:\\.previous)?\\.log|ashita_motsumono_(?:legacy_backup_.*\\.json|corrupt_.*\\.db(?:-(?:wal|shm|journal))?))$',
""",
)

# Serialize purchase stream processing.
replace_once(
    "lib/src/services/purchase_provider.dart",
    "import 'verified_entitlement_cache.dart';\n",
    """import 'verified_entitlement_cache.dart';
import '../utils/async_mutex.dart';
""",
)
replace_once(
    "lib/src/services/purchase_provider.dart",
    "  Future<String?>? _pendingTokenFetch;\n",
    """  Future<String?>? _pendingTokenFetch;
  final AsyncMutex _purchaseEventMutex = AsyncMutex();
""",
)
replace_once(
    "lib/src/services/purchase_provider.dart",
    """      _subscription = _purchase.purchaseStream.listen(
        (details) => unawaited(_processPurchases(details)),
""",
    """      _subscription = _purchase.purchaseStream.listen(
        _enqueuePurchases,
""",
)
replace_once(
    "lib/src/services/purchase_provider.dart",
    """  Future<void> _processPurchases(List<PurchaseDetails> details) async {
""",
    """  void _enqueuePurchases(List<PurchaseDetails> details) {
    unawaited(
      _purchaseEventMutex
          .protect(() => _processPurchases(details))
          .catchError((Object error, StackTrace stackTrace) {
        _statusMessage = '購入情報の処理に失敗しました。時間をおいてもう一度お試しください。';
        notifyListeners();
        if (kDebugMode) {
          debugPrint(
            'PurchaseProvider: queued processing failed - '
            '$error\\n$stackTrace',
          );
        }
      }),
    );
  }

  Future<void> _processPurchases(List<PurchaseDetails> details) async {
""",
)

# Dispose purchase subscriptions whenever bootstrap dependencies are replaced.
replace_once(
    "lib/src/bootstrap_app.dart",
    """    } on Object catch (error, stackTrace) {
      createdState?.dispose();
      _clearDependencies();
      _fatalError = error;
""",
    """    } on Object catch (error, stackTrace) {
      final purchaseProvider = _purchaseProvider;
      _clearDependencies();
      purchaseProvider?.dispose();
      createdState?.dispose();
      _fatalError = error;
""",
)
replace_once(
    "lib/src/bootstrap_app.dart",
    """  Future<void> _restartBootstrap() async {
    final previousState = _appState;
    _clearDependencies();
    if (previousState != null) {
      await previousState.close();
      previousState.dispose();
    }
    await _initializeFresh();
  }
""",
    """  Future<void> _restartBootstrap() async {
    final previousState = _appState;
    final previousPurchaseProvider = _purchaseProvider;
    _clearDependencies();
    previousPurchaseProvider?.dispose();
    if (previousState != null) {
      await previousState.close();
      previousState.dispose();
    }
    await _initializeFresh();
  }
""",
)
replace_once(
    "lib/src/bootstrap_app.dart",
    """  @override
  void dispose() {
    _appState?.dispose();
    super.dispose();
  }
""",
    """  @override
  void dispose() {
    _purchaseProvider?.dispose();
    _appState?.dispose();
    super.dispose();
  }
""",
)

# Reject malformed or structurally invalid entitlement tokens without throwing.
replace_regex(
    "workers/gemini-proxy/src/index.ts",
    r"""async function verifyEntitlementToken\(.*?\n\}\n\nasync function signRs256Jwt""",
    """async function verifyEntitlementToken(
  token: string,
  secret: string,
): Promise<EntitlementPayload | null> {
  try {
    if (!secret) return null;
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const header = decodeBase64UrlJson(parts[0]);
    if (
      !isRecord(header) ||
      header.alg !== 'HS256' ||
      header.typ !== 'JWT'
    ) {
      return null;
    }

    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify(
      'HMAC',
      key,
      base64UrlDecode(parts[2]),
      encoder.encode(`${parts[0]}.${parts[1]}`),
    );
    if (!valid) return null;

    const payload = decodeBase64UrlJson(parts[1]);
    if (!isEntitlementPayload(payload)) return null;

    const now = Math.floor(Date.now() / 1000);
    if (
      payload.exp <= now ||
      payload.iat > now + 60 ||
      payload.exp <= payload.iat ||
      payload.exp - payload.iat > TOKEN_TTL_SECONDS
    ) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isEntitlementPayload(value: unknown): value is EntitlementPayload {
  if (!isRecord(value)) return false;
  return (
    typeof value.productId === 'string' &&
    value.productId.length > 0 &&
    (value.platform === 'android' || value.platform === 'ios') &&
    typeof value.receiptHash === 'string' &&
    /^[a-f0-9]{64}$/.test(value.receiptHash) &&
    typeof value.iat === 'number' &&
    Number.isInteger(value.iat) &&
    typeof value.exp === 'number' &&
    Number.isInteger(value.exp)
  );
}

async function signRs256Jwt""",
)

# Ensure OCR-owned files/documents are cleaned up if the initiating screen disappears.
replace_once(
    "lib/src/screens/add_todo_screen.dart",
    "import '../services/gemini_api_service.dart';\n",
    """import '../services/gemini_api_service.dart';
import '../services/image_file_service.dart';
""",
)
replace_regex(
    "lib/src/screens/add_todo_screen.dart",
    r"""  Future<void> _pickAndOcr\(ImageSource source\) async \{.*?\n  \}\n\n  Future<void> _pickAndOcrWithAi\(\) async \{.*?\n  \}\n\n  void _showOcrError""",
    """  Future<void> _pickAndOcr(ImageSource source) async {
    setState(() => _busy = true);
    final appState = context.read<AppState>();
    OcrPickSuccess? pendingSuccess;
    var handedOff = false;
    try {
      final service = OcrPickService(
        appState: appState,
        appSettings: context.read<AppSettings>(),
      );
      final result = await service.pickAndProcess(source);
      if (result == null) return;
      if (result case OcrPickSuccess()) pendingSuccess = result;
      if (!mounted) return;
      switch (result) {
        case OcrPickEmpty():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文字を読み取れませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
            ),
          );
        case OcrPickSuccess():
          if (result.drafts.isEmpty) {
            await appState.deleteDocument(result.document.id);
            pendingSuccess = null;
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Todo情報を抽出できませんでした。手入力で登録してください。')),
            );
            return;
          }
          handedOff = true;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => _reviewScreenFor(
                drafts: result.drafts,
                documentId: result.document.id,
              ),
            ),
          );
      }
    } on OcrException catch (e) {
      if (kDebugMode) debugPrint('OCR error: ${e.cause ?? e}');
      _showOcrError(e.message);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('OCR error: $e');
      _showOcrError('読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (!handedOff && pendingSuccess != null) {
        await _cleanupAbandonedOcrResult(appState, pendingSuccess!);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndOcrWithAi() async {
    setState(() => _busy = true);
    final appState = context.read<AppState>();
    OcrPickSuccess? pendingSuccess;
    String? persistedDocumentId;
    var handedOff = false;
    try {
      final service = OcrPickService(
        appState: appState,
        appSettings: context.read<AppSettings>(),
      );
      final proxyUrl =
          GeminiApiService.defaultInstance().proxyUrl ?? '';
      final result = await service.pickAndProcessWithAi(proxyUrl);
      if (result == null) return;
      if (result case OcrPickSuccess()) pendingSuccess = result;
      if (!mounted) return;
      switch (result) {
        case OcrPickEmpty():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todo情報を抽出できませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
            ),
          );
        case OcrPickSuccess(document: final doc, drafts: final drafts):
          final document = await appState.addDocument(
            sourceType: 'camera',
            localImagePath: doc.localImagePath ?? '',
            ocrText: doc.ocrText,
          );
          persistedDocumentId = document.id;
          pendingSuccess = null;
          if (!mounted) return;
          handedOff = true;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  _reviewScreenFor(drafts: drafts, documentId: document.id),
            ),
          );
      }
    } on OcrException catch (e) {
      if (kDebugMode) debugPrint('Gemini error: ${e.cause ?? e}');
      _showOcrError(e.message);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Gemini error: $e');
      _showOcrError('AI解析に失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (!handedOff) {
        if (persistedDocumentId != null) {
          try {
            await appState.deleteDocument(persistedDocumentId);
          } on Object catch (error, stackTrace) {
            if (kDebugMode) {
              debugPrint(
                'Failed to clean up abandoned AI document: '
                '$error\\n$stackTrace',
              );
            }
          }
        } else if (pendingSuccess != null) {
          await _cleanupAbandonedOcrResult(appState, pendingSuccess!);
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanupAbandonedOcrResult(
    AppState appState,
    OcrPickSuccess result,
  ) async {
    try {
      final document = result.document;
      if (document.id.isNotEmpty) {
        await appState.deleteDocument(document.id);
        return;
      }
      final path = document.localImagePath;
      if (path != null && path.isNotEmpty) {
        await ImageFileService.deleteIfExists(path);
      }
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Failed to clean up abandoned OCR result: '
          '$error\\n$stackTrace',
        );
      }
    }
  }

  void _showOcrError""",
)

# Prefer dates adjacent to deadline language and reject class/room notation as dates.
replace_once(
    "lib/src/services/date_extractor.dart",
    """  static final _slashDatePattern = RegExp(
    r'(?<!\\d)(\\d{1,2})\\s*[/\\-]\\s*(\\d{1,2})(?!\\d)',
  );
""",
    """  static final _slashDatePattern = RegExp(
    r'(?<![\\d第])(\\d{1,2})\\s*[/\\-]\\s*(\\d{1,2})(?!\\s*(?:組|教室|回|番|\\d))',
  );
""",
)
replace_once(
    "lib/src/services/date_extractor.dart",
    """  static final _ambiguousDeadlinePattern = RegExp(
    r'(今月末|月末|始業式の日|終業式の日|入学式の日|卒園式の日|卒業式の日|運動会の日|遠足の日)',
  );
""",
    """  static final _ambiguousDeadlinePattern = RegExp(
    r'(今月末|月末|始業式の日|終業式の日|入学式の日|卒園式の日|卒業式の日|運動会の日|遠足の日)',
  );
  static final _deadlineKeywordPattern = RegExp(
    r'(提出期限|提出日|持参日|締切|期限|まで)',
  );
""",
)
replace_once(
    "lib/src/services/date_extractor.dart",
    """  static DateTime? extract(String text, DateTime now) {
    DateTime? result = _extractRelativeDate(text, now);
""",
    """  static DateTime? extract(String text, DateTime now) {
    DateTime? result = _extractDeadlineDate(text, now);
    result ??= _extractRelativeDate(text, now);
""",
)
replace_once(
    "lib/src/services/date_extractor.dart",
    """  static bool hasAmbiguousDeadline(String text) {
""",
    """  static DateTime? _extractDeadlineDate(String text, DateTime now) {
    for (final keyword in _deadlineKeywordPattern.allMatches(text)) {
      final start = keyword.start > 24 ? keyword.start - 24 : 0;
      final end = keyword.end + 24 < text.length
          ? keyword.end + 24
          : text.length;
      final window = text.substring(start, end);
      DateTime? result = _extractConcreteDate(window);
      result ??= _extractMonthDayDate(window, now);
      result ??= _extractSlashDate(window, now);
      result ??= _extractRelativeDate(window, now);
      result ??= _extractRelativeWeekday(window, now);
      if (result != null) return result;
    }
    return null;
  }

  static bool hasAmbiguousDeadline(String text) {
""",
)

# Keep recently learned labels when the 100-item cap is reached.
replace_once(
    "lib/src/services/app_settings.dart",
    """    final merged = <String>{
      ..._learnedItemLabels,
      ...labels.map((label) => label.trim()).where(_isUsefulItemLabel),
    }.take(100).toList(growable: false);
""",
    """    final incoming = labels
        .map((label) => label.trim())
        .where(_isUsefulItemLabel);
    final merged = <String>{
      ...incoming,
      ..._learnedItemLabels,
    }.take(100).toList(growable: false);
""",
)

write(
    "test/full_review_regression_test.dart",
    r"""import 'dart:io';

import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/date_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deadline date wins over distribution date', () {
    final result = DateExtractor.extract(
      '本日配布しました。提出期限は2026年7月25日です。',
      DateTime(2026, 7, 18),
    );
    expect(result, DateTime(2026, 7, 25));
  });

  test('class notation is not treated as a slash date', () {
    final result = DateExtractor.extract(
      '1-2組は水筒を持参してください。',
      DateTime(2026, 7, 18),
    );
    expect(result, isNull);
  });

  test('new learned labels are retained at the 100 item cap', () async {
    SharedPreferences.setMockInitialValues({
      'learned_item_labels_v1': [
        for (var index = 0; index < 100; index++) '既存$index',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);

    await settings.addLearnedItemLabels(const ['新しい持ち物']);

    expect(settings.learnedItemLabels, hasLength(100));
    expect(settings.learnedItemLabels.first, '新しい持ち物');
    expect(settings.learnedItemLabels, isNot(contains('既存99')));
  });

  test('corrupt database backup includes SQLite sidecars', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ashita_database_backup_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final source = '${directory.path}/ashita_motsumono.db';
    final backup = '${directory.path}/ashita_motsumono_corrupt.db';
    await File(source).writeAsString('db');
    await File('$source-wal').writeAsString('wal');
    await File('$source-shm').writeAsString('shm');

    final copied = await AppDatabase.backupDatabaseFilesAtPath(source, backup);

    expect(copied, containsAll([backup, '$backup-wal', '$backup-shm']));
    expect(await File('$backup-wal').readAsString(), 'wal');
    expect(await File('$backup-shm').readAsString(), 'shm');
  });

  test('release build depends on successful validation and master dispatch', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    expect(workflow, contains('needs: analyze-and-test'));
    expect(
      workflow,
      contains("github.ref == 'refs/heads/master'"),
    );
    expect(
      workflow,
      contains("needs.analyze-and-test.result == 'success'"),
    );
  });

  test('worker rejects malformed entitlement payloads defensively', () {
    final worker = File(
      'workers/gemini-proxy/src/index.ts',
    ).readAsStringSync();
    expect(worker, contains('function isEntitlementPayload'));
    expect(worker, contains("header.alg !== 'HS256'"));
    expect(worker, contains('} catch {\n    return null;'));
  });

  test('post-delete cleanup cancels only captured todo ids', () {
    final source = File(
      'lib/src/app_state_cleanup.dart',
    ).readAsStringSync();
    expect(source, contains('executeCanceledTodo(todoId)'));
    expect(
      source,
      isNot(contains('retryPending(const <AppTodo>[])')),
    );
  });
}
""",
)

(ROOT / ".review-fixes-applied").write_text(
    "Applied by tool/apply_full_review_fixes.py\n",
    encoding="utf-8",
)
