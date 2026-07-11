part of '../drawing_screen.dart';

class _DrawingToolbar extends StatelessWidget {
  final DrawingController controller;

  const _DrawingToolbar({required this.controller});

  static const List<Color> _palette = [
    Color(0xFF1E293B), Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFEAB308),
    Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF6B7280), Color(0xFFFFFFFF), Color(0xFF92400E), Color(0xFFFBBF24),
  ];

  void _togglePopup(String popup) {
    if (controller.popupMenu.value == popup) {
      controller.popupMenu.value = '';
    } else {
      controller.popupMenu.value = popup;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // ── Base Toolbar or Collapsed FAB ──
        Align(
          alignment: Alignment.bottomCenter,
          child: Obx(() {
            final isExpanded = controller.isToolbarExpanded.value;
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: isExpanded
                  ? _buildExpandedToolbar(context)
                  : _buildCollapsedFAB(),
            );
          }),
        ),

        // ── Popups ──
        _buildPopupLayer('kuas', _buildBrushPopup()),
        _buildPopupLayer('warna', _buildColorPopup(context)),
        _buildPopupLayer('bentuk', _buildShapePopup()),
      ],
    );
  }

  Widget _buildCollapsedFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: FloatingActionButton(
        key: const ValueKey('collapsed_fab'),
        onPressed: controller.toggleToolbar,
        backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.95),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        child: const Icon(Icons.brush_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildExpandedToolbar(BuildContext context) {
    return Container(
      key: const ValueKey('expanded_toolbar'),
      margin: const EdgeInsets.only(bottom: 16.0, left: 12.0, right: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle collapse bar
              GestureDetector(
                onTap: controller.toggleToolbar,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF475569).withValues(alpha: 0.5)),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              
              // ── Row 1: Ketebalan Selalu Tampil ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Obx(() {
                  return Row(
                    children: [
                      const Icon(Icons.line_weight_rounded, size: 16, color: Color(0xFF94A3B8)),
                      Expanded(
                        child: Slider(
                          value: controller.thickness.value,
                          min: 1,
                          max: 40,
                          divisions: 39,
                          activeColor: const Color(0xFF8B5CF6),
                          inactiveColor: const Color(0xFF334155),
                          onChanged: controller.setThickness,
                        ),
                      ),
                      // Preview Ukuran Bundar Kecil
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Center(
                          child: Container(
                            width: controller.thickness.value.clamp(2.0, 20.0),
                            height: controller.thickness.value.clamp(2.0, 20.0),
                            decoration: BoxDecoration(
                              color: controller.activeColor.value,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              
              // ── Row 2: Tombol Tools ──
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 8),
                      // Kerangka (Template)
                      _buildBaseBtn(
                        icon: controller.hasTemplate.value ? Icons.check_circle_rounded : Icons.dashboard_customize_rounded,
                        label: 'Kerangka',
                        isActive: controller.hasTemplate.value,
                        onTap: () {
                          controller.popupMenu.value = '';
                          _showTemplateSelector(context);
                        },
                      ),

                      // Geser (Pan/Hand)
                      _buildBaseBtn(
                        icon: Icons.pan_tool_rounded,
                        label: 'Geser',
                        isActive: controller.activeTool.value == DrawingTool.cursor,
                        onTap: () {
                          controller.popupMenu.value = '';
                          controller.setTool(DrawingTool.cursor);
                        },
                      ),

                      // Kuas (Brush Pop-up)
                      _buildBaseBtn(
                        icon: Icons.brush_rounded,
                        label: 'Kuas',
                        isActive: controller.popupMenu.value == 'kuas' || controller.activeTool.value == DrawingTool.pencil,
                        onTap: () {
                          _togglePopup('kuas');
                          if (controller.activeTool.value != DrawingTool.pencil) {
                            controller.setTool(DrawingTool.pencil);
                          }
                        },
                      ),

                      // Warna (Color Pop-up)
                      _buildColorBtn(),

                      // Penghapus
                      _buildBaseBtn(
                        icon: Icons.auto_fix_high_rounded,
                        label: 'Hapus',
                        isActive: controller.activeTool.value == DrawingTool.eraser,
                        onTap: () {
                          controller.popupMenu.value = '';
                          controller.setTool(DrawingTool.eraser);
                        },
                      ),

                      // Bentuk / Stempel
                      _buildBaseBtn(
                        icon: Icons.category_rounded,
                        label: 'Bentuk',
                        isActive: controller.popupMenu.value == 'bentuk',
                        onTap: () => _togglePopup('bentuk'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupLayer(String popupName, Widget child) {
    return Positioned(
      bottom: 120, // Di atas toolbar baru yang lebih tinggi
      child: Obx(() {
        final isActive = controller.popupMenu.value == popupName;
        return AnimatedScale(
          scale: isActive ? 1.0 : 0.8,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          alignment: Alignment.bottomCenter,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !isActive,
              child: child,
            ),
          ),
        );
      }),
    );
  }

  // --- Widget Builders ---

  Widget _buildBaseBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBtn() {
    final isActive = controller.popupMenu.value == 'warna';
    return GestureDetector(
      onTap: () => _togglePopup('warna'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8B5CF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: controller.activeColor.value,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Warna',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrushPopup() {
    return Container(
      width: 280,
      height: 380, // Taller to fit 4 brushes with their inline horizontal previews
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Obx(() {
        return ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: PencilType.values.map((type) {
            final isSelected = controller.activePencilType.value == type;
            
            return GestureDetector(
              onTap: () {
                controller.setTool(DrawingTool.pencil);
                controller.setPencilType(type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B5CF6).withValues(alpha: 0.15) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF334155),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pratinjau Melintang (Garis panjang ke samping)
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _HorizontalWavyPainter(
                          color: isSelected ? controller.activeColor.value : Colors.white70,
                          thickness: controller.thickness.value,
                          pencilType: type,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Teks dan Ikon
                    Row(
                      children: [
                        Text(type.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type.label,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF8B5CF6), size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _buildShapePopup() {
    final isBatik = controller.kategori.toLowerCase() == 'batik';
    final items = isBatik
        ? [
            _StempelItem('Bintang', StempelShape.bintang),
            _StempelItem('Bunga', StempelShape.bunga),
            _StempelItem('Daun', StempelShape.daun),
            _StempelItem('Air', StempelShape.air),
            _StempelItem('Awan', StempelShape.awan),
            _StempelItem('Api', StempelShape.api),
            _StempelItem('Petir', StempelShape.petir),
            _StempelItem('Hati', StempelShape.hati),
            _StempelItem('Bulan', StempelShape.bulanSabit),
            _StempelItem('Silang', StempelShape.silang),
            _StempelItem('Ceklis', StempelShape.ceklis),
            _StempelItem('Panah', StempelShape.panah),
          ]
        : [
            _StempelItem('Segitiga', StempelShape.segitiga),
            _StempelItem('Persegi', StempelShape.persegi),
            _StempelItem('P. Panjang', StempelShape.persegiPanjang),
            _StempelItem('Belah Ketupat', StempelShape.belahKetupat),
            _StempelItem('Segi Lima', StempelShape.segiLima),
            _StempelItem('Segi Enam', StempelShape.segiEnam),
            _StempelItem('Lingkaran', StempelShape.lingkaran),
            _StempelItem('Bintang', StempelShape.bintang),
            _StempelItem('Hati', StempelShape.hati),
            _StempelItem('Bulan', StempelShape.bulanSabit),
          ];

    return Container(
      width: 320,
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBatik ? 'Pilih Motif' : 'Pilih Bentuk',
            style: const TextStyle(fontFamily: 'FredokaOne', color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((e) => _buildStempelOption(e.label, e.shape)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPopup(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Pipet & Warna Kustom
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    controller.setTool(DrawingTool.eyedropper);
                    controller.popupMenu.value = '';
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.colorize_rounded, size: 18, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 8),
                        Text('Pipet', style: TextStyle(fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    controller.popupMenu.value = '';
                    _showColorPicker(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.palette_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Kustom', style: TextStyle(fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 2 & 3: Palet Warna
          Obx(() {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _palette.map((color) {
                final isSelected = controller.activeColor.value.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    controller.setColor(color);
                    controller.popupMenu.value = ''; // Auto close on select
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 36 : 30,
                    height: isSelected ? 36 : 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                          : [],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // --- Dialogs ---

  void _showColorPicker(BuildContext context) {
    Color pickerColor = controller.activeColor.value;
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Pilih Warna Kustom', style: TextStyle(fontFamily: 'FredokaOne')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(fontFamily: 'Nunito', color: Colors.grey)),
            onPressed: () => Get.back(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Pilih', style: TextStyle(fontFamily: 'FredokaOne')),
            onPressed: () {
              controller.setColor(pickerColor);
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  void _showTemplateSelector(BuildContext context) {
    controller.pauseTimer();
    Get.bottomSheet(
      TemplateSelectorSheet(
        kategori: controller.kategori,
        level: controller.level,
        currentTemplateId: controller.activeTemplate.value?.id,
        onSelected: (template) {
          controller.setTemplate(template);
          controller.resumeTimer();
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).then((_) {
      if (!controller.isTimeUp.value) {
        controller.resumeTimer();
      }
    });
  }

  Widget _buildStempelOption(String label, StempelShape shape) {
    return InkWell(
      onTap: () {
        controller.popupMenu.value = '';
        controller.addStempel(shape);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border.all(color: const Color(0xFF334155)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(
                painter: StempelShapePainter(
                  shape: shape,
                  color: const Color(0xFF8B5CF6),
                  strokeWidth: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StempelItem {
  final String label;
  final StempelShape shape;
  _StempelItem(this.label, this.shape);
}

class _HorizontalWavyPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final PencilType pencilType;

  _HorizontalWavyPainter({
    required this.color,
    required this.thickness,
    required this.pencilType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: pencilType.opacityFactor)
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;
    
    // Generate mathematical sine wave points
    final List<pf.PointVector> points = [];
    final int steps = 40; // Number of points in the preview
    for (int i = 0; i <= steps; i++) {
      final t = i / steps; // 0.0 to 1.0
      final x = 10 + (w - 20) * t;
      // Sine wave: one full cycle
      final y = (h / 2) + math.sin(t * math.pi * 2) * (h * 0.3);
      points.add(pf.PointVector(x, y));
    }

    final options = pf.StrokeOptions(
      size: thickness * pencilType.thicknessMultiplier,
      thinning: 0.7, 
      smoothing: 0.5,
      streamline: 0.5,
      start: pf.StrokeEndOptions.start(customTaper: 10.0), // Force tapering on previews to look extra beautiful!
      end: pf.StrokeEndOptions.end(customTaper: 10.0),
      simulatePressure: true,
    );

    final outlinePoints = pf.getStroke(points, options: options);
    final path = Path();
    if (outlinePoints.isNotEmpty) {
      path.moveTo(outlinePoints[0].dx, outlinePoints[0].dy);
      for (int i = 1; i < outlinePoints.length; i++) {
        path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
      }
      path.close();
    }

    // Tambahkan tekstur/efek jika jenis pensil membutuhkannya
    if (pencilType == PencilType.pencil) {
      // Efek goresan kasar pensil
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    } else if (pencilType == PencilType.watercolor) {
      // Efek blur cat air
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HorizontalWavyPainter oldDelegate) {
    return oldDelegate.color != color ||
           oldDelegate.thickness != thickness ||
           oldDelegate.pencilType != pencilType;
  }
}
