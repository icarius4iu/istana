import 'package:flutter/material.dart';

import '../config/theme.dart';

class VolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
  });

  IconData get _icon {
    if (volume <= 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_icon, color: AppTheme.textSecondary),
          onPressed: () => onVolumeChanged(volume > 0 ? 0 : 1),
          tooltip: volume > 0 ? 'Silenciar' : 'Activar sonido',
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              min: 0,
              max: 1,
              value: volume.clamp(0.0, 1.0),
              onChanged: onVolumeChanged,
            ),
          ),
        ),
      ],
    );
  }
}
