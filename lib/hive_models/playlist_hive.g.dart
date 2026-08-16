// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaylistHiveAdapter extends TypeAdapter<PlaylistHive> {
  @override
  final int typeId = 1;

  @override
  PlaylistHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaylistHive(
      id: fields[0] as String,
      name: fields[1] as String,
      songIds: (fields[2] as List).cast<String>(),
      createdAt: fields[3] as DateTime,
      modifiedAt: fields[4] as DateTime?,
      description: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlaylistHive obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.songIds)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.modifiedAt)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
