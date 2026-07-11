import sys
path = r'c:\Users\ASUS\project-epic-app\epic_app\lib\features\games\menggambar\drawing_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

start_str = 'class _DrawingHeader extends StatelessWidget {'
end_str = '// ─── Layer Panel Helper'

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    new_header = '''class _DrawingHeader extends StatelessWidget {
  final DrawingController controller;

  const _DrawingHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              border: Border.all(color: const Color(0xFF334155), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Row 1: Info & Actions ───
                Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () {
                        controller.pauseTimer();
                        Get.dialog(
                          AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: const Text('Keluar?',
                                style: TextStyle(fontFamily: 'FredokaOne')),
                            content: const Text(
                                'Progres gambarmu akan hilang jika belum dikumpulkan.',
                                style: TextStyle(fontFamily: 'Nunito')),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Get.back();
                                  controller.resumeTimer();
                                },
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  Get.back();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Keluar'),
                              ),
                            ],
                          ),
                        ).then((_) {
                          if (!controller.isTimeUp.value) {
                            controller.resumeTimer();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155).withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Title & Nyawa
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${Helpers.getKategoriEmoji(controller.kategori)} ${Helpers.getLevelLabel(controller.kategori, controller.level)}',
                            style: const TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 14,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Obx(() {
                            final user = Get.find<SessionController>().currentUser.value;
                            final maxNyawaDisplay = Get.isRegistered<AppConfigService>() 
                                ? Get.find<AppConfigService>().maxNyawa.value 
                                : UserModel.maxNyawa;
                            final nyawa = user?.nyawaEfektif ?? 0;
                            return Row(
                              children: List.generate(maxNyawaDisplay, (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    index < nyawa
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: index < nyawa
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF475569),
                                    size: 12,
                                  ),
                                );
                              }),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Timer
                    Obx(() {
                      final isWarning = controller.isWarningTime;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWarning
                              ? const Color(0xFF7F1D1D).withOpacity(0.8)
                              : const Color(0xFF14532D).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isWarning
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF22C55E)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              controller.waktuFormatted,
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 13,
                                color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(width: 8),

                    // Kumpulkan Button
                    ElevatedButton(
                      onPressed: () {
                        controller.pauseTimer();
                        Get.dialog(
                          AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Kumpulkan Karya?',
                                style: TextStyle(fontFamily: 'FredokaOne')),
                            content: const Text(
                                'Pastikan gambarmu sudah selesai! Setelah dikumpulkan, gambar tidak bisa diedit lagi.',
                                style: TextStyle(fontFamily: 'Nunito')),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Get.back();
                                  controller.resumeTimer();
                                },
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  controller.submitDrawing();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Kumpulkan'),
                              ),
                            ],
                          ),
                        ).then((_) {
                          if (!controller.isTimeUp.value) {
                            controller.resumeTimer();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Kumpulkan',
                          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // ─── Row 2: Tools (Centered) ───
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Undo
                      Obx(() => IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 22,
                            onPressed: controller.canUndo ? controller.undo : null,
                            icon: Icon(Icons.undo_rounded,
                                color: controller.canUndo ? Colors.white : const Color(0xFF475569)),
                          )),
                      const SizedBox(width: 16),
                      // Redo
                      Obx(() => IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 22,
                            onPressed: controller.canRedo ? controller.redo : null,
                            icon: Icon(Icons.redo_rounded,
                                color: controller.canRedo ? Colors.white : const Color(0xFF475569)),
                          )),
                      const SizedBox(width: 16),
                      // Reset View
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 22,
                        onPressed: controller.resetCanvasView,
                        icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
                        tooltip: 'Pusatkan Kertas',
                      ),
                      const SizedBox(width: 16),
                      // Clear
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 22,
                        onPressed: () => Get.dialog(
                          AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Hapus Semua?', style: TextStyle(fontFamily: 'FredokaOne')),
                            content: const Text('Canvas akan dikosongkan.', style: TextStyle(fontFamily: 'Nunito')),
                            actions: [
                              TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  controller.clearCanvas();
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFCA5A5)),
                        tooltip: 'Bersihkan Kertas',
                      ),
                      const SizedBox(width: 16),
                      // Layer
                      Obx(() {
                        final layerCount = controller.layers.length;
                        return GestureDetector(
                          onTap: () => _showLayerPanel(context, controller),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_rounded, color: Color(0xFFC4B5FD), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${layerCount}',
                                  style: const TextStyle(
                                    fontFamily: 'FredokaOne',
                                    fontSize: 12,
                                    color: Color(0xFFC4B5FD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Progress Bar
                Obx(() {
                  return RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: controller.timerProgress,
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(controller.timerColor),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

'''
    
    new_content = content[:start_idx] + new_header + content[end_idx:]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Replaced successfully')
else:
    print('Failed to find start or end index')
    print('Start:', start_idx)
    print('End:', end_idx)
