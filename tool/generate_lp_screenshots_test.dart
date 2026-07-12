// tool/generate_lp_screenshots_test.dart
// LP掲載用の実画面スクリーンショットを、実アプリWidgetとダミーデータから生成する。

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ashita_motsumono/main.dart';
import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/screens/review_extraction_screen.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/theme/app_theme.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _outputDirectory = 'build/lp-screenshots';
const _viewportPhysicalSize = Size(1080, 1920);
const _devicePixelRatio = 3.0;
const _captureKey = ValueKey<String>('lp-screenshot-boundary');
const _requiredFontFamilies = <String>{'NotoSansJP', 'MaterialIcons'};

class _TestPurchaseProvider extends PurchaseProvider {
  _TestPurchaseProvider();

  @override
  bool get adRemoved => true;

  @override
  bool get aiAccess => false;

  @override
  bool get busy => false;

  @override
  String get priceLabel => '買い切り ¥190';

  @override
  String get aiPriceLabel => '買い切り ¥190';

  @override
  bool get canPurchase => true;

  @override
  bool get canPurchaseAi => true;

  @override
  String? get statusMessage => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Future<void> purchase() async {}

  @override
  Future<void> purchaseAi() async {}

  @override
  Future<void> restore() async {}
}

Future<AppSettings> _createSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings(prefs);
}

Future<AppState> _createAppState() async {
  final store = await DriftStore.createInMemory();
  final appState = AppState(
    store: store,
    notifications: NotificationService(timezoneName: 'Asia/Tokyo'),
  );
  await appState.load();
  return appState;
}

Future<void> _loadScreenshotFonts() async {
  final manifestJson = await rootBundle.loadString('FontManifest.json');
  final manifest = jsonDecode(manifestJson) as List<dynamic>;
  final loadedFamilies = <String>{};
  final loadFutures = <Future<void>>[];

  for (final entry in manifest) {
    final font = entry as Map<String, dynamic>;
    final family = font['family'] as String;
    if (!_requiredFontFamilies.contains(family)) {
      continue;
    }

    final loader = FontLoader(family);
    for (final descriptor in font['fonts'] as List<dynamic>) {
      final asset = (descriptor as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    loadFutures.add(loader.load());
    loadedFamilies.add(family);
  }

  await Future.wait(loadFutures);

  final missingFamilies = _requiredFontFamilies.difference(loadedFamilies);
  if (missingFamilies.isNotEmpty) {
    throw StateError(
      'スクリーンショット用フォントを読み込めませんでした: '
      '${missingFamilies.join(', ')}',
    );
  }
}

void _configureViewport(WidgetTester tester) {
  tester.view.physicalSize = _viewportPhysicalSize;
  tester.view.devicePixelRatio = _devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _captureBoundary(Widget child) {
  return RepaintBoundary(
    key: _captureKey,
    child: child,
  );
}

Future<void> _writeScreenshot(
  WidgetTester tester,
  String filename,
) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _devicePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('PNGの生成に失敗しました: $filename');
    }

    final output = File('$_outputDirectory/$filename');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  });
}

Future<void> _seedTomorrowTodos(AppState appState) async {
  final child = await appState.addChild('こども');
  final tomorrow = DateTime.now().add(const Duration(days: 1));

  final belongings = await appState.addTodoFromDraft(
    personId: child.id,
    draft: ExtractionDraft(
      title: '遠足の持ち物を準備',
      category: TodoCategory.item,
      items: const ['水筒', 'タオル', '帽子'],
      dueDate: tomorrow,
      note: '前日の夜に確認',
    ),
  );
  await appState.toggleItem(belongings.id, belongings.items.first.id);

  await appState.addTodoFromDraft(
    personId: child.id,
    draft: ExtractionDraft(
      title: '健康調査票を提出',
      category: TodoCategory.submit,
      items: const ['健康調査票'],
      dueDate: tomorrow,
    ),
  );

  await appState.addTodoFromDraft(
    personId: child.id,
    draft: ExtractionDraft(
      title: '集金袋を持参',
      category: TodoCategory.payment,
      items: const ['集金袋'],
      amount: 500,
      dueDate: tomorrow,
    ),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    await _loadScreenshotFonts();

    final directory = Directory(_outputDirectory);
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    directory.createSync(recursive: true);
  });

  setUp(() {
    // このファイルはtool配下だが、CIではflutter testから実行するテスト専用コード。
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'notification_info_shown_v1': true,
    });
  });

  testWidgets('ホームの明日一覧を生成する', (tester) async {
    _configureViewport(tester);
    final appState = await _createAppState();
    final settings = await _createSettings();
    await _seedTomorrowTodos(appState);

    await tester.pumpWidget(
      _captureBoundary(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('明日の持ち物・提出'), findsOneWidget);
    expect(find.text('遠足の持ち物を準備'), findsOneWidget);
    await _writeScreenshot(tester, 'home-tomorrow.png');
  });

  testWidgets('読み取り結果の確認画面を生成する', (tester) async {
    _configureViewport(tester);
    final appState = await _createAppState();
    final settings = await _createSettings();
    await appState.addChild('こども');
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    await tester.pumpWidget(
      _captureBoundary(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appState),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: ReviewExtractionScreen(
              draft: ExtractionDraft(
                title: '遠足の持ち物を準備',
                category: TodoCategory.item,
                items: const ['水筒', 'タオル', '帽子'],
                dueDate: tomorrow,
                note: '遠足のお知らせを確認し、前日の夜までに準備してください。',
                rawText: '明日は水筒、タオル、帽子を持参してください。',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('読み取り結果の確認'), findsOneWidget);
    expect(find.text('登録する'), findsOneWidget);
    await _writeScreenshot(tester, 'review-extraction.png');
  });

  testWidgets('すべて完了したホーム画面を生成する', (tester) async {
    _configureViewport(tester);
    final appState = await _createAppState();
    final settings = await _createSettings();
    await _seedTomorrowTodos(appState);

    for (final todo in appState.todos.toList()) {
      await appState.toggleTodoDone(todo.id);
    }

    await tester.pumpWidget(
      _captureBoundary(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('すべて完了'), findsWidgets);
    await _writeScreenshot(tester, 'all-complete.png');
  });
}
