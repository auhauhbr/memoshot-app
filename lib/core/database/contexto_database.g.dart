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
  static const VerificationMeta _privatePathMeta = const VerificationMeta(
    'privatePath',
  );
  @override
  late final GeneratedColumn<String> privatePath = GeneratedColumn<String>(
    'private_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _internalNameMeta = const VerificationMeta(
    'internalName',
  );
  @override
  late final GeneratedColumn<String> internalName = GeneratedColumn<String>(
    'internal_name',
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
    privatePath,
    internalName,
    mimeType,
    mediaHash,
    importedAt,
    sourceMode,
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
    if (data.containsKey('private_path')) {
      context.handle(
        _privatePathMeta,
        privatePath.isAcceptableOrUnknown(
          data['private_path']!,
          _privatePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_privatePathMeta);
    }
    if (data.containsKey('internal_name')) {
      context.handle(
        _internalNameMeta,
        internalName.isAcceptableOrUnknown(
          data['internal_name']!,
          _internalNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_internalNameMeta);
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
    if (data.containsKey('source_mode')) {
      context.handle(
        _sourceModeMeta,
        sourceMode.isAcceptableOrUnknown(data['source_mode']!, _sourceModeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceModeMeta);
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
      privatePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}private_path'],
      )!,
      internalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}internal_name'],
      )!,
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
      sourceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_mode'],
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
  final String privatePath;
  final String internalName;
  final String? mimeType;
  final String? mediaHash;
  final DateTime importedAt;
  final String sourceMode;
  final String status;
  const MediaItem({
    required this.id,
    required this.privatePath,
    required this.internalName,
    this.mimeType,
    this.mediaHash,
    required this.importedAt,
    required this.sourceMode,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['private_path'] = Variable<String>(privatePath);
    map['internal_name'] = Variable<String>(internalName);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || mediaHash != null) {
      map['media_hash'] = Variable<String>(mediaHash);
    }
    map['imported_at'] = Variable<DateTime>(importedAt);
    map['source_mode'] = Variable<String>(sourceMode);
    map['status'] = Variable<String>(status);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      id: Value(id),
      privatePath: Value(privatePath),
      internalName: Value(internalName),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      mediaHash: mediaHash == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaHash),
      importedAt: Value(importedAt),
      sourceMode: Value(sourceMode),
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
      privatePath: serializer.fromJson<String>(json['privatePath']),
      internalName: serializer.fromJson<String>(json['internalName']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      mediaHash: serializer.fromJson<String?>(json['mediaHash']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      sourceMode: serializer.fromJson<String>(json['sourceMode']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'privatePath': serializer.toJson<String>(privatePath),
      'internalName': serializer.toJson<String>(internalName),
      'mimeType': serializer.toJson<String?>(mimeType),
      'mediaHash': serializer.toJson<String?>(mediaHash),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'sourceMode': serializer.toJson<String>(sourceMode),
      'status': serializer.toJson<String>(status),
    };
  }

  MediaItem copyWith({
    int? id,
    String? privatePath,
    String? internalName,
    Value<String?> mimeType = const Value.absent(),
    Value<String?> mediaHash = const Value.absent(),
    DateTime? importedAt,
    String? sourceMode,
    String? status,
  }) => MediaItem(
    id: id ?? this.id,
    privatePath: privatePath ?? this.privatePath,
    internalName: internalName ?? this.internalName,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    mediaHash: mediaHash.present ? mediaHash.value : this.mediaHash,
    importedAt: importedAt ?? this.importedAt,
    sourceMode: sourceMode ?? this.sourceMode,
    status: status ?? this.status,
  );
  MediaItem copyWithCompanion(MediaItemsCompanion data) {
    return MediaItem(
      id: data.id.present ? data.id.value : this.id,
      privatePath: data.privatePath.present
          ? data.privatePath.value
          : this.privatePath,
      internalName: data.internalName.present
          ? data.internalName.value
          : this.internalName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      mediaHash: data.mediaHash.present ? data.mediaHash.value : this.mediaHash,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      sourceMode: data.sourceMode.present
          ? data.sourceMode.value
          : this.sourceMode,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItem(')
          ..write('id: $id, ')
          ..write('privatePath: $privatePath, ')
          ..write('internalName: $internalName, ')
          ..write('mimeType: $mimeType, ')
          ..write('mediaHash: $mediaHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('sourceMode: $sourceMode, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    privatePath,
    internalName,
    mimeType,
    mediaHash,
    importedAt,
    sourceMode,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItem &&
          other.id == this.id &&
          other.privatePath == this.privatePath &&
          other.internalName == this.internalName &&
          other.mimeType == this.mimeType &&
          other.mediaHash == this.mediaHash &&
          other.importedAt == this.importedAt &&
          other.sourceMode == this.sourceMode &&
          other.status == this.status);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItem> {
  final Value<int> id;
  final Value<String> privatePath;
  final Value<String> internalName;
  final Value<String?> mimeType;
  final Value<String?> mediaHash;
  final Value<DateTime> importedAt;
  final Value<String> sourceMode;
  final Value<String> status;
  const MediaItemsCompanion({
    this.id = const Value.absent(),
    this.privatePath = const Value.absent(),
    this.internalName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.mediaHash = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.sourceMode = const Value.absent(),
    this.status = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    this.id = const Value.absent(),
    required String privatePath,
    required String internalName,
    this.mimeType = const Value.absent(),
    this.mediaHash = const Value.absent(),
    required DateTime importedAt,
    required String sourceMode,
    required String status,
  }) : privatePath = Value(privatePath),
       internalName = Value(internalName),
       importedAt = Value(importedAt),
       sourceMode = Value(sourceMode),
       status = Value(status);
  static Insertable<MediaItem> custom({
    Expression<int>? id,
    Expression<String>? privatePath,
    Expression<String>? internalName,
    Expression<String>? mimeType,
    Expression<String>? mediaHash,
    Expression<DateTime>? importedAt,
    Expression<String>? sourceMode,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (privatePath != null) 'private_path': privatePath,
      if (internalName != null) 'internal_name': internalName,
      if (mimeType != null) 'mime_type': mimeType,
      if (mediaHash != null) 'media_hash': mediaHash,
      if (importedAt != null) 'imported_at': importedAt,
      if (sourceMode != null) 'source_mode': sourceMode,
      if (status != null) 'status': status,
    });
  }

  MediaItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? privatePath,
    Value<String>? internalName,
    Value<String?>? mimeType,
    Value<String?>? mediaHash,
    Value<DateTime>? importedAt,
    Value<String>? sourceMode,
    Value<String>? status,
  }) {
    return MediaItemsCompanion(
      id: id ?? this.id,
      privatePath: privatePath ?? this.privatePath,
      internalName: internalName ?? this.internalName,
      mimeType: mimeType ?? this.mimeType,
      mediaHash: mediaHash ?? this.mediaHash,
      importedAt: importedAt ?? this.importedAt,
      sourceMode: sourceMode ?? this.sourceMode,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (privatePath.present) {
      map['private_path'] = Variable<String>(privatePath.value);
    }
    if (internalName.present) {
      map['internal_name'] = Variable<String>(internalName.value);
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
    if (sourceMode.present) {
      map['source_mode'] = Variable<String>(sourceMode.value);
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
          ..write('privatePath: $privatePath, ')
          ..write('internalName: $internalName, ')
          ..write('mimeType: $mimeType, ')
          ..write('mediaHash: $mediaHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('sourceMode: $sourceMode, ')
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
  final String engine;
  final String engineVersion;
  final DateTime processedAt;
  const OcrResult({
    required this.mediaItemId,
    required this.fullText,
    required this.engine,
    required this.engineVersion,
    required this.processedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['full_text'] = Variable<String>(fullText);
    map['engine'] = Variable<String>(engine);
    map['engine_version'] = Variable<String>(engineVersion);
    map['processed_at'] = Variable<DateTime>(processedAt);
    return map;
  }

  OcrResultsCompanion toCompanion(bool nullToAbsent) {
    return OcrResultsCompanion(
      mediaItemId: Value(mediaItemId),
      fullText: Value(fullText),
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
      'engine': serializer.toJson<String>(engine),
      'engineVersion': serializer.toJson<String>(engineVersion),
      'processedAt': serializer.toJson<DateTime>(processedAt),
    };
  }

  OcrResult copyWith({
    int? mediaItemId,
    String? fullText,
    String? engine,
    String? engineVersion,
    DateTime? processedAt,
  }) => OcrResult(
    mediaItemId: mediaItemId ?? this.mediaItemId,
    fullText: fullText ?? this.fullText,
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
          ..write('engine: $engine, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mediaItemId, fullText, engine, engineVersion, processedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrResult &&
          other.mediaItemId == this.mediaItemId &&
          other.fullText == this.fullText &&
          other.engine == this.engine &&
          other.engineVersion == this.engineVersion &&
          other.processedAt == this.processedAt);
}

class OcrResultsCompanion extends UpdateCompanion<OcrResult> {
  final Value<int> mediaItemId;
  final Value<String> fullText;
  final Value<String> engine;
  final Value<String> engineVersion;
  final Value<DateTime> processedAt;
  const OcrResultsCompanion({
    this.mediaItemId = const Value.absent(),
    this.fullText = const Value.absent(),
    this.engine = const Value.absent(),
    this.engineVersion = const Value.absent(),
    this.processedAt = const Value.absent(),
  });
  OcrResultsCompanion.insert({
    this.mediaItemId = const Value.absent(),
    required String fullText,
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
    Expression<String>? engine,
    Expression<String>? engineVersion,
    Expression<DateTime>? processedAt,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (fullText != null) 'full_text': fullText,
      if (engine != null) 'engine': engine,
      if (engineVersion != null) 'engine_version': engineVersion,
      if (processedAt != null) 'processed_at': processedAt,
    });
  }

  OcrResultsCompanion copyWith({
    Value<int>? mediaItemId,
    Value<String>? fullText,
    Value<String>? engine,
    Value<String>? engineVersion,
    Value<DateTime>? processedAt,
  }) {
    return OcrResultsCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      fullText: fullText ?? this.fullText,
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
          ..write('engine: $engine, ')
          ..write('engineVersion: $engineVersion, ')
          ..write('processedAt: $processedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ContextoDatabase extends GeneratedDatabase {
  _$ContextoDatabase(QueryExecutor e) : super(e);
  $ContextoDatabaseManager get managers => $ContextoDatabaseManager(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $OcrResultsTable ocrResults = $OcrResultsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [mediaItems, ocrResults];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ocr_results', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MediaItemsTableCreateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<int> id,
      required String privatePath,
      required String internalName,
      Value<String?> mimeType,
      Value<String?> mediaHash,
      required DateTime importedAt,
      required String sourceMode,
      required String status,
    });
typedef $$MediaItemsTableUpdateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<int> id,
      Value<String> privatePath,
      Value<String> internalName,
      Value<String?> mimeType,
      Value<String?> mediaHash,
      Value<DateTime> importedAt,
      Value<String> sourceMode,
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

  ColumnFilters<String> get privatePath => $composableBuilder(
    column: $table.privatePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get internalName => $composableBuilder(
    column: $table.internalName,
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

  ColumnFilters<String> get sourceMode => $composableBuilder(
    column: $table.sourceMode,
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

  ColumnOrderings<String> get privatePath => $composableBuilder(
    column: $table.privatePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get internalName => $composableBuilder(
    column: $table.internalName,
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

  ColumnOrderings<String> get sourceMode => $composableBuilder(
    column: $table.sourceMode,
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

  GeneratedColumn<String> get privatePath => $composableBuilder(
    column: $table.privatePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get internalName => $composableBuilder(
    column: $table.internalName,
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

  GeneratedColumn<String> get sourceMode => $composableBuilder(
    column: $table.sourceMode,
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
          PrefetchHooks Function({bool ocrResultsRefs})
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
                Value<String> privatePath = const Value.absent(),
                Value<String> internalName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String?> mediaHash = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<String> sourceMode = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => MediaItemsCompanion(
                id: id,
                privatePath: privatePath,
                internalName: internalName,
                mimeType: mimeType,
                mediaHash: mediaHash,
                importedAt: importedAt,
                sourceMode: sourceMode,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String privatePath,
                required String internalName,
                Value<String?> mimeType = const Value.absent(),
                Value<String?> mediaHash = const Value.absent(),
                required DateTime importedAt,
                required String sourceMode,
                required String status,
              }) => MediaItemsCompanion.insert(
                id: id,
                privatePath: privatePath,
                internalName: internalName,
                mimeType: mimeType,
                mediaHash: mediaHash,
                importedAt: importedAt,
                sourceMode: sourceMode,
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
          prefetchHooksCallback: ({ocrResultsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ocrResultsRefs) db.ocrResults],
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
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
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
      PrefetchHooks Function({bool ocrResultsRefs})
    >;
typedef $$OcrResultsTableCreateCompanionBuilder =
    OcrResultsCompanion Function({
      Value<int> mediaItemId,
      required String fullText,
      required String engine,
      required String engineVersion,
      required DateTime processedAt,
    });
typedef $$OcrResultsTableUpdateCompanionBuilder =
    OcrResultsCompanion Function({
      Value<int> mediaItemId,
      Value<String> fullText,
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
                Value<String> engine = const Value.absent(),
                Value<String> engineVersion = const Value.absent(),
                Value<DateTime> processedAt = const Value.absent(),
              }) => OcrResultsCompanion(
                mediaItemId: mediaItemId,
                fullText: fullText,
                engine: engine,
                engineVersion: engineVersion,
                processedAt: processedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> mediaItemId = const Value.absent(),
                required String fullText,
                required String engine,
                required String engineVersion,
                required DateTime processedAt,
              }) => OcrResultsCompanion.insert(
                mediaItemId: mediaItemId,
                fullText: fullText,
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

class $ContextoDatabaseManager {
  final _$ContextoDatabase _db;
  $ContextoDatabaseManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$OcrResultsTableTableManager get ocrResults =>
      $$OcrResultsTableTableManager(_db, _db.ocrResults);
}
