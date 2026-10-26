import 'dart:io';
import 'dart:ui' as ui;

import 'package:epic_app/core/services/draft_service.dart';
import 'package:epic_app/core/utils/responsive_layout.dart';
import 'package:epic_app/data/models/character_model.dart';
import 'package:epic_app/data/models/kelas_model.dart';
import 'package:epic_app/data/models/misi_harian_model.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/features/games/anyaman/anyaman_controller.dart';
import 'package:epic_app/features/games/anyaman/anyaman_screen.dart';
import 'package:epic_app/features/games/menggambar/drawing_controller.dart';
import 'package:epic_app/features/games/menggambar/drawing_screen.dart';
import 'package:epic_app/features/home/home_tab.dart';
import 'package:epic_app/features/home/widgets/daily_mission_card.dart';
import 'package:epic_app/features/karakter_toko/karakter_tab.dart';
import 'package:epic_app/features/karakter_toko/toko_controller.dart';
import 'package:epic_app/features/kelas/kelas_controller.dart';
import 'package:epic_app/features/main/main_controller.dart';
import 'package:epic_app/features/main/main_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:firebase_core/firebase_core.dart';
// Same Firebase bootstrap as widget_test.dart; no live account is used.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Session extends GetxController implements SessionController {
  @override
  bool get isGuru => currentUser.value?.role == 'guru';
  @override
  final currentUser = Rx<UserModel?>(UserModel(
    uid: 'layout-test',
    namaLengkap: 'Murid Uji',
    namaPanggilan: 'Murid Uji',
    email: '',
    avatarUrl: '',
    poin: 123456,
    nyawa: 3,
    nyawaLastReset: DateTime.now(),
    createdAt: DateTime.now(),
    karakterAktif: 'epi_default',
    karakterDimiliki: ['epi_default', 'ipeh_default'],
    sekolah: 'Sekolah Dasar dengan Nama Panjang',
  ));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _epi = CharacterModel(
    id: 'epi_default',
    nama: 'Epi Si Cerdas',
    deskripsi: '',
    tier: 'common',
    poinUnlock: 0,
    imageUrl: '');
const _ipeh = CharacterModel(
    id: 'ipeh_default',
    nama: 'Ipeh Si Pemberani',
    deskripsi: '',
    tier: 'common',
    poinUnlock: 0,
    imageUrl: '');

class _Shop extends GetxController implements TokoController {
  @override
  final characters = <CharacterModel>[_epi, _ipeh].obs;
  @override
  final selectedPreviewChar = Rxn<CharacterModel>(_epi);
  @override
  final isLoading = false.obs;
  @override
  bool isOwned(String id) => true;
  @override
  void selectPreviewChar(CharacterModel character) =>
      selectedPreviewChar.value = character;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Classes extends GetxController implements KelasController {
  @override
  final kelasList = <KelasModel>[].obs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Missions extends GetxController implements DailyMissionController {
  @override
  final missions = <MisiHarianModel>[].obs;
  @override
  final isLoading = false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Drafts extends DraftService {
  @override
  // Avoid filesystem/subscription initialization in this isolated layout test.
  // ignore: must_call_super
  void onInit() {}
}

class _Drawing extends DrawingController {
  _Drawing() : super(kategori: 'batik', level: 1);
  @override
  void onReady() {}
}

class _Weaving extends AnyamanController {
  _Weaving(int level) : super(level: level);
  @override
  void onReady() {}
}

Future<void> _size(WidgetTester tester, Size size) async {
  final handler = FlutterError.onError!;
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
    handler(details);
  };
  addTearDown(() {
    FlutterError.onError = handler;
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

final _previewKey = GlobalKey();

Future<void> _pump(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(RepaintBoundary(key: _previewKey, child: widget));

Future<void> _preview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SAVE_LAYOUT_PREVIEWS')) return;
  await tester.runAsync(() async {
    final boundary =
        _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.dart_tool/layout-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    if (const bool.fromEnvironment('SAVE_LAYOUT_PREVIEWS')) {
      final font = File('C:/Windows/Fonts/arial.ttf');
      if (font.existsSync()) {
        final bytes = ByteData.sublistView(await font.readAsBytes());
        for (final family in ['Ahem', 'Roboto', 'FredokaOne', 'Nunito']) {
          await (FontLoader(family)..addFont(Future.value(bytes))).load();
        }
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
    }
  });
  setUp(() {
    Get.testMode = true;
    final handler = FlutterError.onError!;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      handler(details);
    };
    addTearDown(() {
      FlutterError.onError = handler;
    });
  });
  tearDown(() {
    Get.reset();
  });

  for (final size in [
    const Size(640, 320),
    const Size(844, 390),
    const Size(390, 844)
  ]) {
    testWidgets('home and avatar fit $size and avatar selection works',
        (tester) async {
      await _size(tester, size);
      if (size == const Size(640, 320)) {
        tester.view.padding =
            const FakeViewPadding(left: 36, right: 36, bottom: 88);
        addTearDown(tester.view.resetPadding);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.put<SessionController>(_Session());
      Get.put<KelasController>(_Classes());
      Get.put<DailyMissionController>(_Missions());
      Get.put<DraftService>(_Drafts());
      final shop = Get.put<TokoController>(_Shop());
      await _pump(tester, const GetMaterialApp(home: HomeTab()));
      await tester.pump(const Duration(milliseconds: 100));
      await _preview(
          tester, 'home_${size.width.toInt()}x${size.height.toInt()}');
      expect(tester.takeException(), isNull);
      expect(find.text('MULAI BERMAIN'), findsOneWidget);
      await _pump(
          tester, const GetMaterialApp(home: Scaffold(body: KarakterTab())));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      final card = find.text('Ipeh Si Pemberani');
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 600));
      expect(shop.selectedPreviewChar.value?.id, 'ipeh_default');
      await _preview(
          tester, 'avatar_${size.width.toInt()}x${size.height.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('rotation preserves artwork, paper size and touch coordinates',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _Drawing()..onInit();
    controller.layers.add(DrawingLayer(id: 'rotation'));
    await _size(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: buildDrawingCanvasForTesting(controller))));
    await tester.pump();
    controller.onTap(const Offset(100, 100));
    final original = controller.activeLayer.strokes.single.toJson();
    final paperSize = Size(controller.paperWidth, controller.paperHeight);
    for (final size in [
      const Size(640, 320),
      const Size(844, 390),
      const Size(390, 844)
    ]) {
      await _size(tester, size);
      await _pump(
          tester,
          MaterialApp(
              home: Scaffold(
                  body: size.width > size.height
                      ? buildDrawingLandscapeForTesting(controller)
                      : buildDrawingCanvasForTesting(controller))));
      await tester.pump();
      expect(Size(controller.paperWidth, controller.paperHeight), paperSize);
      expect(controller.activeLayer.strokes.first.toJson(), original);
      final box =
          controller.canvasKey.currentContext!.findRenderObject() as RenderBox;
      expect(box.size, paperSize);
      final center = box.localToGlobal(paperSize.center(Offset.zero));
      expect(center.dx, inInclusiveRange(0, size.width));
      expect(center.dy, inInclusiveRange(0, size.height));
      final local = controller.screenToCanvas(center);
      expect(local.dx, closeTo(paperSize.width / 2, 0.01));
      expect(local.dy, closeTo(paperSize.height / 2, 0.01));
      expect(tester.takeException(), isNull);
      await _preview(
          tester, 'drawing_${size.width.toInt()}x${size.height.toInt()}');
      if (size.width > size.height) {
        await tester.ensureVisible(find.text('Hapus'));
        await tester.tap(find.text('Hapus'));
        await tester.pump();
        expect(controller.activeTool.value, DrawingTool.eraser);
        await tester.ensureVisible(find.text('Kuas'));
        await tester.tap(find.text('Kuas'));
        await tester.pump();
        expect(controller.popupMenu.value, 'kuas');
        await tester.drag(find.byType(ListView).first, const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Kembali ke alat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kembali ke alat'));
        await tester.pump();
        expect(controller.popupMenu.value, isEmpty);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.onClose();
  });

  for (var level = 1; level <= 4; level++) {
    testWidgets('anyaman level $level fits a short landscape board',
        (tester) async {
      await _size(tester, const Size(640, 320));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = Get.put<AnyamanController>(_Weaving(level));
      controller.isPaused.value = false;
      final transform = TransformationController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 300,
                      height: 160,
                      child: buildAnyamanBoardForTesting(
                          controller, transform))))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer)));
      await tester.pump();
      expect(
          controller.grid
              .expand((row) => row)
              .any((cell) => cell.value != null),
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      transform.dispose();
    });
  }

  testWidgets('portrait grid stays two columns and QR fits both orientations',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await _size(tester, size);
      late int columns;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        columns = ResponsiveLayout.gridColumns(context);
        return const SizedBox();
      })));
      expect(columns, size.width < size.height ? 2 : 4);
      expect(ResponsiveLayout.scannerSize(size), lessThan(size.shortestSide));
    }
  });

  testWidgets('landscape navigation fits safe insets and changes tabs',
      (tester) async {
    await _size(tester, const Size(640, 320));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MainController()..pageController = PageController();
    await _pump(
        tester,
        MaterialApp(
            home: MediaQuery(
          data: const MediaQueryData(
              size: Size(640, 320),
              padding: EdgeInsets.only(left: 36, right: 36, bottom: 24)),
          child: Builder(
              builder: (context) => Scaffold(
                    bottomNavigationBar: buildMainNavigationForTesting(
                        context, controller, _Session()),
                  )),
        )));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Profil'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.currentIndex.value, 4);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.pageController.dispose();
  });
}
