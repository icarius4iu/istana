import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/session_models.dart';

/// Fila de un miembro de la jam: rol (HOST sirve archivos, PEER no) y
/// estado de conexión declarado por el propio cliente (no verificado por el
/// servidor — ver `MemberConnectionStatus` en `session_models.dart`).
class MemberChip extends StatelessWidget {
  final SessionMember member;
  final bool isMe;

  const MemberChip({super.key, required this.member, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        member.role == SessionRole.host ? Icons.star : Icons.person,
        size: 18,
        color: member.role == SessionRole.host
            ? AppTheme.spotifyGreen
            : AppTheme.textSecondary,
      ),
      label: Text(
        isMe
            ? 'Vos (${member.role == SessionRole.host ? 'host' : 'peer'})'
            : member.userId.substring(0, 8),
      ),
      backgroundColor: AppTheme.cardBg,
      side: BorderSide(color: _statusColor(member.connectionStatus)),
    );
  }

  Color _statusColor(MemberConnectionStatus status) {
    switch (status) {
      case MemberConnectionStatus.connected:
        return AppTheme.spotifyGreen;
      case MemberConnectionStatus.connecting:
        return AppTheme.textSecondary;
      case MemberConnectionStatus.disconnected:
        return AppTheme.error;
    }
  }
}
