import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:epic_app/data/models/drawing_session_model.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:flutter/foundation.dart';

class DraftService extends GetxService {
  final RxList<DrawingSessionModel> drafts = <DrawingSessionModel>[].obs;
  
  // Mencegah file I/O bertabrakan untuk file draf yang sama (misal: save & delete berbarengan)
  final Map<String, Completer<void>> _fileLocks = {};
  
  // Mencegah loadAllDrafts berjalan ganda secara bersamaan
  bool _isLoading = false;
  bool _needsReload = false;

  Future<void> _runWithLock(String key, Future<void> Function() action) async {
    while (_fileLocks.containsKey(key)) {
      await _fileLocks[key]?.future;
    }
    final completer = Completer<void>();
    _fileLocks[key] = completer;
    try {
      await action();
    } finally {
      _fileLocks.remove(key);
      completer.complete();
    }
  }

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
    if (_isLoading) {
      _needsReload = true;
      return;
    }
    _isLoading = true;
    
    do {
      _needsReload = false;
      final user = Get.find<SessionController>().currentUser.value;
      if (user == null) {
        drafts.clear();
        continue;
      }

      try {
        final dir = await _getDraftDir();
        final List<DrawingSessionModel> loadedDrafts = [];
        
        final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
        for (var file in files) {
          try {
            final jsonStr = await file.readAsString();
            final data = jsonDecode(jsonStr);
            final session = DrawingSessionModel.fromJson(data);
            if (session.isDraft && session.uid == user.uid) {
              loadedDrafts.add(session);
            }
          } catch (fileErr) {
            debugPrint('Error parsing draft file ${file.path}: $fileErr');
            try {
              if (await file.exists()) {
                await file.delete();
                debugPrint('Deleted corrupted draft file: ${file.path}');
              }
            } catch (_) {}
          }
        }
        
        loadedDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        drafts.assignAll(loadedDrafts);
      } catch (e) {
        debugPrint('Error accessing draft directory: $e');
      }
    } while (_needsReload);
    
    _isLoading = false;
  }

  Future<void> saveDraft(DrawingSessionModel draft) async {
    final updatedDraft = draft.copyWith(updatedAt: DateTime.now());
    await _runWithLock(updatedDraft.storageKey, () async {
      final dir = await _getDraftDir();
      final file = File('${dir.path}/${updatedDraft.storageKey}.json');
      await file.writeAsString(jsonEncode(updatedDraft.toJson()));
    });
    await loadAllDrafts();
  }

  Future<void> deleteDraft(String uid, String kategori, int level) async {
    final key = 'drawing_session_${uid}_${kategori}_$level';
    await _runWithLock(key, () async {
      final dir = await _getDraftDir();
      final file = File('${dir.path}/$key.json');
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ File draft dihapus dari disk: $key');
      }
    });
    await loadAllDrafts();
  }

  /// Menghapus draft dari memori secara langsung (sinkron) agar UI terupdate seketika,
  /// lalu menghapus file dari disk di background tanpa memblokir proses.
  void clearDraftImmediately(String uid, String kategori, int level) {
    // 1. Hapus langsung dari list memory
    drafts.removeWhere((d) => d.uid == uid && d.kategori == kategori && d.level == level);
    debugPrint('✅ Draft dihapus dari memori secara instan: $kategori level $level');

    // 2. Hapus file di background
    _deleteDraftFileInBackground(uid, kategori, level);
  }

  Future<void> _deleteDraftFileInBackground(String uid, String kategori, int level) async {
    final key = 'drawing_session_${uid}_${kategori}_$level';
    await _runWithLock(key, () async {
      try {
        final dir = await _getDraftDir();
        final file = File('${dir.path}/$key.json');
        if (await file.exists()) {
          await file.delete();
          debugPrint('✅ File draft dihapus dari disk secara background: $key');
        }
      } catch (e) {
        debugPrint('⚠️ Gagal menghapus draft di background: $e');
      }
    });
    // Reload silently (diluar lock agar tidak deadlock)
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
