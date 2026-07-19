// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contexto_database.dart';

// ignore_for_file: type=lint
class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _storageKindMeta = const VerificationMeta(
    'storageKind',
  );
  @override
  late final GeneratedColumn<String> storageKind = GeneratedColumn<String>(
    'storage_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('privateFile'),
  );
  static const VerificationMeta _privatePathMeta = const VerificationMeta(
    'privatePath',
  );
  @override
  late final GeneratedColumn<String> privatePath = GeneratedColumn<String>(
    'private_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _internalNameMeta = const VerificationMeta(
    'internalName',
  );
  @override
  late final GeneratedColumn<String> internalName = GeneratedColumn<String>(
    'internal_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaStoreIdMeta = const VerificationMeta(
    'mediaStoreId',
  );
  @override
  late final GeneratedColumn<int> mediaStoreId = GeneratedColumn<int>(
    'media_store_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeNameMeta = const VerificationMeta(
    'volumeName',
  );
  @override
  late final GeneratedColumn<String> volumeName = GeneratedColumn<String>(
    'volume_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentUriMeta = const VerificationMeta(
    'contentUri',
  );
  @override
  late final GeneratedColumn<String> contentUri = GeneratedColumn<String>(
    'content_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceDateModifiedMeta =
      const VerificationMeta('sourceDateModified');
  @override
  late final GeneratedColumn<DateTime> sourceDateModified =
      GeneratedColumn<DateTime>(
        'source_date_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaHashMeta = const VerificationMeta(
    'mediaHash',
  );
  @override
  late final GeneratedColumn<String> mediaHash = GeneratedColumn<String>(
    'media_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceModeMeta = const VerificationMeta(
    'sourceMode',
  );
  @override
  late final GeneratedColumn<String> sourceMode = GeneratedColumn<String>(
    'source_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importOriginMeta = const VerificationMeta(
    'importOrigin',
  );
  @override
  late final GeneratedColumn<String> importOrigin = GeneratedColumn<String>(
    'import_origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('picker'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storageKind,
    privatePath,
    internalName,
    sourceKey,
    mediaStoreId,
    volumeName,
    contentUri,
    sourceDateModified,
    mimeType,
    mediaHash,
    importedAt,
    capturedAt,
    sourceMode,
    importOrigin,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('storage_kind')) {
      context.handle(
        _storageKindMeta,
        storageKind.isAcceptableOrUnknown(
          data['storage_kind']!,
          _storageKindMeta,
        ),
      );
    }
    if (data.containsKey('private_path')) {
      context.handle(
        _privatePathMeta,
        privatePath.isAcceptableOrUnknown(
          data['private_path']!,
          _privatePathMeta,
        ),
      );
    }
    if (data.containsKey('internal_name')) {
      context.handle(
        _internalNameMeta,
        internalName.isAcceptableOrUnknown(
          data['internal_name']!,
          _internalNameMeta,
        ),
      );
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    }
    if (data.containsKey('media_store_id')) {
      context.handle(
        _mediaStoreIdMeta,
        mediaStoreId.isAcceptableOrUnknown(
          data['media_store_id']!,
          _mediaStoreIdMeta,
        ),
      );
    }
    if (data.containsKey('volume_name')) {
      context.handle(
        _volumeNameMeta,
        volumeName.isAcceptableOrUnknown(data['volume_name']!, _volumeNameMeta),
      );
    }
    if (data.containsKey('content_uri')) {
      context.handle(
        _contentUriMeta,
        contentUri.isAcceptableOrUnknown(data['content_uri']!, _contentUriMeta),
      );
    }
    if (data.containsKey('source_date_modified')) {
      context.handle(
        _sourceDateModifiedMeta,
        sourceDateModified.isAcceptableOrUnknown(
          data['source_date_modified']!,
          _sourceDateModifiedMeta,
        ),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('media_hash')) {
      context.handle(
        _mediaHashMeta,
        mediaHash.isAcceptableOrUnknown(data['media_hash']!, _mediaHashMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('source_mode')) {
      context.handle(
        _sourceModeMeta,
        sourceMode.isAcceptableOrUnknown(data['source_mode']!, _sourceModeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceModeMeta);
    }
    if (data.containsKey('import_origin')) {
      context.handle(
        _importOriginMeta,
        importOrigin.isAcceptableOrUnknown(
          data['import_origin']!,
          _importOriginMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      storageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_kind'],
      )!,
      privatePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}private_path'],
      ),
      internalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}internal_name'],
      ),
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      ),
      mediaStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_store_id'],
      ),
      volumeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}volume_name'],
      ),
      contentUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_uri'],
      ),
      sourceDateModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}source_date_modified'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      mediaHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_hash'],
      ),
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      ),
      sourceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_mode'],
      )!,
      importOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_origin'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaItem extends DataClass implements Insertable<MediaItem> {
  final int id;
  final String storageKind;
  final String? privatePath;
  final String? internalName;
  final String? sourceKey;
  final int? mediaStoreId;
  final String? volumeName;
  final String? contentUri;
  final DateTime? sourceDateModified;
  final String? mimeType;
  final String? mediaHash;
  final DateTime importedAt;
  final DateTime? capturedAt;
  final String sourceMode;
  final String importOrigin;
  final String status;
  const MediaItem({
    required this.id,
    required this.storageKind,
    this.privatePath,
    this.internalName,
    this.sourceKey,
    this.mediaStoreId,
    this.volumeName,
    this.contentUri,
    this.sourceDateModified,
    this.mimeType,
    this.mediaHash,
    required this.importedAt,
    this.capturedAt,
    required this.sourceMode,
    required this.importOrigin,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['storage_kind'] = Variable<String>(storageKind);
    if (!nullToAbsent || privatePath != null) {
      map['private_path'] = Variable<String>(privatePath);
    }
    if (!nullToAbsent || internalName != null) {
      map['internal_name'] = Variable<String>(internalName);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    if (!nullToAbsent || mediaStoreId != null) {
      map['media_store_id'] = Variable<int>(mediaStoreId);
    }
    if (!nullToAbsent || volumeName != null) {
      map['volume_name'] = Variable<String>(volumeName);
    }
    if (!nullToAbsent || contentUri != null) {
      map['content_uri'] = Variable<String>(contentUri);
    }
    if (!nullToAbsent || sourceDateModified != null) {
      map['source_date_modified'] = Variable<DateTime>(sourceDateModified);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || mediaHash != null) {
      map['media_hash'] = Variable<String>(mediaHash);
    }
    map['imported_at'] = Variable<DateTime>(importedAt);
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<DateTime>(capturedAt);
    }
    map['source_mode'] = Variable<String>(sourceMode);
    map['import_origin'] = Variable<String>(importOrigin);
    map['status'] = Variable<String>(status);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      id: Value(id),
      storageKind: Value(storageKind),
      privatePath: privatePath == null && nullToAbsent
          ? const Value.absent()
          : Value(privatePath),
      internalName: internalName == null && nullToAbsent
          ? const Value.absent()
          : Value(internalName),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
      mediaStoreId: mediaStoreId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaStoreId),
      volumeName: volumeName == null && nullToAbsent
          ? const Value.absent()
          : Value(volumeName),
      contentUri: contentUri == null && nullToAbsent
          ? const Value.absent()
          : Value(contentUri),
      sourceDateModified: sourceDateModified == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceDateModified),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      mediaHash: mediaHash == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaHash),
      importedAt: Value(importedAt),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      sourceMode: Value(sourceMode),
      importOrigin: Value(importOrigin),
      status: Value(status),
    );
  }

  factory MediaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaItem(
      id: serializer.fromJson<int>(json['id']),
      storageKind: serializer.fromJson<String>(json['storageKind']),
      privatePath: serializer.fromJson<String?>(json['privatePath']),
      internalName: serializer.fromJson<String?>(json['internalName']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      mediaStoreId: serializer.fromJson<int?>(json['mediaStoreId']),
      volumeName: serializer.fromJson<String?>(json['volumeName']),
      contentUri: serializer.fromJson<String?>(json['contentUri']),
      sourceDateModified: serializer.fromJson<DateTime?>(
        json['sourceDateModified'],
      ),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      mediaHash: serializer.fromJson<String?>(json['mediaHash']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      capturedAt: serializer.fromJson<DateTime?>(json['capturedAt']),
      sourceMode: serializer.fromJson<String>(json['sourceMode']),
      importOrigin: serializer.fromJson<String>(json['importOrigin']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'storageKind': serializer.toJson<String>(storageKind),
      'privatePath': serializer.toJson<String?>(privatePath),
      'internalName': serializer.toJson<String?>(internalName),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'mediaStoreId': serializer.toJson<int?>(mediaStoreId),
      'volumeName': serializer.toJson<String?>(volumeName),
      'contentUri': serializer.toJson<String?>(contentUri),
      'sourceDateModified': serializer.toJson<DateTime?>(sourceDateModified),
      'mimeType': serializer.toJson<String?>(mimeType),
      'mediaHash': serializer.toJson<String?>(mediaHash),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'capturedAt': serializer.toJson<DateTime?>(capturedAt),
      'sourceMode': serializer.toJson<String>(sourceMode),
      'importOrigin': serializer.toJson<String>(importOrigin),
      'status': serializer.toJson<String>(status),
    };
  }

  MediaItem copyWith({
    int? id,
    String? storageKind,
    Value<String?> privatePath = const Value.absent(),
    Value<String?> internalName = const Value.absent(),
    Value<String?> sourceKey = const Value.absent(),
    Value<int?> mediaStoreId = const Value.absent(),
    Value<String?> volumeName = const Value.absent(),
    Value<String?> contentUri = const Value.absent(),
    Value<DateTime?> sourceDateModified = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<String?> mediaHash = const Value.absent(),
    DateTime? importedAt,
    Value<DateTime?> capturedAt = const Value.absent(),
    String? sourceMode,
    String? importOrigin,
    String? status,
  }) => MediaItem(
    id: id ?? this.id,
    storageKind: storageKind ?? this.storageKind,
    privatePath: privatePath.present ? privatePath.value : this.privatePath,
    internalName: internalName.present ? internalName.value : this.internalName,
    sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
    mediaStoreId: mediaStoreId.present ? mediaStoreId.value : this.mediaStoreId,
    volumeName: volumeName.present ? volumeName.value : this.volumeName,
    contentUri: contentUri.present ? contentUri.value : this.contentUri,
    sourceDateModified: sourceDateModified.present
        ? sourceDateModified.value
        : this.sourceDateModified,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    mediaHash: mediaHash.present ? mediaHash.value : this.mediaHash,
    importedAt: importedAt ?? this.importedAt,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    sourceMode: sourceMode ?? this.sourceMode,
    importOrigin: importOrigin ?? this.importOrigin,
    status: status ?? this.status,
  );
  MediaItem copyWithCompanion(MediaItemsCompanion data) {
    return MediaItem(
      id: data.id.present ? data.id.value : this.id,
      storageKind: data.storageKind.present
          ? data.storageKind.value
          : this.storageKind,
      privatePath: data.privatePath.present
          ? data.privatePath.value
          : this.privatePath,
      internalName: data.internalName.present
          ? data.internalName.value
          : this.internalName,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      mediaStoreId: data.mediaStoreId.present
          ? data.mediaStoreId.value
          : this.mediaStoreId,
      volumeName: data.volumeName.present
          ? data.volumeName.value
          : this.volumeName,
      contentUri: data.contentUri.present
          ? data.contentUri.value
          : this.contentUri,
      sourceDateModified: data.sourceDateModified.present
          ? data.sourceDateModified.value
          : this.sourceDateModified,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      mediaHash: data.mediaHash.present ? data.mediaHash.value : this.mediaHash,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      sourceMode: data.sourceMode.present
          ? data.sourceMode.value
          : this.sourceMode,
      importOrigin: data.importOrigin.present
          ? data.importOrigin.value
          : this.importOrigin,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItem(')
          ..write('id: $id, ')
          ..write('storageKind: $storageKind, ')
          ..write('privatePath: $privatePath, ')
          ..write('internalName: $internalName, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('volumeName: $volumeName, ')
          ..write('contentUri: $contentUri, ')
          ..write('sourceDateModified: $sourceDateModified, ')
          ..write('mimeType: $mimeType, ')
          ..write('mediaHash: $mediaHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('sourceMode: $sourceMode, ')
          ..write('importOrigin: $importOrigin, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storageKind,
    privatePath,
    internalName,
    sourceKey,
    mediaStoreId,
    volumeName,
    contentUri,
    sourceDateModified,
    mimeType,
    mediaHash,
    importedAt,
    capturedAt,
    sourceMode,
    importOrigin,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItem &&
          other.id == this.id &&
          other.storageKind == this.storageKind &&
          other.privatePath == this.privatePath &&
          other.internalName == this.internalName &&
          other.sourceKey == this.sourceKey &&
          other.mediaStoreId == this.mediaStoreId &&
          other.volumeName == this.volumeName &&
          other.contentUri == this.contentUri &&
          other.sourceDateModified == this.sourceDateModified &&
          other.mimeType == this.mimeType &&
          other.mediaHash == this.mediaHash &&
          other.importedAt == this.importedAt &&
          other.capturedAt == this.capturedAt &&
          other.sourceMode == this.sourceMode &&
          other.importOrigin == this.importOrigin &&
          other.status == this.status);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItem> {
  final Value<int> id;
  final Value<String> storageKind;
  final Value<String?> privatePath;
  final Value<String?> internalName;
  final Value<String?> sourceKey;
  final Value<int?> mediaStoreId;
  final Value<String?> volumeName;
  final Value<String?> contentUri;
  final Value<DateTime?> sourceDateModified;
  final Value<String?> mimeType;
  final Value<String?> mediaHash;
  final Value<DateTime> importedAt;
  final Value<DateTime?> capturedAt;
  final Value<String> sourceMode;
  final Value<String> importOrigin;
  final Value<String> status;
  const MediaItemsCompanion({
    this.id = const Value.absent(),
    this.storageKind = const Value.absent(),
    this.privatePath = const Value.absent(),
    this.internalName = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.mediaStoreId = const Value.absent(),
    this.volumeName = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.sourceDateModified = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.mediaHash = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.sourceMode = const Value.absent(),
    this.importOrigin = const Value.absent(),
    this.status = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    this.id = const Value.absent(),
    this.storageKind = const Value.absent(),
    this.privatePath = const Value.absent(),
    this.internalName = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.mediaStoreId = const Value.absent(),
    this.volumeName = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.sourceDateModified = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.mediaHash = const Value.absent(),
    required DateTime importedAt,
    this.capturedAt = const Value.absent(),
    required String sourceMode,
    this.importOrigin = const Value.absent(),
    required String status,
  }) : importedAt = Value(importedAt),
       sourceMode = Value(sourceMode),
       status = Value(status);
  static Insertable<MediaItem> custom({
    Expression<int>? id,
    Expression<String>? storageKind,
    Expression<String>? privatePath,
    Expression<String>? internalName,
    Expression<String>? sourceKey,
    Expression<int>? mediaStoreId,
    Expression<String>? volumeName,
    Expression<String>? contentUri,
    Expression<DateTime>? sourceDateModified,
    Expression<String>? mimeType,
    Expression<String>? mediaHash,
    Expression<DateTime>? importedAt,
    Expression<DateTime>? capturedAt,
    Expression<String>? sourceMode,
    Expression<String>? importOrigin,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storageKind != null) 'storage_kind': storageKind,
      if (privatePath != null) 'private_path': privatePath,
      if (internalName != null) 'internal_name': internalName,
      if (sourceKey != null) 'source_key': sourceKey,
      if (mediaStoreId != null) 'media_store_id': mediaStoreId,
      if (volumeName != null) 'volume_name': volumeName,
      if (contentUri != null) 'content_uri': contentUri,
      if (sourceDateModified != null)
        'source_date_modified': sourceDateModified,
      if (mimeType != null) 'mime_type': mimeType,
      if (mediaHash != null) 'media_hash': mediaHash,
      if (importedAt != null) 'imported_at': importedAt,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (sourceMode != null) 'source_mode': sourceMode,
      if (importOrigin != null) 'import_origin': importOrigin,
      if (status != null) 'status': status,
    });
  }

  MediaItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? storageKind,
    Value<String?>? privatePath,
    Value<String?>? internalName,
    Value<String?>? sourceKey,
    Value<int?>? mediaStoreId,
    Value<String?>? volumeName,
    Value<String?>? contentUri,
    Value<DateTime?>? sourceDateModified,
    Value<String?>? mimeType,
    Value<String?>? mediaHash,
    Value<DateTime>? importedAt,
    Value<DateTime?>? capturedAt,
    Value<String>? sourceMode,
    Value<String>? importOrigin,
    Value<String>? status,
  }) {
    return MediaItemsCompanion(
      id: id ?? this.id,
      storageKind: storageKind ?? this.storageKind,
      privatePath: privatePath ?? this.privatePath,
      internalName: internalName ?? this.internalName,
      sourceKey: sourceKey ?? this.sourceKey,
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
      volumeName: volumeName ?? this.volumeName,
      contentUri: contentUri ?? this.contentUri,
      sourceDateModified: sourceDateModified ?? this.sourceDateModified,
      mimeType: mimeType ?? this.mimeType,
      mediaHash: mediaHash ?? this.mediaHash,
      importedAt: importedAt ?? this.importedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      sourceMode: sourceMode ?? this.sourceMode,
      importOrigin: importOrigin ?? this.importOrigin,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (storageKind.present) {
      map['storage_kind'] = Variable<String>(storageKind.value);
    }
    if (privatePath.present) {
      map['private_path'] = Variable<String>(privatePath.value);
    }
    if (internalName.present) {
      map['internal_name'] = Variable<String>(internalName.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (mediaStoreId.present) {
      map['media_store_id'] = Variable<int>(mediaStoreId.value);
    }
    if (volumeName.present) {
      map['volume_name'] = Variable<String>(volumeName.value);
    }
    if (contentUri.present) {
      map['content_uri'] = Variable<String>(contentUri.value);
    }
    if (sourceDateModified.present) {
      map['source_date_modified'] = Variable<DateTime>(
        sourceDateModified.value,
      );
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (mediaHash.present) {
      map['media_hash'] = Variable<String>(mediaHash.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (sourceMode.present) {
      map['source_mode'] = Variable<String>(sourceMode.value);
    }
    if (importOrigin.present) {
      map['import_origin'] = Variable<String>(importOrigin.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemsCompanion(')
          ..write('id: $id, ')
          ..write('storageKind: $storageKind, ')
          ..write('privatePath: $privatePath, ')
          ..write('internalName: $internalName, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('volumeName: $volumeName, ')
          ..write('contentUri: $contentUri, ')
          ..write('sourceDateModified: $sourceDateModified, ')
          ..write('mimeType: $mimeType, ')
          ..write('mediaHash: $mediaHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('sourceMode: $sourceMode, ')
          ..write('importOrigin: $importOrigin, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $OcrResultsTable extends OcrResults
    with TableInfo<$OcrResultsTable, OcrResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OcrResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaItemIdMeta = const VerificationMeta(
    'mediaItemId',
  );
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
    'media_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fullTextMeta = const VerificationMeta(
    'fullText',
  );
  @override
  late final GeneratedColumn<String> fullText = GeneratedColumn<String>(
    'full_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedTextMeta = const VerificationMeta(
    'normalizedText',
  );
  @override
  late final GeneratedColumn<String> normalizedText = GeneratedColumn<String>(
    'normalized_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<String> engineVersion = GeneratedColumn<String>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<DateTime> processedAt = GeneratedColumn<DateTime>(
    'processed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaItemId,
    fullText,
    normalizedText,
    engine,
    engineVersion,
    processedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ocr_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<OcrResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_item_id')) {
      context.handle(
        _mediaItemIdMeta,
        mediaItemId.isAcceptableOrUnknown(
          data['media_item_id']!,
          _mediaItemIdMeta,
        ),
      );
    }
    if (data.containsKey('full_text')) {
      context.handle(
        _fullTextMeta,
        fullText.isAcceptableOrUnknown(data['full_text']!, _fullTextMeta),
      );
    } else if (isInserting) {
      context.missing(_fullTextMeta);
    }
    if (data.containsKey('normalized_text')) {
      context.handle(
        _normalizedTextMeta,
        normalizedText.isAcceptableOrUnknown(
          data['normalized_text']!,
          _normalizedTextMeta,
        ),
      );
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaItemId};
  @override
  OcrResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OcrResult(
      mediaItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_item_id'],
      )!,
      fullText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_text'],
      )!,
      normalizedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_text'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_version'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processed_at'],
      )!,
    );
  }

  @override
  $OcrResultsTable createAlias(String alias) {
    return $OcrResultsTable(attachedDatabase, alias);
  }
}

class OcrResult extends DataClass implements Insertable<OcrResult> {
  final int mediaItemId;
  final String fullText;
  final String normalizedText;
  final String engine;
  final String engineVersion;
  final DateTime processedAt;
  const OcrResult({
    required this.mediaItemId,
    required this.fullText,
    required this.normalizedText,
    required this.engine,
    required this.engineVersion,
    required this.processedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['full_text'] = Variable<String>(fullText);
    map['normalized_text'] = Variable<String>(normalizedText);
    map['engine'] = Variable<String>(engine);
    map['engine_version'] = Variable<String>(engineVersion);
    map['processed_at'] = Variable<DateTime>(processedAt);
    return map;
  }

  OcrResultsCompanion toCompanion(bool nullToAbsent) {
    return OcrResultsCompanion(
      mediaItemId: Value(mediaItemId),
      fullText: Value(fullText),
      normalizedText: Value(normalizedText),
      engine: Value(engine),
      engineVersion: Value(engineVersion),
      processedAt: Value(processedAt),
    );
  }

  factory OcrResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OcrResult(
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      fullText: serializer.fromJson<String>(json['fullText']),
      normalizedText: serializer.fromJson<String>(json['normalizedText']),
      engine: serializer.fromJson<String>(json['engine']),
      engineVersion: serializer.fromJson<String>(json['engineVersion']),
      processedAt: serializer.fromJson<DateTime>(json['processedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'fullText': serializer.toJson<String>(fullText),
      'normalizedText': serializer.toJson<String>(normalizedText),
      'engine': serializer.toJson<String>(engine),
      'engineVersion': serializer.toJson<String>(engineVersion),
      'processedAt': serializer.toJson<DateTime>(processedAt),
    };
  }

  OcrResult copyWith({
    int? mediaItemId,
    String? fullText,
    String? normalizedText,
    String? engine,
    String? engineVersion,
    DateTime? processedAt,
  }) => OcrResult(
    mediaItemId: mediaItemId ?? this.mediaItemId,
    fullText: fullText ?? this.fullText,
    normalizedText: normalizedText ?? this.normalizedText,
    engine: engine ?? this.engine,
    engineVersion: engineVersion ?? this.engineVersion,
    processedAt: processedAt ?? this.processedAt,
  );
  OcrResult copyWithCompanion(OcrResultsCompanion data) {
    return OcrResult(
      mediaItemId: data.mediaItemId.present
          ? data.mediaItemId.value
          : this.mediaItemId,
      fullText: data.fullText.present ? data.fullText.value : this.fullText,
      normalizedText: data.normalizedText.present
          ? data.normalizedText.value
          : this.normalizedText,
      engine: data.engine.present ? data.engine.value : this.engine,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OcrResult(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('fullText: $fullText, ')
          ..write('normalizedText: $normalizedText, ')
          ..write('engine: $engine, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mediaItemId,
    fullText,
    normalizedText,
    engine,
    engineVersion,
    processedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrResult &&
          other.mediaItemId == this.mediaItemId &&
          other.fullText == this.fullText &&
          other.normalizedText == this.normalizedText &&
          other.engine == this.engine &&
          other.engineVersion == this.engineVersion &&
          other.processedAt == this.processedAt);
}

class OcrResultsCompanion extends UpdateCompanion<OcrResult> {
  final Value<int> mediaItemId;
  final Value<String> fullText;
  final Value<String> normalizedText;
  final Value<String> engine;
  final Value<String> engineVersion;
  final Value<DateTime> processedAt;
  const OcrResultsCompanion({
    this.mediaItemId = const Value.absent(),
    this.fullText = const Value.absent(),
    this.normalizedText = const Value.absent(),
    this.engine = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.processedAt = const Value.absent(),
  });
  OcrResultsCompanion.insert({
    this.mediaItemId = const Value.absent(),
    required String fullText,
    this.normalizedText = const Value.absent(),
    required String engine,
    required String engineVersion,
    required DateTime processedAt,
  }) : fullText = Value(fullText),
       engine = Value(engine),
       engineVersion = Value(engineVersion),
       processedAt = Value(processedAt);
  static Insertable<OcrResult> custom({
    Expression<int>? mediaItemId,
    Expression<String>? fullText,
    Expression<String>? normalizedText,
    Expression<String>? engine,
    Expression<String>? engineVersion,
    Expression<DateTime>? processedAt,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (fullText != null) 'full_text': fullText,
      if (normalizedText != null) 'normalized_text': normalizedText,
      if (engine != null) 'engine': engine,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (processedAt != null) 'processed_at': processedAt,
    });
  }

  OcrResultsCompanion copyWith({
    Value<int>? mediaItemId,
    Value<String>? fullText,
    Value<String>? normalizedText,
    Value<String>? engine,
    Value<String>? engineVersion,
    Value<DateTime>? processedAt,
  }) {
    return OcrResultsCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      fullText: fullText ?? this.fullText,
      normalizedText: normalizedText ?? this.normalizedText,
      engine: engine ?? this.engine,
      engineVersion: engineVersion ?? this.engineVersion,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (fullText.present) {
      map['full_text'] = Variable<String>(fullText.value);
    }
    if (normalizedText.present) {
      map['normalized_text'] = Variable<String>(normalizedText.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<String>(engineVersion.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<DateTime>(processedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OcrResultsCompanion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('fullText: $fullText, ')
          ..write('normalizedText: $normalizedText, ')
          ..write('engine: $engine, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }
}

class $ProcessingJobsTable extends ProcessingJobs
    with TableInfo<$ProcessingJobsTable, ProcessingJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProcessingJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mediaItemIdMeta = const VerificationMeta(
    'mediaItemId',
  );
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
    'media_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _jobTypeMeta = const VerificationMeta(
    'jobType',
  );
  @override
  late final GeneratedColumn<String> jobType = GeneratedColumn<String>(
    'job_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaItemId,
    jobType,
    status,
    attempts,
    errorCode,
    createdAt,
    startedAt,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProcessingJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_item_id')) {
      context.handle(
        _mediaItemIdMeta,
        mediaItemId.isAcceptableOrUnknown(
          data['media_item_id']!,
          _mediaItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaItemIdMeta);
    }
    if (data.containsKey('job_type')) {
      context.handle(
        _jobTypeMeta,
        jobType.isAcceptableOrUnknown(data['job_type']!, _jobTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_jobTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {mediaItemId, jobType},
  ];
  @override
  ProcessingJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mediaItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_item_id'],
      )!,
      jobType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
    );
  }

  @override
  $ProcessingJobsTable createAlias(String alias) {
    return $ProcessingJobsTable(attachedDatabase, alias);
  }
}

class ProcessingJob extends DataClass implements Insertable<ProcessingJob> {
  final int id;
  final int mediaItemId;
  final String jobType;
  final String status;
  final int attempts;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  const ProcessingJob({
    required this.id,
    required this.mediaItemId,
    required this.jobType,
    required this.status,
    required this.attempts,
    this.errorCode,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['job_type'] = Variable<String>(jobType);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  ProcessingJobsCompanion toCompanion(bool nullToAbsent) {
    return ProcessingJobsCompanion(
      id: Value(id),
      mediaItemId: Value(mediaItemId),
      jobType: Value(jobType),
      status: Value(status),
      attempts: Value(attempts),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
    );
  }

  factory ProcessingJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingJob(
      id: serializer.fromJson<int>(json['id']),
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      jobType: serializer.fromJson<String>(json['jobType']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'jobType': serializer.toJson<String>(jobType),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  ProcessingJob copyWith({
    int? id,
    int? mediaItemId,
    String? jobType,
    String? status,
    int? attempts,
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => ProcessingJob(
    id: id ?? this.id,
    mediaItemId: mediaItemId ?? this.mediaItemId,
    jobType: jobType ?? this.jobType,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  ProcessingJob copyWithCompanion(ProcessingJobsCompanion data) {
    return ProcessingJob(
      id: data.id.present ? data.id.value : this.id,
      mediaItemId: data.mediaItemId.present
          ? data.mediaItemId.value
          : this.mediaItemId,
      jobType: data.jobType.present ? data.jobType.value : this.jobType,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJob(')
          ..write('id: $id, ')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('jobType: $jobType, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mediaItemId,
    jobType,
    status,
    attempts,
    errorCode,
    createdAt,
    startedAt,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingJob &&
          other.id == this.id &&
          other.mediaItemId == this.mediaItemId &&
          other.jobType == this.jobType &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt);
}

class ProcessingJobsCompanion extends UpdateCompanion<ProcessingJob> {
  final Value<int> id;
  final Value<int> mediaItemId;
  final Value<String> jobType;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  const ProcessingJobsCompanion({
    this.id = const Value.absent(),
    this.mediaItemId = const Value.absent(),
    this.jobType = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
  });
  ProcessingJobsCompanion.insert({
    this.id = const Value.absent(),
    required int mediaItemId,
    required String jobType,
    required String status,
    this.attempts = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
  }) : mediaItemId = Value(mediaItemId),
       jobType = Value(jobType),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<ProcessingJob> custom({
    Expression<int>? id,
    Expression<int>? mediaItemId,
    Expression<String>? jobType,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (jobType != null) 'job_type': jobType,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
    });
  }

  ProcessingJobsCompanion copyWith({
    Value<int>? id,
    Value<int>? mediaItemId,
    Value<String>? jobType,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
  }) {
    return ProcessingJobsCompanion(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      jobType: jobType ?? this.jobType,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (jobType.present) {
      map['job_type'] = Variable<String>(jobType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingJobsCompanion(')
          ..write('id: $id, ')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('jobType: $jobType, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    parentId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final String normalizedName;
  final int? parentId;
  final DateTime createdAt;
  const Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    this.parentId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'parentId': serializer.toJson<int?>(parentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? normalizedName,
    Value<int?> parentId = const Value.absent(),
    DateTime? createdAt,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    parentId: parentId.present ? parentId.value : this.parentId,
    createdAt: createdAt ?? this.createdAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, normalizedName, parentId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.parentId == this.parentId &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int?> parentId;
  final Value<DateTime> createdAt;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String normalizedName,
    this.parentId = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? parentId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (parentId != null) 'parent_id': parentId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<int?>? parentId,
    Value<DateTime>? createdAt,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MediaCategoriesTable extends MediaCategories
    with TableInfo<$MediaCategoriesTable, MediaCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaItemIdMeta = const VerificationMeta(
    'mediaItemId',
  );
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
    'media_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [mediaItemId, categoryId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_item_id')) {
      context.handle(
        _mediaItemIdMeta,
        mediaItemId.isAcceptableOrUnknown(
          data['media_item_id']!,
          _mediaItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaItemIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaItemId, categoryId};
  @override
  MediaCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaCategory(
      mediaItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_item_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MediaCategoriesTable createAlias(String alias) {
    return $MediaCategoriesTable(attachedDatabase, alias);
  }
}

class MediaCategory extends DataClass implements Insertable<MediaCategory> {
  final int mediaItemId;
  final int categoryId;
  final DateTime createdAt;
  const MediaCategory({
    required this.mediaItemId,
    required this.categoryId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['category_id'] = Variable<int>(categoryId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MediaCategoriesCompanion toCompanion(bool nullToAbsent) {
    return MediaCategoriesCompanion(
      mediaItemId: Value(mediaItemId),
      categoryId: Value(categoryId),
      createdAt: Value(createdAt),
    );
  }

  factory MediaCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaCategory(
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'categoryId': serializer.toJson<int>(categoryId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MediaCategory copyWith({
    int? mediaItemId,
    int? categoryId,
    DateTime? createdAt,
  }) => MediaCategory(
    mediaItemId: mediaItemId ?? this.mediaItemId,
    categoryId: categoryId ?? this.categoryId,
    createdAt: createdAt ?? this.createdAt,
  );
  MediaCategory copyWithCompanion(MediaCategoriesCompanion data) {
    return MediaCategory(
      mediaItemId: data.mediaItemId.present
          ? data.mediaItemId.value
          : this.mediaItemId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaCategory(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaItemId, categoryId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaCategory &&
          other.mediaItemId == this.mediaItemId &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt);
}

class MediaCategoriesCompanion extends UpdateCompanion<MediaCategory> {
  final Value<int> mediaItemId;
  final Value<int> categoryId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MediaCategoriesCompanion({
    this.mediaItemId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCategoriesCompanion.insert({
    required int mediaItemId,
    required int categoryId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : mediaItemId = Value(mediaItemId),
       categoryId = Value(categoryId),
       createdAt = Value(createdAt);
  static Insertable<MediaCategory> custom({
    Expression<int>? mediaItemId,
    Expression<int>? categoryId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCategoriesCompanion copyWith({
    Value<int>? mediaItemId,
    Value<int>? categoryId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MediaCategoriesCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCategoriesCompanion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Tag({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Tag copyWith({
    int? id,
    String? name,
    String? normalizedName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, normalizedName, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String normalizedName,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MediaTagsTable extends MediaTags
    with TableInfo<$MediaTagsTable, MediaTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaItemIdMeta = const VerificationMeta(
    'mediaItemId',
  );
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
    'media_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [mediaItemId, tagId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_item_id')) {
      context.handle(
        _mediaItemIdMeta,
        mediaItemId.isAcceptableOrUnknown(
          data['media_item_id']!,
          _mediaItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaItemIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaItemId, tagId};
  @override
  MediaTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaTag(
      mediaItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_item_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MediaTagsTable createAlias(String alias) {
    return $MediaTagsTable(attachedDatabase, alias);
  }
}

class MediaTag extends DataClass implements Insertable<MediaTag> {
  final int mediaItemId;
  final int tagId;
  final DateTime createdAt;
  const MediaTag({
    required this.mediaItemId,
    required this.tagId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['tag_id'] = Variable<int>(tagId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MediaTagsCompanion toCompanion(bool nullToAbsent) {
    return MediaTagsCompanion(
      mediaItemId: Value(mediaItemId),
      tagId: Value(tagId),
      createdAt: Value(createdAt),
    );
  }

  factory MediaTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaTag(
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      tagId: serializer.fromJson<int>(json['tagId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'tagId': serializer.toJson<int>(tagId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MediaTag copyWith({int? mediaItemId, int? tagId, DateTime? createdAt}) =>
      MediaTag(
        mediaItemId: mediaItemId ?? this.mediaItemId,
        tagId: tagId ?? this.tagId,
        createdAt: createdAt ?? this.createdAt,
      );
  MediaTag copyWithCompanion(MediaTagsCompanion data) {
    return MediaTag(
      mediaItemId: data.mediaItemId.present
          ? data.mediaItemId.value
          : this.mediaItemId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaTag(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('tagId: $tagId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaItemId, tagId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaTag &&
          other.mediaItemId == this.mediaItemId &&
          other.tagId == this.tagId &&
          other.createdAt == this.createdAt);
}

class MediaTagsCompanion extends UpdateCompanion<MediaTag> {
  final Value<int> mediaItemId;
  final Value<int> tagId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MediaTagsCompanion({
    this.mediaItemId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaTagsCompanion.insert({
    required int mediaItemId,
    required int tagId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : mediaItemId = Value(mediaItemId),
       tagId = Value(tagId),
       createdAt = Value(createdAt);
  static Insertable<MediaTag> custom({
    Expression<int>? mediaItemId,
    Expression<int>? tagId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (tagId != null) 'tag_id': tagId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaTagsCompanion copyWith({
    Value<int>? mediaItemId,
    Value<int>? tagId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MediaTagsCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      tagId: tagId ?? this.tagId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaTagsCompanion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('tagId: $tagId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AutomaticImportSettingsTable extends AutomaticImportSettings
    with TableInfo<$AutomaticImportSettingsTable, AutomaticImportSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AutomaticImportSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastMediaIdMeta = const VerificationMeta(
    'lastMediaId',
  );
  @override
  late final GeneratedColumn<int> lastMediaId = GeneratedColumn<int>(
    'last_media_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledAtMeta = const VerificationMeta(
    'enabledAt',
  );
  @override
  late final GeneratedColumn<DateTime> enabledAt = GeneratedColumn<DateTime>(
    'enabled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScanAt = GeneratedColumn<DateTime>(
    'last_scan_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    enabled,
    lastMediaId,
    enabledAt,
    lastScanAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'automatic_import_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AutomaticImportSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('last_media_id')) {
      context.handle(
        _lastMediaIdMeta,
        lastMediaId.isAcceptableOrUnknown(
          data['last_media_id']!,
          _lastMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('enabled_at')) {
      context.handle(
        _enabledAtMeta,
        enabledAt.isAcceptableOrUnknown(data['enabled_at']!, _enabledAtMeta),
      );
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AutomaticImportSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AutomaticImportSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      lastMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_media_id'],
      ),
      enabledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enabled_at'],
      ),
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scan_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AutomaticImportSettingsTable createAlias(String alias) {
    return $AutomaticImportSettingsTable(attachedDatabase, alias);
  }
}

class AutomaticImportSetting extends DataClass
    implements Insertable<AutomaticImportSetting> {
  final int id;
  final bool enabled;
  final int? lastMediaId;
  final DateTime? enabledAt;
  final DateTime? lastScanAt;
  final DateTime updatedAt;
  const AutomaticImportSetting({
    required this.id,
    required this.enabled,
    this.lastMediaId,
    this.enabledAt,
    this.lastScanAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastMediaId != null) {
      map['last_media_id'] = Variable<int>(lastMediaId);
    }
    if (!nullToAbsent || enabledAt != null) {
      map['enabled_at'] = Variable<DateTime>(enabledAt);
    }
    if (!nullToAbsent || lastScanAt != null) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AutomaticImportSettingsCompanion toCompanion(bool nullToAbsent) {
    return AutomaticImportSettingsCompanion(
      id: Value(id),
      enabled: Value(enabled),
      lastMediaId: lastMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMediaId),
      enabledAt: enabledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(enabledAt),
      lastScanAt: lastScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AutomaticImportSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AutomaticImportSetting(
      id: serializer.fromJson<int>(json['id']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastMediaId: serializer.fromJson<int?>(json['lastMediaId']),
      enabledAt: serializer.fromJson<DateTime?>(json['enabledAt']),
      lastScanAt: serializer.fromJson<DateTime?>(json['lastScanAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'enabled': serializer.toJson<bool>(enabled),
      'lastMediaId': serializer.toJson<int?>(lastMediaId),
      'enabledAt': serializer.toJson<DateTime?>(enabledAt),
      'lastScanAt': serializer.toJson<DateTime?>(lastScanAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AutomaticImportSetting copyWith({
    int? id,
    bool? enabled,
    Value<int?> lastMediaId = const Value.absent(),
    Value<DateTime?> enabledAt = const Value.absent(),
    Value<DateTime?> lastScanAt = const Value.absent(),
    DateTime? updatedAt,
  }) => AutomaticImportSetting(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    lastMediaId: lastMediaId.present ? lastMediaId.value : this.lastMediaId,
    enabledAt: enabledAt.present ? enabledAt.value : this.enabledAt,
    lastScanAt: lastScanAt.present ? lastScanAt.value : this.lastScanAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AutomaticImportSetting copyWithCompanion(
    AutomaticImportSettingsCompanion data,
  ) {
    return AutomaticImportSetting(
      id: data.id.present ? data.id.value : this.id,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastMediaId: data.lastMediaId.present
          ? data.lastMediaId.value
          : this.lastMediaId,
      enabledAt: data.enabledAt.present ? data.enabledAt.value : this.enabledAt,
      lastScanAt: data.lastScanAt.present
          ? data.lastScanAt.value
          : this.lastScanAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AutomaticImportSetting(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('lastMediaId: $lastMediaId, ')
          ..write('enabledAt: $enabledAt, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, enabled, lastMediaId, enabledAt, lastScanAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AutomaticImportSetting &&
          other.id == this.id &&
          other.enabled == this.enabled &&
          other.lastMediaId == this.lastMediaId &&
          other.enabledAt == this.enabledAt &&
          other.lastScanAt == this.lastScanAt &&
          other.updatedAt == this.updatedAt);
}

class AutomaticImportSettingsCompanion
    extends UpdateCompanion<AutomaticImportSetting> {
  final Value<int> id;
  final Value<bool> enabled;
  final Value<int?> lastMediaId;
  final Value<DateTime?> enabledAt;
  final Value<DateTime?> lastScanAt;
  final Value<DateTime> updatedAt;
  const AutomaticImportSettingsCompanion({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastMediaId = const Value.absent(),
    this.enabledAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AutomaticImportSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastMediaId = const Value.absent(),
    this.enabledAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<AutomaticImportSetting> custom({
    Expression<int>? id,
    Expression<bool>? enabled,
    Expression<int>? lastMediaId,
    Expression<DateTime>? enabledAt,
    Expression<DateTime>? lastScanAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (enabled != null) 'enabled': enabled,
      if (lastMediaId != null) 'last_media_id': lastMediaId,
      if (enabledAt != null) 'enabled_at': enabledAt,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AutomaticImportSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? enabled,
    Value<int?>? lastMediaId,
    Value<DateTime?>? enabledAt,
    Value<DateTime?>? lastScanAt,
    Value<DateTime>? updatedAt,
  }) {
    return AutomaticImportSettingsCompanion(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      lastMediaId: lastMediaId ?? this.lastMediaId,
      enabledAt: enabledAt ?? this.enabledAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastMediaId.present) {
      map['last_media_id'] = Variable<int>(lastMediaId.value);
    }
    if (enabledAt.present) {
      map['enabled_at'] = Variable<DateTime>(enabledAt.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AutomaticImportSettingsCompanion(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('lastMediaId: $lastMediaId, ')
          ..write('enabledAt: $enabledAt, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ClassificationSuggestionsTable extends ClassificationSuggestions
    with TableInfo<$ClassificationSuggestionsTable, ClassificationSuggestion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationSuggestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaItemIdMeta = const VerificationMeta(
    'mediaItemId',
  );
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
    'media_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _suggestedCategoryNameMeta =
      const VerificationMeta('suggestedCategoryName');
  @override
  late final GeneratedColumn<String> suggestedCategoryName =
      GeneratedColumn<String>(
        'suggested_category_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasSuggestionMeta = const VerificationMeta(
    'hasSuggestion',
  );
  @override
  late final GeneratedColumn<bool> hasSuggestion = GeneratedColumn<bool>(
    'has_suggestion',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_suggestion" IN (0, 1))',
    ),
  );
  static const VerificationMeta _suggestedTagsJsonMeta = const VerificationMeta(
    'suggestedTagsJson',
  );
  @override
  late final GeneratedColumn<String> suggestedTagsJson =
      GeneratedColumn<String>(
        'suggested_tags_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _evidenceJsonMeta = const VerificationMeta(
    'evidenceJson',
  );
  @override
  late final GeneratedColumn<String> evidenceJson = GeneratedColumn<String>(
    'evidence_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewReasonMeta = const VerificationMeta(
    'reviewReason',
  );
  @override
  late final GeneratedColumn<String> reviewReason = GeneratedColumn<String>(
    'review_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<int> engineVersion = GeneratedColumn<int>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaItemId,
    suggestedCategoryName,
    confidence,
    hasSuggestion,
    suggestedTagsJson,
    evidenceJson,
    status,
    reviewReason,
    engineVersion,
    createdAt,
    updatedAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_suggestions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationSuggestion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_item_id')) {
      context.handle(
        _mediaItemIdMeta,
        mediaItemId.isAcceptableOrUnknown(
          data['media_item_id']!,
          _mediaItemIdMeta,
        ),
      );
    }
    if (data.containsKey('suggested_category_name')) {
      context.handle(
        _suggestedCategoryNameMeta,
        suggestedCategoryName.isAcceptableOrUnknown(
          data['suggested_category_name']!,
          _suggestedCategoryNameMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('has_suggestion')) {
      context.handle(
        _hasSuggestionMeta,
        hasSuggestion.isAcceptableOrUnknown(
          data['has_suggestion']!,
          _hasSuggestionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasSuggestionMeta);
    }
    if (data.containsKey('suggested_tags_json')) {
      context.handle(
        _suggestedTagsJsonMeta,
        suggestedTagsJson.isAcceptableOrUnknown(
          data['suggested_tags_json']!,
          _suggestedTagsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_suggestedTagsJsonMeta);
    }
    if (data.containsKey('evidence_json')) {
      context.handle(
        _evidenceJsonMeta,
        evidenceJson.isAcceptableOrUnknown(
          data['evidence_json']!,
          _evidenceJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('review_reason')) {
      context.handle(
        _reviewReasonMeta,
        reviewReason.isAcceptableOrUnknown(
          data['review_reason']!,
          _reviewReasonMeta,
        ),
      );
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaItemId};
  @override
  ClassificationSuggestion map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationSuggestion(
      mediaItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_item_id'],
      )!,
      suggestedCategoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_category_name'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      hasSuggestion: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_suggestion'],
      )!,
      suggestedTagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_tags_json'],
      )!,
      evidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reviewReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_reason'],
      ),
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}engine_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $ClassificationSuggestionsTable createAlias(String alias) {
    return $ClassificationSuggestionsTable(attachedDatabase, alias);
  }
}

class ClassificationSuggestion extends DataClass
    implements Insertable<ClassificationSuggestion> {
  final int mediaItemId;
  final String? suggestedCategoryName;
  final double confidence;
  final bool hasSuggestion;
  final String suggestedTagsJson;
  final String evidenceJson;
  final String status;
  final String? reviewReason;
  final int engineVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  const ClassificationSuggestion({
    required this.mediaItemId,
    this.suggestedCategoryName,
    required this.confidence,
    required this.hasSuggestion,
    required this.suggestedTagsJson,
    required this.evidenceJson,
    required this.status,
    this.reviewReason,
    required this.engineVersion,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    if (!nullToAbsent || suggestedCategoryName != null) {
      map['suggested_category_name'] = Variable<String>(suggestedCategoryName);
    }
    map['confidence'] = Variable<double>(confidence);
    map['has_suggestion'] = Variable<bool>(hasSuggestion);
    map['suggested_tags_json'] = Variable<String>(suggestedTagsJson);
    map['evidence_json'] = Variable<String>(evidenceJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reviewReason != null) {
      map['review_reason'] = Variable<String>(reviewReason);
    }
    map['engine_version'] = Variable<int>(engineVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  ClassificationSuggestionsCompanion toCompanion(bool nullToAbsent) {
    return ClassificationSuggestionsCompanion(
      mediaItemId: Value(mediaItemId),
      suggestedCategoryName: suggestedCategoryName == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCategoryName),
      confidence: Value(confidence),
      hasSuggestion: Value(hasSuggestion),
      suggestedTagsJson: Value(suggestedTagsJson),
      evidenceJson: Value(evidenceJson),
      status: Value(status),
      reviewReason: reviewReason == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewReason),
      engineVersion: Value(engineVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory ClassificationSuggestion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationSuggestion(
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      suggestedCategoryName: serializer.fromJson<String?>(
        json['suggestedCategoryName'],
      ),
      confidence: serializer.fromJson<double>(json['confidence']),
      hasSuggestion: serializer.fromJson<bool>(json['hasSuggestion']),
      suggestedTagsJson: serializer.fromJson<String>(json['suggestedTagsJson']),
      evidenceJson: serializer.fromJson<String>(json['evidenceJson']),
      status: serializer.fromJson<String>(json['status']),
      reviewReason: serializer.fromJson<String?>(json['reviewReason']),
      engineVersion: serializer.fromJson<int>(json['engineVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'suggestedCategoryName': serializer.toJson<String?>(
        suggestedCategoryName,
      ),
      'confidence': serializer.toJson<double>(confidence),
      'hasSuggestion': serializer.toJson<bool>(hasSuggestion),
      'suggestedTagsJson': serializer.toJson<String>(suggestedTagsJson),
      'evidenceJson': serializer.toJson<String>(evidenceJson),
      'status': serializer.toJson<String>(status),
      'reviewReason': serializer.toJson<String?>(reviewReason),
      'engineVersion': serializer.toJson<int>(engineVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  ClassificationSuggestion copyWith({
    int? mediaItemId,
    Value<String?> suggestedCategoryName = const Value.absent(),
    double? confidence,
    bool? hasSuggestion,
    String? suggestedTagsJson,
    String? evidenceJson,
    String? status,
    Value<String?> reviewReason = const Value.absent(),
    int? engineVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => ClassificationSuggestion(
    mediaItemId: mediaItemId ?? this.mediaItemId,
    suggestedCategoryName: suggestedCategoryName.present
        ? suggestedCategoryName.value
        : this.suggestedCategoryName,
    confidence: confidence ?? this.confidence,
    hasSuggestion: hasSuggestion ?? this.hasSuggestion,
    suggestedTagsJson: suggestedTagsJson ?? this.suggestedTagsJson,
    evidenceJson: evidenceJson ?? this.evidenceJson,
    status: status ?? this.status,
    reviewReason: reviewReason.present ? reviewReason.value : this.reviewReason,
    engineVersion: engineVersion ?? this.engineVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  ClassificationSuggestion copyWithCompanion(
    ClassificationSuggestionsCompanion data,
  ) {
    return ClassificationSuggestion(
      mediaItemId: data.mediaItemId.present
          ? data.mediaItemId.value
          : this.mediaItemId,
      suggestedCategoryName: data.suggestedCategoryName.present
          ? data.suggestedCategoryName.value
          : this.suggestedCategoryName,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      hasSuggestion: data.hasSuggestion.present
          ? data.hasSuggestion.value
          : this.hasSuggestion,
      suggestedTagsJson: data.suggestedTagsJson.present
          ? data.suggestedTagsJson.value
          : this.suggestedTagsJson,
      evidenceJson: data.evidenceJson.present
          ? data.evidenceJson.value
          : this.evidenceJson,
      status: data.status.present ? data.status.value : this.status,
      reviewReason: data.reviewReason.present
          ? data.reviewReason.value
          : this.reviewReason,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationSuggestion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('suggestedCategoryName: $suggestedCategoryName, ')
          ..write('confidence: $confidence, ')
          ..write('hasSuggestion: $hasSuggestion, ')
          ..write('suggestedTagsJson: $suggestedTagsJson, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('status: $status, ')
          ..write('reviewReason: $reviewReason, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mediaItemId,
    suggestedCategoryName,
    confidence,
    hasSuggestion,
    suggestedTagsJson,
    evidenceJson,
    status,
    reviewReason,
    engineVersion,
    createdAt,
    updatedAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationSuggestion &&
          other.mediaItemId == this.mediaItemId &&
          other.suggestedCategoryName == this.suggestedCategoryName &&
          other.confidence == this.confidence &&
          other.hasSuggestion == this.hasSuggestion &&
          other.suggestedTagsJson == this.suggestedTagsJson &&
          other.evidenceJson == this.evidenceJson &&
          other.status == this.status &&
          other.reviewReason == this.reviewReason &&
          other.engineVersion == this.engineVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.resolvedAt == this.resolvedAt);
}

class ClassificationSuggestionsCompanion
    extends UpdateCompanion<ClassificationSuggestion> {
  final Value<int> mediaItemId;
  final Value<String?> suggestedCategoryName;
  final Value<double> confidence;
  final Value<bool> hasSuggestion;
  final Value<String> suggestedTagsJson;
  final Value<String> evidenceJson;
  final Value<String> status;
  final Value<String?> reviewReason;
  final Value<int> engineVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> resolvedAt;
  const ClassificationSuggestionsCompanion({
    this.mediaItemId = const Value.absent(),
    this.suggestedCategoryName = const Value.absent(),
    this.confidence = const Value.absent(),
    this.hasSuggestion = const Value.absent(),
    this.suggestedTagsJson = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.status = const Value.absent(),
    this.reviewReason = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  ClassificationSuggestionsCompanion.insert({
    this.mediaItemId = const Value.absent(),
    this.suggestedCategoryName = const Value.absent(),
    required double confidence,
    required bool hasSuggestion,
    required String suggestedTagsJson,
    required String evidenceJson,
    required String status,
    this.reviewReason = const Value.absent(),
    required int engineVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.resolvedAt = const Value.absent(),
  }) : confidence = Value(confidence),
       hasSuggestion = Value(hasSuggestion),
       suggestedTagsJson = Value(suggestedTagsJson),
       evidenceJson = Value(evidenceJson),
       status = Value(status),
       engineVersion = Value(engineVersion),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ClassificationSuggestion> custom({
    Expression<int>? mediaItemId,
    Expression<String>? suggestedCategoryName,
    Expression<double>? confidence,
    Expression<bool>? hasSuggestion,
    Expression<String>? suggestedTagsJson,
    Expression<String>? evidenceJson,
    Expression<String>? status,
    Expression<String>? reviewReason,
    Expression<int>? engineVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (suggestedCategoryName != null)
        'suggested_category_name': suggestedCategoryName,
      if (confidence != null) 'confidence': confidence,
      if (hasSuggestion != null) 'has_suggestion': hasSuggestion,
      if (suggestedTagsJson != null) 'suggested_tags_json': suggestedTagsJson,
      if (evidenceJson != null) 'evidence_json': evidenceJson,
      if (status != null) 'status': status,
      if (reviewReason != null) 'review_reason': reviewReason,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  ClassificationSuggestionsCompanion copyWith({
    Value<int>? mediaItemId,
    Value<String?>? suggestedCategoryName,
    Value<double>? confidence,
    Value<bool>? hasSuggestion,
    Value<String>? suggestedTagsJson,
    Value<String>? evidenceJson,
    Value<String>? status,
    Value<String?>? reviewReason,
    Value<int>? engineVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? resolvedAt,
  }) {
    return ClassificationSuggestionsCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      suggestedCategoryName:
          suggestedCategoryName ?? this.suggestedCategoryName,
      confidence: confidence ?? this.confidence,
      hasSuggestion: hasSuggestion ?? this.hasSuggestion,
      suggestedTagsJson: suggestedTagsJson ?? this.suggestedTagsJson,
      evidenceJson: evidenceJson ?? this.evidenceJson,
      status: status ?? this.status,
      reviewReason: reviewReason ?? this.reviewReason,
      engineVersion: engineVersion ?? this.engineVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (suggestedCategoryName.present) {
      map['suggested_category_name'] = Variable<String>(
        suggestedCategoryName.value,
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (hasSuggestion.present) {
      map['has_suggestion'] = Variable<bool>(hasSuggestion.value);
    }
    if (suggestedTagsJson.present) {
      map['suggested_tags_json'] = Variable<String>(suggestedTagsJson.value);
    }
    if (evidenceJson.present) {
      map['evidence_json'] = Variable<String>(evidenceJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reviewReason.present) {
      map['review_reason'] = Variable<String>(reviewReason.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<int>(engineVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationSuggestionsCompanion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('suggestedCategoryName: $suggestedCategoryName, ')
          ..write('confidence: $confidence, ')
          ..write('hasSuggestion: $hasSuggestion, ')
          ..write('suggestedTagsJson: $suggestedTagsJson, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('status: $status, ')
          ..write('reviewReason: $reviewReason, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $ClassificationJobsTable extends ClassificationJobs
    with TableInfo<$ClassificationJobsTable, ClassificationJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaItemIdMeta = const VerificationMeta(
    'mediaItemId',
  );
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
    'media_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _availableAtMeta = const VerificationMeta(
    'availableAt',
  );
  @override
  late final GeneratedColumn<DateTime> availableAt = GeneratedColumn<DateTime>(
    'available_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineVersionMeta = const VerificationMeta(
    'engineVersion',
  );
  @override
  late final GeneratedColumn<int> engineVersion = GeneratedColumn<int>(
    'engine_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processingStartedAtMeta =
      const VerificationMeta('processingStartedAt');
  @override
  late final GeneratedColumn<DateTime> processingStartedAt =
      GeneratedColumn<DateTime>(
        'processing_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaItemId,
    state,
    attempts,
    availableAt,
    engineVersion,
    createdAt,
    updatedAt,
    processingStartedAt,
    lastErrorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_item_id')) {
      context.handle(
        _mediaItemIdMeta,
        mediaItemId.isAcceptableOrUnknown(
          data['media_item_id']!,
          _mediaItemIdMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('available_at')) {
      context.handle(
        _availableAtMeta,
        availableAt.isAcceptableOrUnknown(
          data['available_at']!,
          _availableAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availableAtMeta);
    }
    if (data.containsKey('engine_version')) {
      context.handle(
        _engineVersionMeta,
        engineVersion.isAcceptableOrUnknown(
          data['engine_version']!,
          _engineVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineVersionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('processing_started_at')) {
      context.handle(
        _processingStartedAtMeta,
        processingStartedAt.isAcceptableOrUnknown(
          data['processing_started_at']!,
          _processingStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaItemId};
  @override
  ClassificationJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationJob(
      mediaItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_item_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      availableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}available_at'],
      )!,
      engineVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}engine_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      processingStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processing_started_at'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
    );
  }

  @override
  $ClassificationJobsTable createAlias(String alias) {
    return $ClassificationJobsTable(attachedDatabase, alias);
  }
}

class ClassificationJob extends DataClass
    implements Insertable<ClassificationJob> {
  final int mediaItemId;
  final String state;
  final int attempts;
  final DateTime availableAt;
  final int engineVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processingStartedAt;
  final String? lastErrorCode;
  const ClassificationJob({
    required this.mediaItemId,
    required this.state,
    required this.attempts,
    required this.availableAt,
    required this.engineVersion,
    required this.createdAt,
    required this.updatedAt,
    this.processingStartedAt,
    this.lastErrorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    map['available_at'] = Variable<DateTime>(availableAt);
    map['engine_version'] = Variable<int>(engineVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || processingStartedAt != null) {
      map['processing_started_at'] = Variable<DateTime>(processingStartedAt);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    return map;
  }

  ClassificationJobsCompanion toCompanion(bool nullToAbsent) {
    return ClassificationJobsCompanion(
      mediaItemId: Value(mediaItemId),
      state: Value(state),
      attempts: Value(attempts),
      availableAt: Value(availableAt),
      engineVersion: Value(engineVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      processingStartedAt: processingStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processingStartedAt),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
    );
  }

  factory ClassificationJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationJob(
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      availableAt: serializer.fromJson<DateTime>(json['availableAt']),
      engineVersion: serializer.fromJson<int>(json['engineVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      processingStartedAt: serializer.fromJson<DateTime?>(
        json['processingStartedAt'],
      ),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'availableAt': serializer.toJson<DateTime>(availableAt),
      'engineVersion': serializer.toJson<int>(engineVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'processingStartedAt': serializer.toJson<DateTime?>(processingStartedAt),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
    };
  }

  ClassificationJob copyWith({
    int? mediaItemId,
    String? state,
    int? attempts,
    DateTime? availableAt,
    int? engineVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> processingStartedAt = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
  }) => ClassificationJob(
    mediaItemId: mediaItemId ?? this.mediaItemId,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    availableAt: availableAt ?? this.availableAt,
    engineVersion: engineVersion ?? this.engineVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    processingStartedAt: processingStartedAt.present
        ? processingStartedAt.value
        : this.processingStartedAt,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
  );
  ClassificationJob copyWithCompanion(ClassificationJobsCompanion data) {
    return ClassificationJob(
      mediaItemId: data.mediaItemId.present
          ? data.mediaItemId.value
          : this.mediaItemId,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      availableAt: data.availableAt.present
          ? data.availableAt.value
          : this.availableAt,
      engineVersion: data.engineVersion.present
          ? data.engineVersion.value
          : this.engineVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      processingStartedAt: data.processingStartedAt.present
          ? data.processingStartedAt.value
          : this.processingStartedAt,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationJob(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('processingStartedAt: $processingStartedAt, ')
          ..write('lastErrorCode: $lastErrorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mediaItemId,
    state,
    attempts,
    availableAt,
    engineVersion,
    createdAt,
    updatedAt,
    processingStartedAt,
    lastErrorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationJob &&
          other.mediaItemId == this.mediaItemId &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.availableAt == this.availableAt &&
          other.engineVersion == this.engineVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.processingStartedAt == this.processingStartedAt &&
          other.lastErrorCode == this.lastErrorCode);
}

class ClassificationJobsCompanion extends UpdateCompanion<ClassificationJob> {
  final Value<int> mediaItemId;
  final Value<String> state;
  final Value<int> attempts;
  final Value<DateTime> availableAt;
  final Value<int> engineVersion;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> processingStartedAt;
  final Value<String?> lastErrorCode;
  const ClassificationJobsCompanion({
    this.mediaItemId = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.processingStartedAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
  });
  ClassificationJobsCompanion.insert({
    this.mediaItemId = const Value.absent(),
    required String state,
    this.attempts = const Value.absent(),
    required DateTime availableAt,
    required int engineVersion,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.processingStartedAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
  }) : state = Value(state),
       availableAt = Value(availableAt),
       engineVersion = Value(engineVersion),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ClassificationJob> custom({
    Expression<int>? mediaItemId,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<DateTime>? availableAt,
    Expression<int>? engineVersion,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? processingStartedAt,
    Expression<String>? lastErrorCode,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (availableAt != null) 'available_at': availableAt,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (processingStartedAt != null)
        'processing_started_at': processingStartedAt,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
    });
  }

  ClassificationJobsCompanion copyWith({
    Value<int>? mediaItemId,
    Value<String>? state,
    Value<int>? attempts,
    Value<DateTime>? availableAt,
    Value<int>? engineVersion,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? processingStartedAt,
    Value<String?>? lastErrorCode,
  }) {
    return ClassificationJobsCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      availableAt: availableAt ?? this.availableAt,
      engineVersion: engineVersion ?? this.engineVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<DateTime>(availableAt.value);
    }
    if (engineVersion.present) {
      map['engine_version'] = Variable<int>(engineVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (processingStartedAt.present) {
      map['processing_started_at'] = Variable<DateTime>(
        processingStartedAt.value,
      );
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationJobsCompanion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('processingStartedAt: $processingStartedAt, ')
          ..write('lastErrorCode: $lastErrorCode')
          ..write(')'))
        .toString();
  }
}

class $ExistingScreenshotCandidatesTable extends ExistingScreenshotCandidates
    with
        TableInfo<
          $ExistingScreenshotCandidatesTable,
          ExistingScreenshotCandidate
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExistingScreenshotCandidatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaStoreIdMeta = const VerificationMeta(
    'mediaStoreId',
  );
  @override
  late final GeneratedColumn<int> mediaStoreId = GeneratedColumn<int>(
    'media_store_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeNameMeta = const VerificationMeta(
    'volumeName',
  );
  @override
  late final GeneratedColumn<String> volumeName = GeneratedColumn<String>(
    'volume_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentUriMeta = const VerificationMeta(
    'contentUri',
  );
  @override
  late final GeneratedColumn<String> contentUri = GeneratedColumn<String>(
    'content_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateModifiedMeta = const VerificationMeta(
    'dateModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateModified = GeneratedColumn<DateTime>(
    'date_modified',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discoveredAtMeta = const VerificationMeta(
    'discoveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> discoveredAt = GeneratedColumn<DateTime>(
    'discovered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _availabilityStateMeta = const VerificationMeta(
    'availabilityState',
  );
  @override
  late final GeneratedColumn<String> availabilityState =
      GeneratedColumn<String>(
        'availability_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    sourceKey,
    mediaStoreId,
    volumeName,
    contentUri,
    mimeType,
    capturedAt,
    dateModified,
    sizeBytes,
    width,
    height,
    discoveredAt,
    lastSeenAt,
    availabilityState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'existing_screenshot_candidates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExistingScreenshotCandidate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('media_store_id')) {
      context.handle(
        _mediaStoreIdMeta,
        mediaStoreId.isAcceptableOrUnknown(
          data['media_store_id']!,
          _mediaStoreIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaStoreIdMeta);
    }
    if (data.containsKey('volume_name')) {
      context.handle(
        _volumeNameMeta,
        volumeName.isAcceptableOrUnknown(data['volume_name']!, _volumeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeNameMeta);
    }
    if (data.containsKey('content_uri')) {
      context.handle(
        _contentUriMeta,
        contentUri.isAcceptableOrUnknown(data['content_uri']!, _contentUriMeta),
      );
    } else if (isInserting) {
      context.missing(_contentUriMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('date_modified')) {
      context.handle(
        _dateModifiedMeta,
        dateModified.isAcceptableOrUnknown(
          data['date_modified']!,
          _dateModifiedMeta,
        ),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('discovered_at')) {
      context.handle(
        _discoveredAtMeta,
        discoveredAt.isAcceptableOrUnknown(
          data['discovered_at']!,
          _discoveredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discoveredAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('availability_state')) {
      context.handle(
        _availabilityStateMeta,
        availabilityState.isAcceptableOrUnknown(
          data['availability_state']!,
          _availabilityStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availabilityStateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceKey};
  @override
  ExistingScreenshotCandidate map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExistingScreenshotCandidate(
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      mediaStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_store_id'],
      )!,
      volumeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}volume_name'],
      )!,
      contentUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_uri'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      ),
      dateModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_modified'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      discoveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}discovered_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      availabilityState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability_state'],
      )!,
    );
  }

  @override
  $ExistingScreenshotCandidatesTable createAlias(String alias) {
    return $ExistingScreenshotCandidatesTable(attachedDatabase, alias);
  }
}

class ExistingScreenshotCandidate extends DataClass
    implements Insertable<ExistingScreenshotCandidate> {
  final String sourceKey;
  final int mediaStoreId;
  final String volumeName;
  final String contentUri;
  final String? mimeType;
  final DateTime? capturedAt;
  final DateTime? dateModified;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final DateTime discoveredAt;
  final DateTime lastSeenAt;
  final String availabilityState;
  const ExistingScreenshotCandidate({
    required this.sourceKey,
    required this.mediaStoreId,
    required this.volumeName,
    required this.contentUri,
    this.mimeType,
    this.capturedAt,
    this.dateModified,
    this.sizeBytes,
    this.width,
    this.height,
    required this.discoveredAt,
    required this.lastSeenAt,
    required this.availabilityState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_key'] = Variable<String>(sourceKey);
    map['media_store_id'] = Variable<int>(mediaStoreId);
    map['volume_name'] = Variable<String>(volumeName);
    map['content_uri'] = Variable<String>(contentUri);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<DateTime>(capturedAt);
    }
    if (!nullToAbsent || dateModified != null) {
      map['date_modified'] = Variable<DateTime>(dateModified);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['discovered_at'] = Variable<DateTime>(discoveredAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['availability_state'] = Variable<String>(availabilityState);
    return map;
  }

  ExistingScreenshotCandidatesCompanion toCompanion(bool nullToAbsent) {
    return ExistingScreenshotCandidatesCompanion(
      sourceKey: Value(sourceKey),
      mediaStoreId: Value(mediaStoreId),
      volumeName: Value(volumeName),
      contentUri: Value(contentUri),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      dateModified: dateModified == null && nullToAbsent
          ? const Value.absent()
          : Value(dateModified),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      discoveredAt: Value(discoveredAt),
      lastSeenAt: Value(lastSeenAt),
      availabilityState: Value(availabilityState),
    );
  }

  factory ExistingScreenshotCandidate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExistingScreenshotCandidate(
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      mediaStoreId: serializer.fromJson<int>(json['mediaStoreId']),
      volumeName: serializer.fromJson<String>(json['volumeName']),
      contentUri: serializer.fromJson<String>(json['contentUri']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      capturedAt: serializer.fromJson<DateTime?>(json['capturedAt']),
      dateModified: serializer.fromJson<DateTime?>(json['dateModified']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      discoveredAt: serializer.fromJson<DateTime>(json['discoveredAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      availabilityState: serializer.fromJson<String>(json['availabilityState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceKey': serializer.toJson<String>(sourceKey),
      'mediaStoreId': serializer.toJson<int>(mediaStoreId),
      'volumeName': serializer.toJson<String>(volumeName),
      'contentUri': serializer.toJson<String>(contentUri),
      'mimeType': serializer.toJson<String?>(mimeType),
      'capturedAt': serializer.toJson<DateTime?>(capturedAt),
      'dateModified': serializer.toJson<DateTime?>(dateModified),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'discoveredAt': serializer.toJson<DateTime>(discoveredAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'availabilityState': serializer.toJson<String>(availabilityState),
    };
  }

  ExistingScreenshotCandidate copyWith({
    String? sourceKey,
    int? mediaStoreId,
    String? volumeName,
    String? contentUri,
    Value<String?> mimeType = const Value.absent(),
    Value<DateTime?> capturedAt = const Value.absent(),
    Value<DateTime?> dateModified = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    DateTime? discoveredAt,
    DateTime? lastSeenAt,
    String? availabilityState,
  }) => ExistingScreenshotCandidate(
    sourceKey: sourceKey ?? this.sourceKey,
    mediaStoreId: mediaStoreId ?? this.mediaStoreId,
    volumeName: volumeName ?? this.volumeName,
    contentUri: contentUri ?? this.contentUri,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    dateModified: dateModified.present ? dateModified.value : this.dateModified,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    discoveredAt: discoveredAt ?? this.discoveredAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    availabilityState: availabilityState ?? this.availabilityState,
  );
  ExistingScreenshotCandidate copyWithCompanion(
    ExistingScreenshotCandidatesCompanion data,
  ) {
    return ExistingScreenshotCandidate(
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      mediaStoreId: data.mediaStoreId.present
          ? data.mediaStoreId.value
          : this.mediaStoreId,
      volumeName: data.volumeName.present
          ? data.volumeName.value
          : this.volumeName,
      contentUri: data.contentUri.present
          ? data.contentUri.value
          : this.contentUri,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      dateModified: data.dateModified.present
          ? data.dateModified.value
          : this.dateModified,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      discoveredAt: data.discoveredAt.present
          ? data.discoveredAt.value
          : this.discoveredAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      availabilityState: data.availabilityState.present
          ? data.availabilityState.value
          : this.availabilityState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExistingScreenshotCandidate(')
          ..write('sourceKey: $sourceKey, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('volumeName: $volumeName, ')
          ..write('contentUri: $contentUri, ')
          ..write('mimeType: $mimeType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('dateModified: $dateModified, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('availabilityState: $availabilityState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceKey,
    mediaStoreId,
    volumeName,
    contentUri,
    mimeType,
    capturedAt,
    dateModified,
    sizeBytes,
    width,
    height,
    discoveredAt,
    lastSeenAt,
    availabilityState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExistingScreenshotCandidate &&
          other.sourceKey == this.sourceKey &&
          other.mediaStoreId == this.mediaStoreId &&
          other.volumeName == this.volumeName &&
          other.contentUri == this.contentUri &&
          other.mimeType == this.mimeType &&
          other.capturedAt == this.capturedAt &&
          other.dateModified == this.dateModified &&
          other.sizeBytes == this.sizeBytes &&
          other.width == this.width &&
          other.height == this.height &&
          other.discoveredAt == this.discoveredAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.availabilityState == this.availabilityState);
}

class ExistingScreenshotCandidatesCompanion
    extends UpdateCompanion<ExistingScreenshotCandidate> {
  final Value<String> sourceKey;
  final Value<int> mediaStoreId;
  final Value<String> volumeName;
  final Value<String> contentUri;
  final Value<String?> mimeType;
  final Value<DateTime?> capturedAt;
  final Value<DateTime?> dateModified;
  final Value<int?> sizeBytes;
  final Value<int?> width;
  final Value<int?> height;
  final Value<DateTime> discoveredAt;
  final Value<DateTime> lastSeenAt;
  final Value<String> availabilityState;
  final Value<int> rowid;
  const ExistingScreenshotCandidatesCompanion({
    this.sourceKey = const Value.absent(),
    this.mediaStoreId = const Value.absent(),
    this.volumeName = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.dateModified = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.discoveredAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.availabilityState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExistingScreenshotCandidatesCompanion.insert({
    required String sourceKey,
    required int mediaStoreId,
    required String volumeName,
    required String contentUri,
    this.mimeType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.dateModified = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    required DateTime discoveredAt,
    required DateTime lastSeenAt,
    required String availabilityState,
    this.rowid = const Value.absent(),
  }) : sourceKey = Value(sourceKey),
       mediaStoreId = Value(mediaStoreId),
       volumeName = Value(volumeName),
       contentUri = Value(contentUri),
       discoveredAt = Value(discoveredAt),
       lastSeenAt = Value(lastSeenAt),
       availabilityState = Value(availabilityState);
  static Insertable<ExistingScreenshotCandidate> custom({
    Expression<String>? sourceKey,
    Expression<int>? mediaStoreId,
    Expression<String>? volumeName,
    Expression<String>? contentUri,
    Expression<String>? mimeType,
    Expression<DateTime>? capturedAt,
    Expression<DateTime>? dateModified,
    Expression<int>? sizeBytes,
    Expression<int>? width,
    Expression<int>? height,
    Expression<DateTime>? discoveredAt,
    Expression<DateTime>? lastSeenAt,
    Expression<String>? availabilityState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceKey != null) 'source_key': sourceKey,
      if (mediaStoreId != null) 'media_store_id': mediaStoreId,
      if (volumeName != null) 'volume_name': volumeName,
      if (contentUri != null) 'content_uri': contentUri,
      if (mimeType != null) 'mime_type': mimeType,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (dateModified != null) 'date_modified': dateModified,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (discoveredAt != null) 'discovered_at': discoveredAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (availabilityState != null) 'availability_state': availabilityState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExistingScreenshotCandidatesCompanion copyWith({
    Value<String>? sourceKey,
    Value<int>? mediaStoreId,
    Value<String>? volumeName,
    Value<String>? contentUri,
    Value<String?>? mimeType,
    Value<DateTime?>? capturedAt,
    Value<DateTime?>? dateModified,
    Value<int?>? sizeBytes,
    Value<int?>? width,
    Value<int?>? height,
    Value<DateTime>? discoveredAt,
    Value<DateTime>? lastSeenAt,
    Value<String>? availabilityState,
    Value<int>? rowid,
  }) {
    return ExistingScreenshotCandidatesCompanion(
      sourceKey: sourceKey ?? this.sourceKey,
      mediaStoreId: mediaStoreId ?? this.mediaStoreId,
      volumeName: volumeName ?? this.volumeName,
      contentUri: contentUri ?? this.contentUri,
      mimeType: mimeType ?? this.mimeType,
      capturedAt: capturedAt ?? this.capturedAt,
      dateModified: dateModified ?? this.dateModified,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      availabilityState: availabilityState ?? this.availabilityState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (mediaStoreId.present) {
      map['media_store_id'] = Variable<int>(mediaStoreId.value);
    }
    if (volumeName.present) {
      map['volume_name'] = Variable<String>(volumeName.value);
    }
    if (contentUri.present) {
      map['content_uri'] = Variable<String>(contentUri.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (dateModified.present) {
      map['date_modified'] = Variable<DateTime>(dateModified.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (discoveredAt.present) {
      map['discovered_at'] = Variable<DateTime>(discoveredAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (availabilityState.present) {
      map['availability_state'] = Variable<String>(availabilityState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExistingScreenshotCandidatesCompanion(')
          ..write('sourceKey: $sourceKey, ')
          ..write('mediaStoreId: $mediaStoreId, ')
          ..write('volumeName: $volumeName, ')
          ..write('contentUri: $contentUri, ')
          ..write('mimeType: $mimeType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('dateModified: $dateModified, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('availabilityState: $availabilityState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExistingScreenshotInventoryStatesTable
    extends ExistingScreenshotInventoryStates
    with
        TableInfo<
          $ExistingScreenshotInventoryStatesTable,
          ExistingScreenshotInventoryState
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExistingScreenshotInventoryStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCompletedScanAtMeta =
      const VerificationMeta('lastCompletedScanAt');
  @override
  late final GeneratedColumn<DateTime> lastCompletedScanAt =
      GeneratedColumn<DateTime>(
        'last_completed_scan_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastScanWasPartialMeta =
      const VerificationMeta('lastScanWasPartial');
  @override
  late final GeneratedColumn<bool> lastScanWasPartial = GeneratedColumn<bool>(
    'last_scan_was_partial',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("last_scan_was_partial" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastCompletedScanAt,
    lastScanWasPartial,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'existing_screenshot_inventory_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExistingScreenshotInventoryState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_completed_scan_at')) {
      context.handle(
        _lastCompletedScanAtMeta,
        lastCompletedScanAt.isAcceptableOrUnknown(
          data['last_completed_scan_at']!,
          _lastCompletedScanAtMeta,
        ),
      );
    }
    if (data.containsKey('last_scan_was_partial')) {
      context.handle(
        _lastScanWasPartialMeta,
        lastScanWasPartial.isAcceptableOrUnknown(
          data['last_scan_was_partial']!,
          _lastScanWasPartialMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExistingScreenshotInventoryState map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExistingScreenshotInventoryState(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastCompletedScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_completed_scan_at'],
      ),
      lastScanWasPartial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}last_scan_was_partial'],
      )!,
    );
  }

  @override
  $ExistingScreenshotInventoryStatesTable createAlias(String alias) {
    return $ExistingScreenshotInventoryStatesTable(attachedDatabase, alias);
  }
}

class ExistingScreenshotInventoryState extends DataClass
    implements Insertable<ExistingScreenshotInventoryState> {
  final int id;
  final DateTime? lastCompletedScanAt;
  final bool lastScanWasPartial;
  const ExistingScreenshotInventoryState({
    required this.id,
    this.lastCompletedScanAt,
    required this.lastScanWasPartial,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastCompletedScanAt != null) {
      map['last_completed_scan_at'] = Variable<DateTime>(lastCompletedScanAt);
    }
    map['last_scan_was_partial'] = Variable<bool>(lastScanWasPartial);
    return map;
  }

  ExistingScreenshotInventoryStatesCompanion toCompanion(bool nullToAbsent) {
    return ExistingScreenshotInventoryStatesCompanion(
      id: Value(id),
      lastCompletedScanAt: lastCompletedScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCompletedScanAt),
      lastScanWasPartial: Value(lastScanWasPartial),
    );
  }

  factory ExistingScreenshotInventoryState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExistingScreenshotInventoryState(
      id: serializer.fromJson<int>(json['id']),
      lastCompletedScanAt: serializer.fromJson<DateTime?>(
        json['lastCompletedScanAt'],
      ),
      lastScanWasPartial: serializer.fromJson<bool>(json['lastScanWasPartial']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastCompletedScanAt': serializer.toJson<DateTime?>(lastCompletedScanAt),
      'lastScanWasPartial': serializer.toJson<bool>(lastScanWasPartial),
    };
  }

  ExistingScreenshotInventoryState copyWith({
    int? id,
    Value<DateTime?> lastCompletedScanAt = const Value.absent(),
    bool? lastScanWasPartial,
  }) => ExistingScreenshotInventoryState(
    id: id ?? this.id,
    lastCompletedScanAt: lastCompletedScanAt.present
        ? lastCompletedScanAt.value
        : this.lastCompletedScanAt,
    lastScanWasPartial: lastScanWasPartial ?? this.lastScanWasPartial,
  );
  ExistingScreenshotInventoryState copyWithCompanion(
    ExistingScreenshotInventoryStatesCompanion data,
  ) {
    return ExistingScreenshotInventoryState(
      id: data.id.present ? data.id.value : this.id,
      lastCompletedScanAt: data.lastCompletedScanAt.present
          ? data.lastCompletedScanAt.value
          : this.lastCompletedScanAt,
      lastScanWasPartial: data.lastScanWasPartial.present
          ? data.lastScanWasPartial.value
          : this.lastScanWasPartial,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExistingScreenshotInventoryState(')
          ..write('id: $id, ')
          ..write('lastCompletedScanAt: $lastCompletedScanAt, ')
          ..write('lastScanWasPartial: $lastScanWasPartial')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lastCompletedScanAt, lastScanWasPartial);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExistingScreenshotInventoryState &&
          other.id == this.id &&
          other.lastCompletedScanAt == this.lastCompletedScanAt &&
          other.lastScanWasPartial == this.lastScanWasPartial);
}

class ExistingScreenshotInventoryStatesCompanion
    extends UpdateCompanion<ExistingScreenshotInventoryState> {
  final Value<int> id;
  final Value<DateTime?> lastCompletedScanAt;
  final Value<bool> lastScanWasPartial;
  const ExistingScreenshotInventoryStatesCompanion({
    this.id = const Value.absent(),
    this.lastCompletedScanAt = const Value.absent(),
    this.lastScanWasPartial = const Value.absent(),
  });
  ExistingScreenshotInventoryStatesCompanion.insert({
    this.id = const Value.absent(),
    this.lastCompletedScanAt = const Value.absent(),
    this.lastScanWasPartial = const Value.absent(),
  });
  static Insertable<ExistingScreenshotInventoryState> custom({
    Expression<int>? id,
    Expression<DateTime>? lastCompletedScanAt,
    Expression<bool>? lastScanWasPartial,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastCompletedScanAt != null)
        'last_completed_scan_at': lastCompletedScanAt,
      if (lastScanWasPartial != null)
        'last_scan_was_partial': lastScanWasPartial,
    });
  }

  ExistingScreenshotInventoryStatesCompanion copyWith({
    Value<int>? id,
    Value<DateTime?>? lastCompletedScanAt,
    Value<bool>? lastScanWasPartial,
  }) {
    return ExistingScreenshotInventoryStatesCompanion(
      id: id ?? this.id,
      lastCompletedScanAt: lastCompletedScanAt ?? this.lastCompletedScanAt,
      lastScanWasPartial: lastScanWasPartial ?? this.lastScanWasPartial,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastCompletedScanAt.present) {
      map['last_completed_scan_at'] = Variable<DateTime>(
        lastCompletedScanAt.value,
      );
    }
    if (lastScanWasPartial.present) {
      map['last_scan_was_partial'] = Variable<bool>(lastScanWasPartial.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExistingScreenshotInventoryStatesCompanion(')
          ..write('id: $id, ')
          ..write('lastCompletedScanAt: $lastCompletedScanAt, ')
          ..write('lastScanWasPartial: $lastScanWasPartial')
          ..write(')'))
        .toString();
  }
}

class $HistoricalMediaImportJobsTable extends HistoricalMediaImportJobs
    with TableInfo<$HistoricalMediaImportJobsTable, HistoricalMediaImportJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoricalMediaImportJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES existing_screenshot_candidates (source_key) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _availableAtMeta = const VerificationMeta(
    'availableAt',
  );
  @override
  late final GeneratedColumn<DateTime> availableAt = GeneratedColumn<DateTime>(
    'available_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processingStartedAtMeta =
      const VerificationMeta('processingStartedAt');
  @override
  late final GeneratedColumn<DateTime> processingStartedAt =
      GeneratedColumn<DateTime>(
        'processing_started_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceKey,
    state,
    attempts,
    availableAt,
    createdAt,
    updatedAt,
    processingStartedAt,
    lastErrorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historical_media_import_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoricalMediaImportJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('available_at')) {
      context.handle(
        _availableAtMeta,
        availableAt.isAcceptableOrUnknown(
          data['available_at']!,
          _availableAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availableAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('processing_started_at')) {
      context.handle(
        _processingStartedAtMeta,
        processingStartedAt.isAcceptableOrUnknown(
          data['processing_started_at']!,
          _processingStartedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceKey};
  @override
  HistoricalMediaImportJob map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoricalMediaImportJob(
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      availableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}available_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      processingStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}processing_started_at'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
    );
  }

  @override
  $HistoricalMediaImportJobsTable createAlias(String alias) {
    return $HistoricalMediaImportJobsTable(attachedDatabase, alias);
  }
}

class HistoricalMediaImportJob extends DataClass
    implements Insertable<HistoricalMediaImportJob> {
  final String sourceKey;
  final String state;
  final int attempts;
  final DateTime availableAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processingStartedAt;
  final String? lastErrorCode;
  const HistoricalMediaImportJob({
    required this.sourceKey,
    required this.state,
    required this.attempts,
    required this.availableAt,
    required this.createdAt,
    required this.updatedAt,
    this.processingStartedAt,
    this.lastErrorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_key'] = Variable<String>(sourceKey);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    map['available_at'] = Variable<DateTime>(availableAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || processingStartedAt != null) {
      map['processing_started_at'] = Variable<DateTime>(processingStartedAt);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    return map;
  }

  HistoricalMediaImportJobsCompanion toCompanion(bool nullToAbsent) {
    return HistoricalMediaImportJobsCompanion(
      sourceKey: Value(sourceKey),
      state: Value(state),
      attempts: Value(attempts),
      availableAt: Value(availableAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      processingStartedAt: processingStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processingStartedAt),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
    );
  }

  factory HistoricalMediaImportJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoricalMediaImportJob(
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      availableAt: serializer.fromJson<DateTime>(json['availableAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      processingStartedAt: serializer.fromJson<DateTime?>(
        json['processingStartedAt'],
      ),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceKey': serializer.toJson<String>(sourceKey),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'availableAt': serializer.toJson<DateTime>(availableAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'processingStartedAt': serializer.toJson<DateTime?>(processingStartedAt),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
    };
  }

  HistoricalMediaImportJob copyWith({
    String? sourceKey,
    String? state,
    int? attempts,
    DateTime? availableAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> processingStartedAt = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
  }) => HistoricalMediaImportJob(
    sourceKey: sourceKey ?? this.sourceKey,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    availableAt: availableAt ?? this.availableAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    processingStartedAt: processingStartedAt.present
        ? processingStartedAt.value
        : this.processingStartedAt,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
  );
  HistoricalMediaImportJob copyWithCompanion(
    HistoricalMediaImportJobsCompanion data,
  ) {
    return HistoricalMediaImportJob(
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      availableAt: data.availableAt.present
          ? data.availableAt.value
          : this.availableAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      processingStartedAt: data.processingStartedAt.present
          ? data.processingStartedAt.value
          : this.processingStartedAt,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoricalMediaImportJob(')
          ..write('sourceKey: $sourceKey, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('processingStartedAt: $processingStartedAt, ')
          ..write('lastErrorCode: $lastErrorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceKey,
    state,
    attempts,
    availableAt,
    createdAt,
    updatedAt,
    processingStartedAt,
    lastErrorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoricalMediaImportJob &&
          other.sourceKey == this.sourceKey &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.availableAt == this.availableAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.processingStartedAt == this.processingStartedAt &&
          other.lastErrorCode == this.lastErrorCode);
}

class HistoricalMediaImportJobsCompanion
    extends UpdateCompanion<HistoricalMediaImportJob> {
  final Value<String> sourceKey;
  final Value<String> state;
  final Value<int> attempts;
  final Value<DateTime> availableAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> processingStartedAt;
  final Value<String?> lastErrorCode;
  final Value<int> rowid;
  const HistoricalMediaImportJobsCompanion({
    this.sourceKey = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.processingStartedAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoricalMediaImportJobsCompanion.insert({
    required String sourceKey,
    required String state,
    this.attempts = const Value.absent(),
    required DateTime availableAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.processingStartedAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceKey = Value(sourceKey),
       state = Value(state),
       availableAt = Value(availableAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<HistoricalMediaImportJob> custom({
    Expression<String>? sourceKey,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<DateTime>? availableAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? processingStartedAt,
    Expression<String>? lastErrorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceKey != null) 'source_key': sourceKey,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (availableAt != null) 'available_at': availableAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (processingStartedAt != null)
        'processing_started_at': processingStartedAt,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoricalMediaImportJobsCompanion copyWith({
    Value<String>? sourceKey,
    Value<String>? state,
    Value<int>? attempts,
    Value<DateTime>? availableAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? processingStartedAt,
    Value<String?>? lastErrorCode,
    Value<int>? rowid,
  }) {
    return HistoricalMediaImportJobsCompanion(
      sourceKey: sourceKey ?? this.sourceKey,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      availableAt: availableAt ?? this.availableAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<DateTime>(availableAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (processingStartedAt.present) {
      map['processing_started_at'] = Variable<DateTime>(
        processingStartedAt.value,
      );
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoricalMediaImportJobsCompanion(')
          ..write('sourceKey: $sourceKey, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('processingStartedAt: $processingStartedAt, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ContextoDatabase extends GeneratedDatabase {
  _$ContextoDatabase(QueryExecutor e) : super(e);
  $ContextoDatabaseManager get managers => $ContextoDatabaseManager(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $OcrResultsTable ocrResults = $OcrResultsTable(this);
  late final $ProcessingJobsTable processingJobs = $ProcessingJobsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $MediaCategoriesTable mediaCategories = $MediaCategoriesTable(
    this,
  );
  late final $TagsTable tags = $TagsTable(this);
  late final $MediaTagsTable mediaTags = $MediaTagsTable(this);
  late final $AutomaticImportSettingsTable automaticImportSettings =
      $AutomaticImportSettingsTable(this);
  late final $ClassificationSuggestionsTable classificationSuggestions =
      $ClassificationSuggestionsTable(this);
  late final $ClassificationJobsTable classificationJobs =
      $ClassificationJobsTable(this);
  late final $ExistingScreenshotCandidatesTable existingScreenshotCandidates =
      $ExistingScreenshotCandidatesTable(this);
  late final $ExistingScreenshotInventoryStatesTable
  existingScreenshotInventoryStates = $ExistingScreenshotInventoryStatesTable(
    this,
  );
  late final $HistoricalMediaImportJobsTable historicalMediaImportJobs =
      $HistoricalMediaImportJobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaItems,
    ocrResults,
    processingJobs,
    categories,
    mediaCategories,
    tags,
    mediaTags,
    automaticImportSettings,
    classificationSuggestions,
    classificationJobs,
    existingScreenshotCandidates,
    existingScreenshotInventoryStates,
    historicalMediaImportJobs,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ocr_results', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('processing_jobs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_categories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_categories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('classification_suggestions', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('classification_jobs', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MediaItemsTableCreateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<int> id,
      Value<String> storageKind,
      Value<String?> privatePath,
      Value<String?> internalName,
      Value<String?> sourceKey,
      Value<int?> mediaStoreId,
      Value<String?> volumeName,
      Value<String?> contentUri,
      Value<DateTime?> sourceDateModified,
      Value<String?> mimeType,
      Value<String?> mediaHash,
      required DateTime importedAt,
      Value<DateTime?> capturedAt,
      required String sourceMode,
      Value<String> importOrigin,
      required String status,
    });
typedef $$MediaItemsTableUpdateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<int> id,
      Value<String> storageKind,
      Value<String?> privatePath,
      Value<String?> internalName,
      Value<String?> sourceKey,
      Value<int?> mediaStoreId,
      Value<String?> volumeName,
      Value<String?> contentUri,
      Value<DateTime?> sourceDateModified,
      Value<String?> mimeType,
      Value<String?> mediaHash,
      Value<DateTime> importedAt,
      Value<DateTime?> capturedAt,
      Value<String> sourceMode,
      Value<String> importOrigin,
      Value<String> status,
    });

final class $$MediaItemsTableReferences
    extends BaseReferences<_$ContextoDatabase, $MediaItemsTable, MediaItem> {
  $$MediaItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OcrResultsTable, List<OcrResult>>
  _ocrResultsRefsTable(_$ContextoDatabase db) => MultiTypedResultKey.fromTable(
    db.ocrResults,
    aliasName: 'media_items__id__ocr_results__media_item_id',
  );

  $$OcrResultsTableProcessedTableManager get ocrResultsRefs {
    final manager = $$OcrResultsTableTableManager(
      $_db,
      $_db.ocrResults,
    ).filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_ocrResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProcessingJobsTable, List<ProcessingJob>>
  _processingJobsRefsTable(_$ContextoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.processingJobs,
        aliasName: 'media_items__id__processing_jobs__media_item_id',
      );

  $$ProcessingJobsTableProcessedTableManager get processingJobsRefs {
    final manager = $$ProcessingJobsTableTableManager(
      $_db,
      $_db.processingJobs,
    ).filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_processingJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MediaCategoriesTable, List<MediaCategory>>
  _mediaCategoriesRefsTable(_$ContextoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mediaCategories,
        aliasName: 'media_items__id__media_categories__media_item_id',
      );

  $$MediaCategoriesTableProcessedTableManager get mediaCategoriesRefs {
    final manager = $$MediaCategoriesTableTableManager(
      $_db,
      $_db.mediaCategories,
    ).filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mediaCategoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MediaTagsTable, List<MediaTag>>
  _mediaTagsRefsTable(_$ContextoDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaTags,
    aliasName: 'media_items__id__media_tags__media_item_id',
  );

  $$MediaTagsTableProcessedTableManager get mediaTagsRefs {
    final manager = $$MediaTagsTableTableManager(
      $_db,
      $_db.mediaTags,
    ).filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ClassificationSuggestionsTable,
    List<ClassificationSuggestion>
  >
  _classificationSuggestionsRefsTable(_$ContextoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.classificationSuggestions,
        aliasName: 'media_items__id__classification_suggestions__media_item_id',
      );

  $$ClassificationSuggestionsTableProcessedTableManager
  get classificationSuggestionsRefs {
    final manager = $$ClassificationSuggestionsTableTableManager(
      $_db,
      $_db.classificationSuggestions,
    ).filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _classificationSuggestionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ClassificationJobsTable, List<ClassificationJob>>
  _classificationJobsRefsTable(_$ContextoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.classificationJobs,
        aliasName: 'media_items__id__classification_jobs__media_item_id',
      );

  $$ClassificationJobsTableProcessedTableManager get classificationJobsRefs {
    final manager = $$ClassificationJobsTableTableManager(
      $_db,
      $_db.classificationJobs,
    ).filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _classificationJobsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MediaItemsTableFilterComposer
    extends Composer<_$ContextoDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageKind => $composableBuilder(
    column: $table.storageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privatePath => $composableBuilder(
    column: $table.privatePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get internalName => $composableBuilder(
    column: $table.internalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sourceDateModified => $composableBuilder(
    column: $table.sourceDateModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaHash => $composableBuilder(
    column: $table.mediaHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMode => $composableBuilder(
    column: $table.sourceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importOrigin => $composableBuilder(
    column: $table.importOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> ocrResultsRefs(
    Expression<bool> Function($$OcrResultsTableFilterComposer f) f,
  ) {
    final $$OcrResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ocrResults,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OcrResultsTableFilterComposer(
            $db: $db,
            $table: $db.ocrResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> processingJobsRefs(
    Expression<bool> Function($$ProcessingJobsTableFilterComposer f) f,
  ) {
    final $$ProcessingJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableFilterComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mediaCategoriesRefs(
    Expression<bool> Function($$MediaCategoriesTableFilterComposer f) f,
  ) {
    final $$MediaCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaCategories,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.mediaCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mediaTagsRefs(
    Expression<bool> Function($$MediaTagsTableFilterComposer f) f,
  ) {
    final $$MediaTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaTags,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaTagsTableFilterComposer(
            $db: $db,
            $table: $db.mediaTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> classificationSuggestionsRefs(
    Expression<bool> Function($$ClassificationSuggestionsTableFilterComposer f)
    f,
  ) {
    final $$ClassificationSuggestionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.classificationSuggestions,
          getReferencedColumn: (t) => t.mediaItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ClassificationSuggestionsTableFilterComposer(
                $db: $db,
                $table: $db.classificationSuggestions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> classificationJobsRefs(
    Expression<bool> Function($$ClassificationJobsTableFilterComposer f) f,
  ) {
    final $$ClassificationJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.classificationJobs,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassificationJobsTableFilterComposer(
            $db: $db,
            $table: $db.classificationJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageKind => $composableBuilder(
    column: $table.storageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privatePath => $composableBuilder(
    column: $table.privatePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get internalName => $composableBuilder(
    column: $table.internalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sourceDateModified => $composableBuilder(
    column: $table.sourceDateModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaHash => $composableBuilder(
    column: $table.mediaHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMode => $composableBuilder(
    column: $table.sourceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importOrigin => $composableBuilder(
    column: $table.importOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storageKind => $composableBuilder(
    column: $table.storageKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get privatePath => $composableBuilder(
    column: $table.privatePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get internalName => $composableBuilder(
    column: $table.internalName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get sourceDateModified => $composableBuilder(
    column: $table.sourceDateModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get mediaHash =>
      $composableBuilder(column: $table.mediaHash, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceMode => $composableBuilder(
    column: $table.sourceMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importOrigin => $composableBuilder(
    column: $table.importOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  Expression<T> ocrResultsRefs<T extends Object>(
    Expression<T> Function($$OcrResultsTableAnnotationComposer a) f,
  ) {
    final $$OcrResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ocrResults,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OcrResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.ocrResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> processingJobsRefs<T extends Object>(
    Expression<T> Function($$ProcessingJobsTableAnnotationComposer a) f,
  ) {
    final $$ProcessingJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.processingJobs,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProcessingJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.processingJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mediaCategoriesRefs<T extends Object>(
    Expression<T> Function($$MediaCategoriesTableAnnotationComposer a) f,
  ) {
    final $$MediaCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaCategories,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mediaTagsRefs<T extends Object>(
    Expression<T> Function($$MediaTagsTableAnnotationComposer a) f,
  ) {
    final $$MediaTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaTags,
      getReferencedColumn: (t) => t.mediaItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> classificationSuggestionsRefs<T extends Object>(
    Expression<T> Function($$ClassificationSuggestionsTableAnnotationComposer a)
    f,
  ) {
    final $$ClassificationSuggestionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.classificationSuggestions,
          getReferencedColumn: (t) => t.mediaItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ClassificationSuggestionsTableAnnotationComposer(
                $db: $db,
                $table: $db.classificationSuggestions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> classificationJobsRefs<T extends Object>(
    Expression<T> Function($$ClassificationJobsTableAnnotationComposer a) f,
  ) {
    final $$ClassificationJobsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.classificationJobs,
          getReferencedColumn: (t) => t.mediaItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ClassificationJobsTableAnnotationComposer(
                $db: $db,
                $table: $db.classificationJobs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MediaItemsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $MediaItemsTable,
          MediaItem,
          $$MediaItemsTableFilterComposer,
          $$MediaItemsTableOrderingComposer,
          $$MediaItemsTableAnnotationComposer,
          $$MediaItemsTableCreateCompanionBuilder,
          $$MediaItemsTableUpdateCompanionBuilder,
          (MediaItem, $$MediaItemsTableReferences),
          MediaItem,
          PrefetchHooks Function({
            bool ocrResultsRefs,
            bool processingJobsRefs,
            bool mediaCategoriesRefs,
            bool mediaTagsRefs,
            bool classificationSuggestionsRefs,
            bool classificationJobsRefs,
          })
        > {
  $$MediaItemsTableTableManager(_$ContextoDatabase db, $MediaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> storageKind = const Value.absent(),
                Value<String?> privatePath = const Value.absent(),
                Value<String?> internalName = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<int?> mediaStoreId = const Value.absent(),
                Value<String?> volumeName = const Value.absent(),
                Value<String?> contentUri = const Value.absent(),
                Value<DateTime?> sourceDateModified = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> mediaHash = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<String> sourceMode = const Value.absent(),
                Value<String> importOrigin = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => MediaItemsCompanion(
                id: id,
                storageKind: storageKind,
                privatePath: privatePath,
                internalName: internalName,
                sourceKey: sourceKey,
                mediaStoreId: mediaStoreId,
                volumeName: volumeName,
                contentUri: contentUri,
                sourceDateModified: sourceDateModified,
                mimeType: mimeType,
                mediaHash: mediaHash,
                importedAt: importedAt,
                capturedAt: capturedAt,
                sourceMode: sourceMode,
                importOrigin: importOrigin,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> storageKind = const Value.absent(),
                Value<String?> privatePath = const Value.absent(),
                Value<String?> internalName = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<int?> mediaStoreId = const Value.absent(),
                Value<String?> volumeName = const Value.absent(),
                Value<String?> contentUri = const Value.absent(),
                Value<DateTime?> sourceDateModified = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> mediaHash = const Value.absent(),
                required DateTime importedAt,
                Value<DateTime?> capturedAt = const Value.absent(),
                required String sourceMode,
                Value<String> importOrigin = const Value.absent(),
                required String status,
              }) => MediaItemsCompanion.insert(
                id: id,
                storageKind: storageKind,
                privatePath: privatePath,
                internalName: internalName,
                sourceKey: sourceKey,
                mediaStoreId: mediaStoreId,
                volumeName: volumeName,
                contentUri: contentUri,
                sourceDateModified: sourceDateModified,
                mimeType: mimeType,
                mediaHash: mediaHash,
                importedAt: importedAt,
                capturedAt: capturedAt,
                sourceMode: sourceMode,
                importOrigin: importOrigin,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ocrResultsRefs = false,
                processingJobsRefs = false,
                mediaCategoriesRefs = false,
                mediaTagsRefs = false,
                classificationSuggestionsRefs = false,
                classificationJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (ocrResultsRefs) db.ocrResults,
                    if (processingJobsRefs) db.processingJobs,
                    if (mediaCategoriesRefs) db.mediaCategories,
                    if (mediaTagsRefs) db.mediaTags,
                    if (classificationSuggestionsRefs)
                      db.classificationSuggestions,
                    if (classificationJobsRefs) db.classificationJobs,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (ocrResultsRefs)
                        await $_getPrefetchedData<
                          MediaItem,
                          $MediaItemsTable,
                          OcrResult
                        >(
                          currentTable: table,
                          referencedTable: $$MediaItemsTableReferences
                              ._ocrResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).ocrResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (processingJobsRefs)
                        await $_getPrefetchedData<
                          MediaItem,
                          $MediaItemsTable,
                          ProcessingJob
                        >(
                          currentTable: table,
                          referencedTable: $$MediaItemsTableReferences
                              ._processingJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).processingJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mediaCategoriesRefs)
                        await $_getPrefetchedData<
                          MediaItem,
                          $MediaItemsTable,
                          MediaCategory
                        >(
                          currentTable: table,
                          referencedTable: $$MediaItemsTableReferences
                              ._mediaCategoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).mediaCategoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mediaTagsRefs)
                        await $_getPrefetchedData<
                          MediaItem,
                          $MediaItemsTable,
                          MediaTag
                        >(
                          currentTable: table,
                          referencedTable: $$MediaItemsTableReferences
                              ._mediaTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).mediaTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (classificationSuggestionsRefs)
                        await $_getPrefetchedData<
                          MediaItem,
                          $MediaItemsTable,
                          ClassificationSuggestion
                        >(
                          currentTable: table,
                          referencedTable: $$MediaItemsTableReferences
                              ._classificationSuggestionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).classificationSuggestionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (classificationJobsRefs)
                        await $_getPrefetchedData<
                          MediaItem,
                          $MediaItemsTable,
                          ClassificationJob
                        >(
                          currentTable: table,
                          referencedTable: $$MediaItemsTableReferences
                              ._classificationJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MediaItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).classificationJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mediaItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $MediaItemsTable,
      MediaItem,
      $$MediaItemsTableFilterComposer,
      $$MediaItemsTableOrderingComposer,
      $$MediaItemsTableAnnotationComposer,
      $$MediaItemsTableCreateCompanionBuilder,
      $$MediaItemsTableUpdateCompanionBuilder,
      (MediaItem, $$MediaItemsTableReferences),
      MediaItem,
      PrefetchHooks Function({
        bool ocrResultsRefs,
        bool processingJobsRefs,
        bool mediaCategoriesRefs,
        bool mediaTagsRefs,
        bool classificationSuggestionsRefs,
        bool classificationJobsRefs,
      })
    >;
typedef $$OcrResultsTableCreateCompanionBuilder =
    OcrResultsCompanion Function({
      Value<int> mediaItemId,
      required String fullText,
      Value<String> normalizedText,
      required String engine,
      required String engineVersion,
      required DateTime processedAt,
    });
typedef $$OcrResultsTableUpdateCompanionBuilder =
    OcrResultsCompanion Function({
      Value<int> mediaItemId,
      Value<String> fullText,
      Value<String> normalizedText,
      Value<String> engine,
      Value<String> engineVersion,
      Value<DateTime> processedAt,
    });

final class $$OcrResultsTableReferences
    extends BaseReferences<_$ContextoDatabase, $OcrResultsTable, OcrResult> {
  $$OcrResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaItemsTable _mediaItemIdTable(_$ContextoDatabase db) =>
      db.mediaItems.createAlias('ocr_results__media_item_id__media_items__id');

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OcrResultsTableFilterComposer
    extends Composer<_$ContextoDatabase, $OcrResultsTable> {
  $$OcrResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fullText => $composableBuilder(
    column: $table.fullText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedText => $composableBuilder(
    column: $table.normalizedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OcrResultsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $OcrResultsTable> {
  $$OcrResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fullText => $composableBuilder(
    column: $table.fullText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedText => $composableBuilder(
    column: $table.normalizedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OcrResultsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $OcrResultsTable> {
  $$OcrResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fullText =>
      $composableBuilder(column: $table.fullText, builder: (column) => column);

  GeneratedColumn<String> get normalizedText => $composableBuilder(
    column: $table.normalizedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OcrResultsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $OcrResultsTable,
          OcrResult,
          $$OcrResultsTableFilterComposer,
          $$OcrResultsTableOrderingComposer,
          $$OcrResultsTableAnnotationComposer,
          $$OcrResultsTableCreateCompanionBuilder,
          $$OcrResultsTableUpdateCompanionBuilder,
          (OcrResult, $$OcrResultsTableReferences),
          OcrResult,
          PrefetchHooks Function({bool mediaItemId})
        > {
  $$OcrResultsTableTableManager(_$ContextoDatabase db, $OcrResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OcrResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OcrResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OcrResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                Value<String> fullText = const Value.absent(),
                Value<String> normalizedText = const Value.absent(),
                Value<String> engine = const Value.absent(),
                Value<String> engineVersion = const Value.absent(),
                Value<DateTime> processedAt = const Value.absent(),
              }) => OcrResultsCompanion(
                mediaItemId: mediaItemId,
                fullText: fullText,
                normalizedText: normalizedText,
                engine: engine,
                engineVersion: engineVersion,
                processedAt: processedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                required String fullText,
                Value<String> normalizedText = const Value.absent(),
                required String engine,
                required String engineVersion,
                required DateTime processedAt,
              }) => OcrResultsCompanion.insert(
                mediaItemId: mediaItemId,
                fullText: fullText,
                normalizedText: normalizedText,
                engine: engine,
                engineVersion: engineVersion,
                processedAt: processedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OcrResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaItemId,
                                referencedTable: $$OcrResultsTableReferences
                                    ._mediaItemIdTable(db),
                                referencedColumn: $$OcrResultsTableReferences
                                    ._mediaItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OcrResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $OcrResultsTable,
      OcrResult,
      $$OcrResultsTableFilterComposer,
      $$OcrResultsTableOrderingComposer,
      $$OcrResultsTableAnnotationComposer,
      $$OcrResultsTableCreateCompanionBuilder,
      $$OcrResultsTableUpdateCompanionBuilder,
      (OcrResult, $$OcrResultsTableReferences),
      OcrResult,
      PrefetchHooks Function({bool mediaItemId})
    >;
typedef $$ProcessingJobsTableCreateCompanionBuilder =
    ProcessingJobsCompanion Function({
      Value<int> id,
      required int mediaItemId,
      required String jobType,
      required String status,
      Value<int> attempts,
      Value<String?> errorCode,
      required DateTime createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
    });
typedef $$ProcessingJobsTableUpdateCompanionBuilder =
    ProcessingJobsCompanion Function({
      Value<int> id,
      Value<int> mediaItemId,
      Value<String> jobType,
      Value<String> status,
      Value<int> attempts,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
    });

final class $$ProcessingJobsTableReferences
    extends
        BaseReferences<
          _$ContextoDatabase,
          $ProcessingJobsTable,
          ProcessingJob
        > {
  $$ProcessingJobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MediaItemsTable _mediaItemIdTable(_$ContextoDatabase db) => db
      .mediaItems
      .createAlias('processing_jobs__media_item_id__media_items__id');

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProcessingJobsTableFilterComposer
    extends Composer<_$ContextoDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProcessingJobsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProcessingJobsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $ProcessingJobsTable> {
  $$ProcessingJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jobType =>
      $composableBuilder(column: $table.jobType, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProcessingJobsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $ProcessingJobsTable,
          ProcessingJob,
          $$ProcessingJobsTableFilterComposer,
          $$ProcessingJobsTableOrderingComposer,
          $$ProcessingJobsTableAnnotationComposer,
          $$ProcessingJobsTableCreateCompanionBuilder,
          $$ProcessingJobsTableUpdateCompanionBuilder,
          (ProcessingJob, $$ProcessingJobsTableReferences),
          ProcessingJob,
          PrefetchHooks Function({bool mediaItemId})
        > {
  $$ProcessingJobsTableTableManager(
    _$ContextoDatabase db,
    $ProcessingJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProcessingJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProcessingJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProcessingJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mediaItemId = const Value.absent(),
                Value<String> jobType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
              }) => ProcessingJobsCompanion(
                id: id,
                mediaItemId: mediaItemId,
                jobType: jobType,
                status: status,
                attempts: attempts,
                errorCode: errorCode,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mediaItemId,
                required String jobType,
                required String status,
                Value<int> attempts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
              }) => ProcessingJobsCompanion.insert(
                id: id,
                mediaItemId: mediaItemId,
                jobType: jobType,
                status: status,
                attempts: attempts,
                errorCode: errorCode,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProcessingJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaItemId,
                                referencedTable: $$ProcessingJobsTableReferences
                                    ._mediaItemIdTable(db),
                                referencedColumn:
                                    $$ProcessingJobsTableReferences
                                        ._mediaItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProcessingJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $ProcessingJobsTable,
      ProcessingJob,
      $$ProcessingJobsTableFilterComposer,
      $$ProcessingJobsTableOrderingComposer,
      $$ProcessingJobsTableAnnotationComposer,
      $$ProcessingJobsTableCreateCompanionBuilder,
      $$ProcessingJobsTableUpdateCompanionBuilder,
      (ProcessingJob, $$ProcessingJobsTableReferences),
      ProcessingJob,
      PrefetchHooks Function({bool mediaItemId})
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required String normalizedName,
      Value<int?> parentId,
      required DateTime createdAt,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<int?> parentId,
      Value<DateTime> createdAt,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$ContextoDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _parentIdTable(_$ContextoDatabase db) =>
      db.categories.createAlias('categories__parent_id__categories__id');

  $$CategoriesTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<int>('parent_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MediaCategoriesTable, List<MediaCategory>>
  _mediaCategoriesRefsTable(_$ContextoDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mediaCategories,
        aliasName: 'categories__id__media_categories__category_id',
      );

  $$MediaCategoriesTableProcessedTableManager get mediaCategoriesRefs {
    final manager = $$MediaCategoriesTableTableManager(
      $_db,
      $_db.mediaCategories,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mediaCategoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$ContextoDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get parentId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mediaCategoriesRefs(
    Expression<bool> Function($$MediaCategoriesTableFilterComposer f) f,
  ) {
    final $$MediaCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaCategories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.mediaCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$ContextoDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get parentId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get parentId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mediaCategoriesRefs<T extends Object>(
    Expression<T> Function($$MediaCategoriesTableAnnotationComposer a) f,
  ) {
    final $$MediaCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaCategories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool parentId, bool mediaCategoriesRefs})
        > {
  $$CategoriesTableTableManager(_$ContextoDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                parentId: parentId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String normalizedName,
                Value<int?> parentId = const Value.absent(),
                required DateTime createdAt,
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                parentId: parentId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({parentId = false, mediaCategoriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mediaCategoriesRefs) db.mediaCategories,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentId,
                                    referencedTable: $$CategoriesTableReferences
                                        ._parentIdTable(db),
                                    referencedColumn:
                                        $$CategoriesTableReferences
                                            ._parentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mediaCategoriesRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          MediaCategory
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._mediaCategoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).mediaCategoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool parentId, bool mediaCategoriesRefs})
    >;
typedef $$MediaCategoriesTableCreateCompanionBuilder =
    MediaCategoriesCompanion Function({
      required int mediaItemId,
      required int categoryId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MediaCategoriesTableUpdateCompanionBuilder =
    MediaCategoriesCompanion Function({
      Value<int> mediaItemId,
      Value<int> categoryId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$MediaCategoriesTableReferences
    extends
        BaseReferences<
          _$ContextoDatabase,
          $MediaCategoriesTable,
          MediaCategory
        > {
  $$MediaCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MediaItemsTable _mediaItemIdTable(_$ContextoDatabase db) => db
      .mediaItems
      .createAlias('media_categories__media_item_id__media_items__id');

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$ContextoDatabase db) => db
      .categories
      .createAlias('media_categories__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaCategoriesTableFilterComposer
    extends Composer<_$ContextoDatabase, $MediaCategoriesTable> {
  $$MediaCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaCategoriesTableOrderingComposer
    extends Composer<_$ContextoDatabase, $MediaCategoriesTable> {
  $$MediaCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaCategoriesTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $MediaCategoriesTable> {
  $$MediaCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaCategoriesTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $MediaCategoriesTable,
          MediaCategory,
          $$MediaCategoriesTableFilterComposer,
          $$MediaCategoriesTableOrderingComposer,
          $$MediaCategoriesTableAnnotationComposer,
          $$MediaCategoriesTableCreateCompanionBuilder,
          $$MediaCategoriesTableUpdateCompanionBuilder,
          (MediaCategory, $$MediaCategoriesTableReferences),
          MediaCategory,
          PrefetchHooks Function({bool mediaItemId, bool categoryId})
        > {
  $$MediaCategoriesTableTableManager(
    _$ContextoDatabase db,
    $MediaCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCategoriesCompanion(
                mediaItemId: mediaItemId,
                categoryId: categoryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int mediaItemId,
                required int categoryId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaCategoriesCompanion.insert(
                mediaItemId: mediaItemId,
                categoryId: categoryId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false, categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaItemId,
                                referencedTable:
                                    $$MediaCategoriesTableReferences
                                        ._mediaItemIdTable(db),
                                referencedColumn:
                                    $$MediaCategoriesTableReferences
                                        ._mediaItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable:
                                    $$MediaCategoriesTableReferences
                                        ._categoryIdTable(db),
                                referencedColumn:
                                    $$MediaCategoriesTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MediaCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $MediaCategoriesTable,
      MediaCategory,
      $$MediaCategoriesTableFilterComposer,
      $$MediaCategoriesTableOrderingComposer,
      $$MediaCategoriesTableAnnotationComposer,
      $$MediaCategoriesTableCreateCompanionBuilder,
      $$MediaCategoriesTableUpdateCompanionBuilder,
      (MediaCategory, $$MediaCategoriesTableReferences),
      MediaCategory,
      PrefetchHooks Function({bool mediaItemId, bool categoryId})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      required String name,
      required String normalizedName,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$ContextoDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MediaTagsTable, List<MediaTag>>
  _mediaTagsRefsTable(_$ContextoDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaTags,
    aliasName: 'tags__id__media_tags__tag_id',
  );

  $$MediaTagsTableProcessedTableManager get mediaTagsRefs {
    final manager = $$MediaTagsTableTableManager(
      $_db,
      $_db.mediaTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer
    extends Composer<_$ContextoDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mediaTagsRefs(
    Expression<bool> Function($$MediaTagsTableFilterComposer f) f,
  ) {
    final $$MediaTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaTagsTableFilterComposer(
            $db: $db,
            $table: $db.mediaTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> mediaTagsRefs<T extends Object>(
    Expression<T> Function($$MediaTagsTableAnnotationComposer a) f,
  ) {
    final $$MediaTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool mediaTagsRefs})
        > {
  $$TagsTableTableManager(_$ContextoDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String normalizedName,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({mediaTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mediaTagsRefs) db.mediaTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, MediaTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._mediaTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).mediaTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool mediaTagsRefs})
    >;
typedef $$MediaTagsTableCreateCompanionBuilder =
    MediaTagsCompanion Function({
      required int mediaItemId,
      required int tagId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MediaTagsTableUpdateCompanionBuilder =
    MediaTagsCompanion Function({
      Value<int> mediaItemId,
      Value<int> tagId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$MediaTagsTableReferences
    extends BaseReferences<_$ContextoDatabase, $MediaTagsTable, MediaTag> {
  $$MediaTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaItemsTable _mediaItemIdTable(_$ContextoDatabase db) =>
      db.mediaItems.createAlias('media_tags__media_item_id__media_items__id');

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$ContextoDatabase db) =>
      db.tags.createAlias('media_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaTagsTableFilterComposer
    extends Composer<_$ContextoDatabase, $MediaTagsTable> {
  $$MediaTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaTagsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $MediaTagsTable> {
  $$MediaTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaTagsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $MediaTagsTable> {
  $$MediaTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaTagsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $MediaTagsTable,
          MediaTag,
          $$MediaTagsTableFilterComposer,
          $$MediaTagsTableOrderingComposer,
          $$MediaTagsTableAnnotationComposer,
          $$MediaTagsTableCreateCompanionBuilder,
          $$MediaTagsTableUpdateCompanionBuilder,
          (MediaTag, $$MediaTagsTableReferences),
          MediaTag,
          PrefetchHooks Function({bool mediaItemId, bool tagId})
        > {
  $$MediaTagsTableTableManager(_$ContextoDatabase db, $MediaTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaTagsCompanion(
                mediaItemId: mediaItemId,
                tagId: tagId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int mediaItemId,
                required int tagId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaTagsCompanion.insert(
                mediaItemId: mediaItemId,
                tagId: tagId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaItemId,
                                referencedTable: $$MediaTagsTableReferences
                                    ._mediaItemIdTable(db),
                                referencedColumn: $$MediaTagsTableReferences
                                    ._mediaItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$MediaTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$MediaTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MediaTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $MediaTagsTable,
      MediaTag,
      $$MediaTagsTableFilterComposer,
      $$MediaTagsTableOrderingComposer,
      $$MediaTagsTableAnnotationComposer,
      $$MediaTagsTableCreateCompanionBuilder,
      $$MediaTagsTableUpdateCompanionBuilder,
      (MediaTag, $$MediaTagsTableReferences),
      MediaTag,
      PrefetchHooks Function({bool mediaItemId, bool tagId})
    >;
typedef $$AutomaticImportSettingsTableCreateCompanionBuilder =
    AutomaticImportSettingsCompanion Function({
      Value<int> id,
      Value<bool> enabled,
      Value<int?> lastMediaId,
      Value<DateTime?> enabledAt,
      Value<DateTime?> lastScanAt,
      required DateTime updatedAt,
    });
typedef $$AutomaticImportSettingsTableUpdateCompanionBuilder =
    AutomaticImportSettingsCompanion Function({
      Value<int> id,
      Value<bool> enabled,
      Value<int?> lastMediaId,
      Value<DateTime?> enabledAt,
      Value<DateTime?> lastScanAt,
      Value<DateTime> updatedAt,
    });

class $$AutomaticImportSettingsTableFilterComposer
    extends Composer<_$ContextoDatabase, $AutomaticImportSettingsTable> {
  $$AutomaticImportSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMediaId => $composableBuilder(
    column: $table.lastMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enabledAt => $composableBuilder(
    column: $table.enabledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AutomaticImportSettingsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $AutomaticImportSettingsTable> {
  $$AutomaticImportSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMediaId => $composableBuilder(
    column: $table.lastMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enabledAt => $composableBuilder(
    column: $table.enabledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AutomaticImportSettingsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $AutomaticImportSettingsTable> {
  $$AutomaticImportSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get lastMediaId => $composableBuilder(
    column: $table.lastMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get enabledAt =>
      $composableBuilder(column: $table.enabledAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AutomaticImportSettingsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $AutomaticImportSettingsTable,
          AutomaticImportSetting,
          $$AutomaticImportSettingsTableFilterComposer,
          $$AutomaticImportSettingsTableOrderingComposer,
          $$AutomaticImportSettingsTableAnnotationComposer,
          $$AutomaticImportSettingsTableCreateCompanionBuilder,
          $$AutomaticImportSettingsTableUpdateCompanionBuilder,
          (
            AutomaticImportSetting,
            BaseReferences<
              _$ContextoDatabase,
              $AutomaticImportSettingsTable,
              AutomaticImportSetting
            >,
          ),
          AutomaticImportSetting,
          PrefetchHooks Function()
        > {
  $$AutomaticImportSettingsTableTableManager(
    _$ContextoDatabase db,
    $AutomaticImportSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AutomaticImportSettingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AutomaticImportSettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AutomaticImportSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> lastMediaId = const Value.absent(),
                Value<DateTime?> enabledAt = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AutomaticImportSettingsCompanion(
                id: id,
                enabled: enabled,
                lastMediaId: lastMediaId,
                enabledAt: enabledAt,
                lastScanAt: lastScanAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> lastMediaId = const Value.absent(),
                Value<DateTime?> enabledAt = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
                required DateTime updatedAt,
              }) => AutomaticImportSettingsCompanion.insert(
                id: id,
                enabled: enabled,
                lastMediaId: lastMediaId,
                enabledAt: enabledAt,
                lastScanAt: lastScanAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AutomaticImportSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $AutomaticImportSettingsTable,
      AutomaticImportSetting,
      $$AutomaticImportSettingsTableFilterComposer,
      $$AutomaticImportSettingsTableOrderingComposer,
      $$AutomaticImportSettingsTableAnnotationComposer,
      $$AutomaticImportSettingsTableCreateCompanionBuilder,
      $$AutomaticImportSettingsTableUpdateCompanionBuilder,
      (
        AutomaticImportSetting,
        BaseReferences<
          _$ContextoDatabase,
          $AutomaticImportSettingsTable,
          AutomaticImportSetting
        >,
      ),
      AutomaticImportSetting,
      PrefetchHooks Function()
    >;
typedef $$ClassificationSuggestionsTableCreateCompanionBuilder =
    ClassificationSuggestionsCompanion Function({
      Value<int> mediaItemId,
      Value<String?> suggestedCategoryName,
      required double confidence,
      required bool hasSuggestion,
      required String suggestedTagsJson,
      required String evidenceJson,
      required String status,
      Value<String?> reviewReason,
      required int engineVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> resolvedAt,
    });
typedef $$ClassificationSuggestionsTableUpdateCompanionBuilder =
    ClassificationSuggestionsCompanion Function({
      Value<int> mediaItemId,
      Value<String?> suggestedCategoryName,
      Value<double> confidence,
      Value<bool> hasSuggestion,
      Value<String> suggestedTagsJson,
      Value<String> evidenceJson,
      Value<String> status,
      Value<String?> reviewReason,
      Value<int> engineVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> resolvedAt,
    });

final class $$ClassificationSuggestionsTableReferences
    extends
        BaseReferences<
          _$ContextoDatabase,
          $ClassificationSuggestionsTable,
          ClassificationSuggestion
        > {
  $$ClassificationSuggestionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MediaItemsTable _mediaItemIdTable(_$ContextoDatabase db) =>
      db.mediaItems.createAlias(
        'classification_suggestions__media_item_id__media_items__id',
      );

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClassificationSuggestionsTableFilterComposer
    extends Composer<_$ContextoDatabase, $ClassificationSuggestionsTable> {
  $$ClassificationSuggestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get suggestedCategoryName => $composableBuilder(
    column: $table.suggestedCategoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSuggestion => $composableBuilder(
    column: $table.hasSuggestion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedTagsJson => $composableBuilder(
    column: $table.suggestedTagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewReason => $composableBuilder(
    column: $table.reviewReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassificationSuggestionsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $ClassificationSuggestionsTable> {
  $$ClassificationSuggestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get suggestedCategoryName => $composableBuilder(
    column: $table.suggestedCategoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSuggestion => $composableBuilder(
    column: $table.hasSuggestion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedTagsJson => $composableBuilder(
    column: $table.suggestedTagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewReason => $composableBuilder(
    column: $table.reviewReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassificationSuggestionsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $ClassificationSuggestionsTable> {
  $$ClassificationSuggestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get suggestedCategoryName => $composableBuilder(
    column: $table.suggestedCategoryName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasSuggestion => $composableBuilder(
    column: $table.hasSuggestion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedTagsJson => $composableBuilder(
    column: $table.suggestedTagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reviewReason => $composableBuilder(
    column: $table.reviewReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassificationSuggestionsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $ClassificationSuggestionsTable,
          ClassificationSuggestion,
          $$ClassificationSuggestionsTableFilterComposer,
          $$ClassificationSuggestionsTableOrderingComposer,
          $$ClassificationSuggestionsTableAnnotationComposer,
          $$ClassificationSuggestionsTableCreateCompanionBuilder,
          $$ClassificationSuggestionsTableUpdateCompanionBuilder,
          (
            ClassificationSuggestion,
            $$ClassificationSuggestionsTableReferences,
          ),
          ClassificationSuggestion,
          PrefetchHooks Function({bool mediaItemId})
        > {
  $$ClassificationSuggestionsTableTableManager(
    _$ContextoDatabase db,
    $ClassificationSuggestionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationSuggestionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ClassificationSuggestionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClassificationSuggestionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                Value<String?> suggestedCategoryName = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<bool> hasSuggestion = const Value.absent(),
                Value<String> suggestedTagsJson = const Value.absent(),
                Value<String> evidenceJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reviewReason = const Value.absent(),
                Value<int> engineVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => ClassificationSuggestionsCompanion(
                mediaItemId: mediaItemId,
                suggestedCategoryName: suggestedCategoryName,
                confidence: confidence,
                hasSuggestion: hasSuggestion,
                suggestedTagsJson: suggestedTagsJson,
                evidenceJson: evidenceJson,
                status: status,
                reviewReason: reviewReason,
                engineVersion: engineVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                Value<String?> suggestedCategoryName = const Value.absent(),
                required double confidence,
                required bool hasSuggestion,
                required String suggestedTagsJson,
                required String evidenceJson,
                required String status,
                Value<String?> reviewReason = const Value.absent(),
                required int engineVersion,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => ClassificationSuggestionsCompanion.insert(
                mediaItemId: mediaItemId,
                suggestedCategoryName: suggestedCategoryName,
                confidence: confidence,
                hasSuggestion: hasSuggestion,
                suggestedTagsJson: suggestedTagsJson,
                evidenceJson: evidenceJson,
                status: status,
                reviewReason: reviewReason,
                engineVersion: engineVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ClassificationSuggestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaItemId,
                                referencedTable:
                                    $$ClassificationSuggestionsTableReferences
                                        ._mediaItemIdTable(db),
                                referencedColumn:
                                    $$ClassificationSuggestionsTableReferences
                                        ._mediaItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClassificationSuggestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $ClassificationSuggestionsTable,
      ClassificationSuggestion,
      $$ClassificationSuggestionsTableFilterComposer,
      $$ClassificationSuggestionsTableOrderingComposer,
      $$ClassificationSuggestionsTableAnnotationComposer,
      $$ClassificationSuggestionsTableCreateCompanionBuilder,
      $$ClassificationSuggestionsTableUpdateCompanionBuilder,
      (ClassificationSuggestion, $$ClassificationSuggestionsTableReferences),
      ClassificationSuggestion,
      PrefetchHooks Function({bool mediaItemId})
    >;
typedef $$ClassificationJobsTableCreateCompanionBuilder =
    ClassificationJobsCompanion Function({
      Value<int> mediaItemId,
      required String state,
      Value<int> attempts,
      required DateTime availableAt,
      required int engineVersion,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> processingStartedAt,
      Value<String?> lastErrorCode,
    });
typedef $$ClassificationJobsTableUpdateCompanionBuilder =
    ClassificationJobsCompanion Function({
      Value<int> mediaItemId,
      Value<String> state,
      Value<int> attempts,
      Value<DateTime> availableAt,
      Value<int> engineVersion,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> processingStartedAt,
      Value<String?> lastErrorCode,
    });

final class $$ClassificationJobsTableReferences
    extends
        BaseReferences<
          _$ContextoDatabase,
          $ClassificationJobsTable,
          ClassificationJob
        > {
  $$ClassificationJobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MediaItemsTable _mediaItemIdTable(_$ContextoDatabase db) => db
      .mediaItems
      .createAlias('classification_jobs__media_item_id__media_items__id');

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClassificationJobsTableFilterComposer
    extends Composer<_$ContextoDatabase, $ClassificationJobsTable> {
  $$ClassificationJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processingStartedAt => $composableBuilder(
    column: $table.processingStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassificationJobsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $ClassificationJobsTable> {
  $$ClassificationJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processingStartedAt => $composableBuilder(
    column: $table.processingStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassificationJobsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $ClassificationJobsTable> {
  $$ClassificationJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get engineVersion => $composableBuilder(
    column: $table.engineVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get processingStartedAt => $composableBuilder(
    column: $table.processingStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mediaItemId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClassificationJobsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $ClassificationJobsTable,
          ClassificationJob,
          $$ClassificationJobsTableFilterComposer,
          $$ClassificationJobsTableOrderingComposer,
          $$ClassificationJobsTableAnnotationComposer,
          $$ClassificationJobsTableCreateCompanionBuilder,
          $$ClassificationJobsTableUpdateCompanionBuilder,
          (ClassificationJob, $$ClassificationJobsTableReferences),
          ClassificationJob,
          PrefetchHooks Function({bool mediaItemId})
        > {
  $$ClassificationJobsTableTableManager(
    _$ContextoDatabase db,
    $ClassificationJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassificationJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClassificationJobsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> availableAt = const Value.absent(),
                Value<int> engineVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> processingStartedAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
              }) => ClassificationJobsCompanion(
                mediaItemId: mediaItemId,
                state: state,
                attempts: attempts,
                availableAt: availableAt,
                engineVersion: engineVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                processingStartedAt: processingStartedAt,
                lastErrorCode: lastErrorCode,
              ),
          createCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                required String state,
                Value<int> attempts = const Value.absent(),
                required DateTime availableAt,
                required int engineVersion,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> processingStartedAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
              }) => ClassificationJobsCompanion.insert(
                mediaItemId: mediaItemId,
                state: state,
                attempts: attempts,
                availableAt: availableAt,
                engineVersion: engineVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                processingStartedAt: processingStartedAt,
                lastErrorCode: lastErrorCode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ClassificationJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mediaItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mediaItemId,
                                referencedTable:
                                    $$ClassificationJobsTableReferences
                                        ._mediaItemIdTable(db),
                                referencedColumn:
                                    $$ClassificationJobsTableReferences
                                        ._mediaItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClassificationJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $ClassificationJobsTable,
      ClassificationJob,
      $$ClassificationJobsTableFilterComposer,
      $$ClassificationJobsTableOrderingComposer,
      $$ClassificationJobsTableAnnotationComposer,
      $$ClassificationJobsTableCreateCompanionBuilder,
      $$ClassificationJobsTableUpdateCompanionBuilder,
      (ClassificationJob, $$ClassificationJobsTableReferences),
      ClassificationJob,
      PrefetchHooks Function({bool mediaItemId})
    >;
typedef $$ExistingScreenshotCandidatesTableCreateCompanionBuilder =
    ExistingScreenshotCandidatesCompanion Function({
      required String sourceKey,
      required int mediaStoreId,
      required String volumeName,
      required String contentUri,
      Value<String?> mimeType,
      Value<DateTime?> capturedAt,
      Value<DateTime?> dateModified,
      Value<int?> sizeBytes,
      Value<int?> width,
      Value<int?> height,
      required DateTime discoveredAt,
      required DateTime lastSeenAt,
      required String availabilityState,
      Value<int> rowid,
    });
typedef $$ExistingScreenshotCandidatesTableUpdateCompanionBuilder =
    ExistingScreenshotCandidatesCompanion Function({
      Value<String> sourceKey,
      Value<int> mediaStoreId,
      Value<String> volumeName,
      Value<String> contentUri,
      Value<String?> mimeType,
      Value<DateTime?> capturedAt,
      Value<DateTime?> dateModified,
      Value<int?> sizeBytes,
      Value<int?> width,
      Value<int?> height,
      Value<DateTime> discoveredAt,
      Value<DateTime> lastSeenAt,
      Value<String> availabilityState,
      Value<int> rowid,
    });

final class $$ExistingScreenshotCandidatesTableReferences
    extends
        BaseReferences<
          _$ContextoDatabase,
          $ExistingScreenshotCandidatesTable,
          ExistingScreenshotCandidate
        > {
  $$ExistingScreenshotCandidatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $HistoricalMediaImportJobsTable,
    List<HistoricalMediaImportJob>
  >
  _historicalMediaImportJobsRefsTable(
    _$ContextoDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.historicalMediaImportJobs,
    aliasName:
        'existing_screenshot_candidates__source_key__historical_media_import_jobs__source_key',
  );

  $$HistoricalMediaImportJobsTableProcessedTableManager
  get historicalMediaImportJobsRefs {
    final manager =
        $$HistoricalMediaImportJobsTableTableManager(
          $_db,
          $_db.historicalMediaImportJobs,
        ).filter(
          (f) => f.sourceKey.sourceKey.sqlEquals(
            $_itemColumn<String>('source_key')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _historicalMediaImportJobsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExistingScreenshotCandidatesTableFilterComposer
    extends Composer<_$ContextoDatabase, $ExistingScreenshotCandidatesTable> {
  $$ExistingScreenshotCandidatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateModified => $composableBuilder(
    column: $table.dateModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availabilityState => $composableBuilder(
    column: $table.availabilityState,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> historicalMediaImportJobsRefs(
    Expression<bool> Function($$HistoricalMediaImportJobsTableFilterComposer f)
    f,
  ) {
    final $$HistoricalMediaImportJobsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceKey,
          referencedTable: $db.historicalMediaImportJobs,
          getReferencedColumn: (t) => t.sourceKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HistoricalMediaImportJobsTableFilterComposer(
                $db: $db,
                $table: $db.historicalMediaImportJobs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExistingScreenshotCandidatesTableOrderingComposer
    extends Composer<_$ContextoDatabase, $ExistingScreenshotCandidatesTable> {
  $$ExistingScreenshotCandidatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateModified => $composableBuilder(
    column: $table.dateModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availabilityState => $composableBuilder(
    column: $table.availabilityState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExistingScreenshotCandidatesTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $ExistingScreenshotCandidatesTable> {
  $$ExistingScreenshotCandidatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get mediaStoreId => $composableBuilder(
    column: $table.mediaStoreId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get volumeName => $composableBuilder(
    column: $table.volumeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateModified => $composableBuilder(
    column: $table.dateModified,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availabilityState => $composableBuilder(
    column: $table.availabilityState,
    builder: (column) => column,
  );

  Expression<T> historicalMediaImportJobsRefs<T extends Object>(
    Expression<T> Function($$HistoricalMediaImportJobsTableAnnotationComposer a)
    f,
  ) {
    final $$HistoricalMediaImportJobsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceKey,
          referencedTable: $db.historicalMediaImportJobs,
          getReferencedColumn: (t) => t.sourceKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HistoricalMediaImportJobsTableAnnotationComposer(
                $db: $db,
                $table: $db.historicalMediaImportJobs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExistingScreenshotCandidatesTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $ExistingScreenshotCandidatesTable,
          ExistingScreenshotCandidate,
          $$ExistingScreenshotCandidatesTableFilterComposer,
          $$ExistingScreenshotCandidatesTableOrderingComposer,
          $$ExistingScreenshotCandidatesTableAnnotationComposer,
          $$ExistingScreenshotCandidatesTableCreateCompanionBuilder,
          $$ExistingScreenshotCandidatesTableUpdateCompanionBuilder,
          (
            ExistingScreenshotCandidate,
            $$ExistingScreenshotCandidatesTableReferences,
          ),
          ExistingScreenshotCandidate,
          PrefetchHooks Function({bool historicalMediaImportJobsRefs})
        > {
  $$ExistingScreenshotCandidatesTableTableManager(
    _$ContextoDatabase db,
    $ExistingScreenshotCandidatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExistingScreenshotCandidatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExistingScreenshotCandidatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExistingScreenshotCandidatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceKey = const Value.absent(),
                Value<int> mediaStoreId = const Value.absent(),
                Value<String> volumeName = const Value.absent(),
                Value<String> contentUri = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<DateTime?> dateModified = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<DateTime> discoveredAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<String> availabilityState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExistingScreenshotCandidatesCompanion(
                sourceKey: sourceKey,
                mediaStoreId: mediaStoreId,
                volumeName: volumeName,
                contentUri: contentUri,
                mimeType: mimeType,
                capturedAt: capturedAt,
                dateModified: dateModified,
                sizeBytes: sizeBytes,
                width: width,
                height: height,
                discoveredAt: discoveredAt,
                lastSeenAt: lastSeenAt,
                availabilityState: availabilityState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceKey,
                required int mediaStoreId,
                required String volumeName,
                required String contentUri,
                Value<String?> mimeType = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<DateTime?> dateModified = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                required DateTime discoveredAt,
                required DateTime lastSeenAt,
                required String availabilityState,
                Value<int> rowid = const Value.absent(),
              }) => ExistingScreenshotCandidatesCompanion.insert(
                sourceKey: sourceKey,
                mediaStoreId: mediaStoreId,
                volumeName: volumeName,
                contentUri: contentUri,
                mimeType: mimeType,
                capturedAt: capturedAt,
                dateModified: dateModified,
                sizeBytes: sizeBytes,
                width: width,
                height: height,
                discoveredAt: discoveredAt,
                lastSeenAt: lastSeenAt,
                availabilityState: availabilityState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExistingScreenshotCandidatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({historicalMediaImportJobsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (historicalMediaImportJobsRefs) db.historicalMediaImportJobs,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (historicalMediaImportJobsRefs)
                    await $_getPrefetchedData<
                      ExistingScreenshotCandidate,
                      $ExistingScreenshotCandidatesTable,
                      HistoricalMediaImportJob
                    >(
                      currentTable: table,
                      referencedTable:
                          $$ExistingScreenshotCandidatesTableReferences
                              ._historicalMediaImportJobsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ExistingScreenshotCandidatesTableReferences(
                            db,
                            table,
                            p0,
                          ).historicalMediaImportJobsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.sourceKey == item.sourceKey,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ExistingScreenshotCandidatesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $ExistingScreenshotCandidatesTable,
      ExistingScreenshotCandidate,
      $$ExistingScreenshotCandidatesTableFilterComposer,
      $$ExistingScreenshotCandidatesTableOrderingComposer,
      $$ExistingScreenshotCandidatesTableAnnotationComposer,
      $$ExistingScreenshotCandidatesTableCreateCompanionBuilder,
      $$ExistingScreenshotCandidatesTableUpdateCompanionBuilder,
      (
        ExistingScreenshotCandidate,
        $$ExistingScreenshotCandidatesTableReferences,
      ),
      ExistingScreenshotCandidate,
      PrefetchHooks Function({bool historicalMediaImportJobsRefs})
    >;
typedef $$ExistingScreenshotInventoryStatesTableCreateCompanionBuilder =
    ExistingScreenshotInventoryStatesCompanion Function({
      Value<int> id,
      Value<DateTime?> lastCompletedScanAt,
      Value<bool> lastScanWasPartial,
    });
typedef $$ExistingScreenshotInventoryStatesTableUpdateCompanionBuilder =
    ExistingScreenshotInventoryStatesCompanion Function({
      Value<int> id,
      Value<DateTime?> lastCompletedScanAt,
      Value<bool> lastScanWasPartial,
    });

class $$ExistingScreenshotInventoryStatesTableFilterComposer
    extends
        Composer<_$ContextoDatabase, $ExistingScreenshotInventoryStatesTable> {
  $$ExistingScreenshotInventoryStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCompletedScanAt => $composableBuilder(
    column: $table.lastCompletedScanAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lastScanWasPartial => $composableBuilder(
    column: $table.lastScanWasPartial,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExistingScreenshotInventoryStatesTableOrderingComposer
    extends
        Composer<_$ContextoDatabase, $ExistingScreenshotInventoryStatesTable> {
  $$ExistingScreenshotInventoryStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCompletedScanAt => $composableBuilder(
    column: $table.lastCompletedScanAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lastScanWasPartial => $composableBuilder(
    column: $table.lastScanWasPartial,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExistingScreenshotInventoryStatesTableAnnotationComposer
    extends
        Composer<_$ContextoDatabase, $ExistingScreenshotInventoryStatesTable> {
  $$ExistingScreenshotInventoryStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCompletedScanAt => $composableBuilder(
    column: $table.lastCompletedScanAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lastScanWasPartial => $composableBuilder(
    column: $table.lastScanWasPartial,
    builder: (column) => column,
  );
}

class $$ExistingScreenshotInventoryStatesTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $ExistingScreenshotInventoryStatesTable,
          ExistingScreenshotInventoryState,
          $$ExistingScreenshotInventoryStatesTableFilterComposer,
          $$ExistingScreenshotInventoryStatesTableOrderingComposer,
          $$ExistingScreenshotInventoryStatesTableAnnotationComposer,
          $$ExistingScreenshotInventoryStatesTableCreateCompanionBuilder,
          $$ExistingScreenshotInventoryStatesTableUpdateCompanionBuilder,
          (
            ExistingScreenshotInventoryState,
            BaseReferences<
              _$ContextoDatabase,
              $ExistingScreenshotInventoryStatesTable,
              ExistingScreenshotInventoryState
            >,
          ),
          ExistingScreenshotInventoryState,
          PrefetchHooks Function()
        > {
  $$ExistingScreenshotInventoryStatesTableTableManager(
    _$ContextoDatabase db,
    $ExistingScreenshotInventoryStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExistingScreenshotInventoryStatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExistingScreenshotInventoryStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExistingScreenshotInventoryStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime?> lastCompletedScanAt = const Value.absent(),
                Value<bool> lastScanWasPartial = const Value.absent(),
              }) => ExistingScreenshotInventoryStatesCompanion(
                id: id,
                lastCompletedScanAt: lastCompletedScanAt,
                lastScanWasPartial: lastScanWasPartial,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime?> lastCompletedScanAt = const Value.absent(),
                Value<bool> lastScanWasPartial = const Value.absent(),
              }) => ExistingScreenshotInventoryStatesCompanion.insert(
                id: id,
                lastCompletedScanAt: lastCompletedScanAt,
                lastScanWasPartial: lastScanWasPartial,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExistingScreenshotInventoryStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $ExistingScreenshotInventoryStatesTable,
      ExistingScreenshotInventoryState,
      $$ExistingScreenshotInventoryStatesTableFilterComposer,
      $$ExistingScreenshotInventoryStatesTableOrderingComposer,
      $$ExistingScreenshotInventoryStatesTableAnnotationComposer,
      $$ExistingScreenshotInventoryStatesTableCreateCompanionBuilder,
      $$ExistingScreenshotInventoryStatesTableUpdateCompanionBuilder,
      (
        ExistingScreenshotInventoryState,
        BaseReferences<
          _$ContextoDatabase,
          $ExistingScreenshotInventoryStatesTable,
          ExistingScreenshotInventoryState
        >,
      ),
      ExistingScreenshotInventoryState,
      PrefetchHooks Function()
    >;
typedef $$HistoricalMediaImportJobsTableCreateCompanionBuilder =
    HistoricalMediaImportJobsCompanion Function({
      required String sourceKey,
      required String state,
      Value<int> attempts,
      required DateTime availableAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> processingStartedAt,
      Value<String?> lastErrorCode,
      Value<int> rowid,
    });
typedef $$HistoricalMediaImportJobsTableUpdateCompanionBuilder =
    HistoricalMediaImportJobsCompanion Function({
      Value<String> sourceKey,
      Value<String> state,
      Value<int> attempts,
      Value<DateTime> availableAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> processingStartedAt,
      Value<String?> lastErrorCode,
      Value<int> rowid,
    });

final class $$HistoricalMediaImportJobsTableReferences
    extends
        BaseReferences<
          _$ContextoDatabase,
          $HistoricalMediaImportJobsTable,
          HistoricalMediaImportJob
        > {
  $$HistoricalMediaImportJobsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ExistingScreenshotCandidatesTable _sourceKeyTable(
    _$ContextoDatabase db,
  ) => db.existingScreenshotCandidates.createAlias(
    'historical_media_import_jobs__source_key__existing_screenshot_candidates__source_key',
  );

  $$ExistingScreenshotCandidatesTableProcessedTableManager get sourceKey {
    final $_column = $_itemColumn<String>('source_key')!;

    final manager = $$ExistingScreenshotCandidatesTableTableManager(
      $_db,
      $_db.existingScreenshotCandidates,
    ).filter((f) => f.sourceKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HistoricalMediaImportJobsTableFilterComposer
    extends Composer<_$ContextoDatabase, $HistoricalMediaImportJobsTable> {
  $$HistoricalMediaImportJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get processingStartedAt => $composableBuilder(
    column: $table.processingStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$ExistingScreenshotCandidatesTableFilterComposer get sourceKey {
    final $$ExistingScreenshotCandidatesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceKey,
          referencedTable: $db.existingScreenshotCandidates,
          getReferencedColumn: (t) => t.sourceKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExistingScreenshotCandidatesTableFilterComposer(
                $db: $db,
                $table: $db.existingScreenshotCandidates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$HistoricalMediaImportJobsTableOrderingComposer
    extends Composer<_$ContextoDatabase, $HistoricalMediaImportJobsTable> {
  $$HistoricalMediaImportJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get processingStartedAt => $composableBuilder(
    column: $table.processingStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExistingScreenshotCandidatesTableOrderingComposer get sourceKey {
    final $$ExistingScreenshotCandidatesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceKey,
          referencedTable: $db.existingScreenshotCandidates,
          getReferencedColumn: (t) => t.sourceKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExistingScreenshotCandidatesTableOrderingComposer(
                $db: $db,
                $table: $db.existingScreenshotCandidates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$HistoricalMediaImportJobsTableAnnotationComposer
    extends Composer<_$ContextoDatabase, $HistoricalMediaImportJobsTable> {
  $$HistoricalMediaImportJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get processingStartedAt => $composableBuilder(
    column: $table.processingStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  $$ExistingScreenshotCandidatesTableAnnotationComposer get sourceKey {
    final $$ExistingScreenshotCandidatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceKey,
          referencedTable: $db.existingScreenshotCandidates,
          getReferencedColumn: (t) => t.sourceKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExistingScreenshotCandidatesTableAnnotationComposer(
                $db: $db,
                $table: $db.existingScreenshotCandidates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$HistoricalMediaImportJobsTableTableManager
    extends
        RootTableManager<
          _$ContextoDatabase,
          $HistoricalMediaImportJobsTable,
          HistoricalMediaImportJob,
          $$HistoricalMediaImportJobsTableFilterComposer,
          $$HistoricalMediaImportJobsTableOrderingComposer,
          $$HistoricalMediaImportJobsTableAnnotationComposer,
          $$HistoricalMediaImportJobsTableCreateCompanionBuilder,
          $$HistoricalMediaImportJobsTableUpdateCompanionBuilder,
          (
            HistoricalMediaImportJob,
            $$HistoricalMediaImportJobsTableReferences,
          ),
          HistoricalMediaImportJob,
          PrefetchHooks Function({bool sourceKey})
        > {
  $$HistoricalMediaImportJobsTableTableManager(
    _$ContextoDatabase db,
    $HistoricalMediaImportJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoricalMediaImportJobsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$HistoricalMediaImportJobsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HistoricalMediaImportJobsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceKey = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> availableAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> processingStartedAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoricalMediaImportJobsCompanion(
                sourceKey: sourceKey,
                state: state,
                attempts: attempts,
                availableAt: availableAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                processingStartedAt: processingStartedAt,
                lastErrorCode: lastErrorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceKey,
                required String state,
                Value<int> attempts = const Value.absent(),
                required DateTime availableAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> processingStartedAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoricalMediaImportJobsCompanion.insert(
                sourceKey: sourceKey,
                state: state,
                attempts: attempts,
                availableAt: availableAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                processingStartedAt: processingStartedAt,
                lastErrorCode: lastErrorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HistoricalMediaImportJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceKey) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceKey,
                                referencedTable:
                                    $$HistoricalMediaImportJobsTableReferences
                                        ._sourceKeyTable(db),
                                referencedColumn:
                                    $$HistoricalMediaImportJobsTableReferences
                                        ._sourceKeyTable(db)
                                        .sourceKey,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HistoricalMediaImportJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$ContextoDatabase,
      $HistoricalMediaImportJobsTable,
      HistoricalMediaImportJob,
      $$HistoricalMediaImportJobsTableFilterComposer,
      $$HistoricalMediaImportJobsTableOrderingComposer,
      $$HistoricalMediaImportJobsTableAnnotationComposer,
      $$HistoricalMediaImportJobsTableCreateCompanionBuilder,
      $$HistoricalMediaImportJobsTableUpdateCompanionBuilder,
      (HistoricalMediaImportJob, $$HistoricalMediaImportJobsTableReferences),
      HistoricalMediaImportJob,
      PrefetchHooks Function({bool sourceKey})
    >;

class $ContextoDatabaseManager {
  final _$ContextoDatabase _db;
  $ContextoDatabaseManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$OcrResultsTableTableManager get ocrResults =>
      $$OcrResultsTableTableManager(_db, _db.ocrResults);
  $$ProcessingJobsTableTableManager get processingJobs =>
      $$ProcessingJobsTableTableManager(_db, _db.processingJobs);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$MediaCategoriesTableTableManager get mediaCategories =>
      $$MediaCategoriesTableTableManager(_db, _db.mediaCategories);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$MediaTagsTableTableManager get mediaTags =>
      $$MediaTagsTableTableManager(_db, _db.mediaTags);
  $$AutomaticImportSettingsTableTableManager get automaticImportSettings =>
      $$AutomaticImportSettingsTableTableManager(
        _db,
        _db.automaticImportSettings,
      );
  $$ClassificationSuggestionsTableTableManager get classificationSuggestions =>
      $$ClassificationSuggestionsTableTableManager(
        _db,
        _db.classificationSuggestions,
      );
  $$ClassificationJobsTableTableManager get classificationJobs =>
      $$ClassificationJobsTableTableManager(_db, _db.classificationJobs);
  $$ExistingScreenshotCandidatesTableTableManager
  get existingScreenshotCandidates =>
      $$ExistingScreenshotCandidatesTableTableManager(
        _db,
        _db.existingScreenshotCandidates,
      );
  $$ExistingScreenshotInventoryStatesTableTableManager
  get existingScreenshotInventoryStates =>
      $$ExistingScreenshotInventoryStatesTableTableManager(
        _db,
        _db.existingScreenshotInventoryStates,
      );
  $$HistoricalMediaImportJobsTableTableManager get historicalMediaImportJobs =>
      $$HistoricalMediaImportJobsTableTableManager(
        _db,
        _db.historicalMediaImportJobs,
      );
}
