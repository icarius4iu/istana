import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/formatters.dart';

/// Barra de progreso con seek. Mantiene una posición "arrastrada"
/// localmente mientras el usuario mueve el slider, para no pelear con el
/// stream de posición del reproductor (que seguiría llegando y "tironeando"
/// el thumb de vuelta si se leyera `currentPosition` en cada frame durante
/// el drag).
class ProgressBar extends StatefulWidget {
  final Duration currentPosition;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const ProgressBar({
    super.key,
    required this.currentPosition,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    // Evita min==max en el Slider (crashea) cuando aún no se conoce la
    // duración real (0 al arrancar, o en Web hasta que carga el audio).
    final totalMs = widget.duration.inMilliseconds > 0
        ? widget.duration.inMilliseconds
        : 1;
    final currentMs = widget.currentPosition.inMilliseconds
        .clamp(0, totalMs)
        .toDouble();
    final sliderValue = (_dragValue ?? currentMs)
        .clamp(0, totalMs.toDouble())
        .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: 0,
            max: totalMs.toDouble(),
            value: sliderValue,
            onChanged: widget.duration == Duration.zero
                ? null
                : (value) => setState(() => _dragValue = value),
            onChangeEnd: (value) {
              widget.onSeek(Duration(milliseconds: value.round()));
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                FormatUtils.formatDuration(
                  Duration(milliseconds: (_dragValue ?? currentMs).round()),
                ),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                FormatUtils.formatDuration(widget.duration),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
