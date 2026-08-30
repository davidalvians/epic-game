import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/features/games/menggambar/stempel_painter.dart';

class StempelModel {
  final String id;
  final StempelShape shape;
  final Rx<Offset> position;
  final RxDouble scaleX;
  final RxDouble scaleY;
  final Rx<Color> color;
  final RxDouble strokeWidth;
  final RxDouble opacity;
  final RxBool isResizing = false.obs;

  /// Rotasi dalam radian (0 = tidak diputar)
  final RxDouble rotation;

  /// Urutan lapisan — semakin besar nilainya, semakin di atas
  final RxInt zIndex;

  StempelModel({
    required this.id,
    required this.shape,
    required Offset initialPosition,
    required Color initialColor,
    required double initialStrokeWidth,
    double initialOpacity = 1.0,
    double initialScaleX = 1.0,
    double initialScaleY = 1.0,
    double initialRotation = 0.0,
    int initialZIndex = 0,
  })  : position = initialPosition.obs,
        scaleX = initialScaleX.obs,
        scaleY = initialScaleY.obs,
        strokeWidth = initialStrokeWidth.obs,
        opacity = initialOpacity.obs,
        color = initialColor.obs,
        rotation = initialRotation.obs,
        zIndex = initialZIndex.obs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'shape': shape.name,
        'position': [position.value.dx, position.value.dy],
        'scaleX': scaleX.value,
        'scaleY': scaleY.value,
        'strokeWidth': strokeWidth.value,
        'opacity': opacity.value,
        'color': color.value.toARGB32(),
        'rotation': rotation.value,
        'zIndex': zIndex.value,
      };

  factory StempelModel.fromJson(Map<String, dynamic> json) {
    return StempelModel(
      id: json['id'],
      shape: StempelShape.values.firstWhere(
        (e) => e.name == json['shape'],
        orElse: () => StempelShape.persegi,
      ),
      initialPosition: Offset(
        (json['position'] as List)[0].toDouble(),
        (json['position'] as List)[1].toDouble(),
      ),
      initialScaleX: (json['scaleX'] as num?)?.toDouble() ?? (json['scale'] as num?)?.toDouble() ?? 1.0,
      initialScaleY: (json['scaleY'] as num?)?.toDouble() ?? (json['scale'] as num?)?.toDouble() ?? 1.0,
      initialStrokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      initialOpacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      initialColor: Color(json['color']),
      initialRotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      initialZIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
