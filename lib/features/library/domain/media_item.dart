sealed class MediaItemLocation {
  const MediaItemLocation();

  bool get isPrivateFile => this is PrivateFileLocation;

  bool get isMediaStoreReference => this is MediaStoreReferenceLocation;
}

final class PrivateFileLocation extends MediaItemLocation {
  PrivateFileLocation({
    required String privatePath,
    required String internalName,
  }) : privatePath = _required(privatePath, 'privatePath'),
       internalName = _required(internalName, 'internalName');

  final String privatePath;
  final String internalName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivateFileLocation &&
          other.privatePath == privatePath &&
          other.internalName == internalName;

  @override
  int get hashCode => Object.hash(privatePath, internalName);
}

final class MediaStoreReferenceLocation extends MediaItemLocation {
  MediaStoreReferenceLocation({
    required String sourceKey,
    required int mediaStoreId,
    required String volumeName,
    required String contentUri,
    this.dateModified,
  }) : sourceKey = _required(sourceKey, 'sourceKey'),
       mediaStoreId = _validId(mediaStoreId),
       volumeName = _validVolume(volumeName),
       contentUri = _validContentUri(
         contentUri,
         volumeName: volumeName,
         mediaStoreId: mediaStoreId,
       ) {
    if (sourceKey != '$volumeName:$mediaStoreId') {
      throw ArgumentError.value(sourceKey, 'sourceKey', 'Chave incoerente.');
    }
  }

  final String sourceKey;
  final int mediaStoreId;
  final String volumeName;
  final String contentUri;
  final DateTime? dateModified;

  static String canonicalContentUri(String volumeName, int mediaStoreId) {
    final validVolume = _validVolume(volumeName);
    final validId = _validId(mediaStoreId);
    return 'content://media/$validVolume/images/media/$validId';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaStoreReferenceLocation &&
          other.sourceKey == sourceKey &&
          other.mediaStoreId == mediaStoreId &&
          other.volumeName == volumeName &&
          other.contentUri == contentUri &&
          other.dateModified == dateModified;

  @override
  int get hashCode => Object.hash(
    sourceKey,
    mediaStoreId,
    volumeName,
    contentUri,
    dateModified,
  );
}

String _required(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) throw ArgumentError.value(value, name, 'Obrigatório.');
  return trimmed;
}

int _validId(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'mediaStoreId', 'Inválido.');
  return value;
}

String _validVolume(String value) {
  final volume = _required(value, 'volumeName');
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(volume)) {
    throw ArgumentError.value(value, 'volumeName', 'Volume inválido.');
  }
  return volume;
}

String _validContentUri(
  String value, {
  required String volumeName,
  required int mediaStoreId,
}) {
  final uri = Uri.tryParse(value);
  final canonical = MediaStoreReferenceLocation.canonicalContentUri(
    volumeName,
    mediaStoreId,
  );
  if (uri == null ||
      uri.scheme != 'content' ||
      uri.authority != 'media' ||
      value != canonical) {
    throw ArgumentError.value(value, 'contentUri', 'URI MediaStore inválida.');
  }
  return value;
}

MediaItemLocation mediaItemLocationFromStorage({
  required String storageKind,
  required String? privatePath,
  required String? internalName,
  required String? sourceKey,
  required int? mediaStoreId,
  required String? volumeName,
  required String? contentUri,
  required DateTime? sourceDateModified,
}) {
  if (storageKind == 'mediaStoreReference') {
    return MediaStoreReferenceLocation(
      sourceKey: sourceKey!,
      mediaStoreId: mediaStoreId!,
      volumeName: volumeName!,
      contentUri: contentUri!,
      dateModified: sourceDateModified,
    );
  }
  return PrivateFileLocation(
    privatePath: privatePath!,
    internalName: internalName!,
  );
}

class MediaItem {
  MediaItem({
    required this.id,
    MediaItemLocation? location,
    String? privatePath,
    String? internalName,
    required this.importedAt,
    required this.sourceMode,
    required this.status,
    this.importOrigin = ImportOrigin.picker,
    this.mimeType,
    this.mediaHash,
    this.capturedAt,
  }) : location =
           location ??
           PrivateFileLocation(
             privatePath: privatePath!,
             internalName: internalName!,
           );

  final int id;
  final MediaItemLocation location;
  final String? mimeType;
  final String? mediaHash;
  final DateTime importedAt;
  final DateTime? capturedAt;
  final String sourceMode;
  final String status;
  final ImportOrigin importOrigin;

  bool get isPrivateFile => location.isPrivateFile;

  bool get isMediaStoreReference => location.isMediaStoreReference;

  String? get privatePath => switch (location) {
    PrivateFileLocation(:final privatePath) => privatePath,
    MediaStoreReferenceLocation() => null,
  };

  String? get internalName => switch (location) {
    PrivateFileLocation(:final internalName) => internalName,
    MediaStoreReferenceLocation() => null,
  };

  String? get sourceKey => switch (location) {
    MediaStoreReferenceLocation(:final sourceKey) => sourceKey,
    PrivateFileLocation() => null,
  };

  DateTime get effectiveCapturedAt => capturedAt ?? importedAt;
}

enum ImportOrigin {
  picker('picker'),
  shared('shared'),
  automatic('automatic');

  const ImportOrigin(this.databaseValue);

  final String databaseValue;

  static ImportOrigin fromDatabase(String value) {
    return ImportOrigin.values.firstWhere(
      (origin) => origin.databaseValue == value,
      orElse: () => ImportOrigin.picker,
    );
  }
}
