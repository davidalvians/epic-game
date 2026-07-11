import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:epic_app/data/models/drawing_session_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:flutter/foundation.dart';

class DraftService extends GetxService {
  final RxList<DrawingSessionModel> drafts = <DrawingSessionModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    final sessionController = Get.find<SessionController>();
    sessionController.activeDrafts.bindStream(drafts.stream);
    ever(sessionController.currentUser, (_) => loadAllDrafts());
    loadAllDrafts();
  }

  Future<Directory> _getDraftDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final draftDir = Directory('${docDir.path}/drafts');
    if (!await draftDir.exists()) {
      await draftDir.create(recursive: true);
    }
    return draftDir;
  }

  Future<void> loadAllDrafts() async {
    final user = Get.find<SessionController>().currentUser.value;
    if (user == null) {
      drafts.clear();
      return;
    }

    try {
      final dir = await _getDraftDir();
      final List<DrawingSessionModel> loadedDrafts = [];
      
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
      for (var file in files) {
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr);
        final session = DrawingSessionModel.fromJson(data);
        if (session.isDraft && session.uid == user.uid) {
          loadedDrafts.add(session);
        }
      }
      
      loadedDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      drafts.assignAll(loadedDrafts);
    } catch (e) {
      debugPrint('Error loading drafts: $e');
    }
  }

  Future<void> saveDraft(DrawingSessionModel draft) async {
    final updatedDraft = draft.copyWith(updatedAt: DateTime.now());
    final dir = await _getDraftDir();
    final file = File('${dir.path}/${updatedDraft.storageKey}.json');
    await file.writeAsString(jsonEncode(updatedDraft.toJson()));
    await loadAllDrafts();
  }

  Future<void> deleteDraft(String uid, String kategori, int level) async {
    final key = 'drawing_session_${uid}_${kategori}_$level';
    final dir = await _getDraftDir();
    final file = File('${dir.path}/$key.json');
    if (await file.exists()) {
      await file.delete();
    }
    await loadAllDrafts();
  }

  Future<DrawingSessionModel?> getDraft(String uid, String kategori, int level) async {
    final key = 'drawing_session_${uid}_${kategori}_$level';
    final dir = await _getDraftDir();
    final file = File('${dir.path}/$key.json');
    if (await file.exists()) {
      try {
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr);
        return DrawingSessionModel.fromJson(data);
      } catch (e) {
        debugPrint('Error reading draft file: $e');
      }
    }
    return null;
  }
}
