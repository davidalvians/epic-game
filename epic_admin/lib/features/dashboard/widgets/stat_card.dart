import 'package:flutter/material.dart';

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color bg = Colors.white;
    const Color titleColor = Color(0xFF64748B);
    const Color valueColor = Color(0xFF0F172A);
    final Color subtitleColor = _getReadableTextColor(widget.color);
    final Color iconBgColor = widget.color.withOpacity(0.1);
    final Color iconColor = widget.color;
    final Color curveColor = widget.color.withOpacity(0.05);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovered ? widget.color.withOpacity(0.35) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isHovered ? widget.color : Colors.black).withOpacity(_isHovered ? 0.08 : 0.02),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Background Contours Painter
              Positioned.fill(
                child: CustomPaint(
                  painter: CurvedBackgroundPainter(lineColor: curveColor),
                ),
              ),
              // 2. Main Content Layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.value,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: valueColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: subtitleColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.icon,
                        color: iconColor,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getReadableTextColor(Color color) {
    if (color == Colors.blue) return const Color(0xFF1D4ED8);
    if (color == Colors.green) return const Color(0xFF15803D);
    if (color == Colors.red) return const Color(0xFFB91C1C);
    if (color == Colors.purple) return const Color(0xFF7E22CE);
    if (color == Colors.orange) return const Color(0xFFC2410C);
    if (color == Colors.teal) return const Color(0xFF0F766E);
    return color;
  }
}

class CurvedBackgroundPainter extends CustomPainter {
  final Color lineColor;
  CurvedBackgroundPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path1 = Path()
      ..moveTo(size.width * 0.3, size.height)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.1,
        size.width * 1.1,
        size.height * 0.4,
      );

    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.2,
        size.width * 1.2,
        size.height * 0.5,
      );

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CurvedBackgroundPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
