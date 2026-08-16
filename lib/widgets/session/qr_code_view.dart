import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// El backend ya manda el QR renderizado como PNG (`qrCodePng`, base64):
/// alcanza con decodificarlo, no hace falta ninguna librería de generación
/// de QR en el cliente.
class QrCodeView extends StatelessWidget {
  final String base64Png;
  final double size;

  const QrCodeView({super.key, required this.base64Png, this.size = 220});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64Png);
    } on FormatException {
      bytes = null;
    }

    if (bytes == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Icon(Icons.qr_code_2, color: AppTheme.textSecondary, size: 48),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        gaplessPlayback: true,
      ),
    );
  }
}
