import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../text/text_normalizer.dart';

part 'contexto_database.g.dart';

class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get privatePath => text()();

  TextColumn get internalName => text()();

  TextColumn get mimeType => text().nullable()();

  TextColumn get mediaHash => text().nullable()();

  DateTimeColumn get importedAt => dateTime()();

  DateTimeColumn get capturedAt => dateTime().nullable()();

  TextColumn get sourceMode => text()();

  TextColumn get importOrigin => text().withDefault(const Constant('picker'))();

  TextColumn get status => text()();
}

class OcrResults extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get fullText => text()();

  TextColumn get normalizedText => text().withDefault(const Constant(''))();

  TextColumn get engine => text()();

  TextColumn get engineVersion => text()();

  DateTimeColumn get processedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId};
}

class ProcessingJobs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get jobType => text()();

  TextColumn get status => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get errorCode => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {mediaItemId, jobType},
  ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get normalizedName => text()();

  IntColumn get parentId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();

  DateTimeColumn get createdAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (parent_id IS NULL OR parent_id <> id)',
  ];
}

class MediaCategories extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId, categoryId};
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get normalizedName => text().unique()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();
}

class MediaTags extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId, tagId};
}

class AutomaticImportSettings extends Table {
  IntColumn get id => integer()();

  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  IntColumn get lastMediaId => integer().nullable()();

  DateTimeColumn get enabledAt => dateTime().nullable()();

  DateTimeColumn get lastScanAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ClassificationSuggestions extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get suggestedCategoryName => text().nullable()();

  RealColumn get confidence => real()();

  BoolColumn get hasSuggestion => boolean()();

  TextColumn get suggestedTagsJson => text()();

  TextColumn get evidenceJson => text()();

  TextColumn get status => text()();

  TextColumn get reviewReason => text().nullable()();

  IntColumn get engineVersion => integer()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId};

  @override
  List<String> get customConstraints => const [
    'CHECK (confidence >= 0 AND confidence <= 1)',
  ];
}

class ClassificationJobs extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();

  TextColumn get state => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get availableAt => dateTime()();

  IntColumn get engineVersion => integer()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get processingStartedAt => dateTime().nullable()();

  TextColumn get lastErrorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {mediaItemId};
}

class ExistingScreenshotCandidates extends Table {
  TextColumn get sourceKey => text()();

  IntColumn get mediaStoreId => integer()();

  TextColumn get volumeName => text()();

  TextColumn get contentUri => text()();

  TextColumn get mimeType => text().nullable()();

  DateTimeColumn get capturedAt => dateTime().nullable()();

  DateTimeColumn get dateModified => dateTime().nullable()();

  IntColumn get sizeBytes => integer().nullable()();

  IntColumn get width => integer().nullable()();

  IntColumn get height => integer().nullable()();

  DateTimeColumn get discoveredAt => dateTime()();

  DateTimeColumn get lastSeenAt => dateTime()();

  TextColumn get availabilityState => text()();

  @override
  Set<Column<Object>> get primaryKey => {sourceKey};

  @override
  List<String> get customConstraints => const [
    "CHECK (availability_state IN ('available', 'unavailable'))",
  ];
}

class ExistingScreenshotInventoryStates extends Table {
  IntColumn get id => integer()();

  DateTimeColumn get lastCompletedScanAt => dateTime().nullable()();

  BoolColumn get lastScanWasPartial =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    MediaItems,
    OcrResults,
    ProcessingJobs,
    Categories,
    MediaCategories,
    Tags,
    MediaTags,
    AutomaticImportSettings,
    ClassificationSuggestions,
    ClassificationJobs,
    ExistingScreenshotCandidates,
    ExistingScreenshotInventoryStates,
  ],
)
class ContextoDatabase extends _$ContextoDatabase {
  ContextoDatabase() : super(_openConnection());

  ContextoDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createMediaHashIndex();
      await _createCategoryNameIndexes();
      await _createClassificationJobIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(mediaItems, mediaItems.mediaHash);
        await _createMediaHashIndex();
      }
      if (from < 3) {
        await migrator.createTable(ocrResults);
      }
      if (from < 4) {
        await migrator.createTable(processingJobs);
      }
      if (from >= 3 && from < 5) {
        await migrator.addColumn(ocrResults, ocrResults.normalizedText);
        await _backfillNormalizedOcrText();
      }
      if (from < 6) {
        await migrator.createTable(categories);
        await migrator.createTable(mediaCategories);
      }
      if (from < 7) {
        await migrator.addColumn(mediaItems, mediaItems.importOrigin);
      }
      if (from < 8) {
        await migrator.createTable(automaticImportSettings);
      }
      if (from < 9) {
        await migrator.addColumn(mediaItems, mediaItems.capturedAt);
        await customStatement(
          'UPDATE media_items SET captured_at = imported_at '
          'WHERE captured_at IS NULL',
        );
      }
      if (from < 10) {
        await migrator.createTable(tags);
        await migrator.createTable(mediaTags);
      }
      if (from >= 6 && from < 11) {
        await migrator.alterTable(
          TableMigration(categories, newColumns: [categories.parentId]),
        );
      }
      if (from < 11) {
        await _createCategoryNameIndexes();
      }
      if (from < 12) {
        await migrator.createTable(classificationSuggestions);
      }
      if (from < 13) {
        await migrator.createTable(classificationJobs);
        await _createClassificationJobIndexes();
      }
      if (from < 14) {
        await migrator.createTable(existingScreenshotCandidates);
        await migrator.createTable(existingScreenshotInventoryStates);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _backfillNormalizedOcrText();
    },
  );

  Future<void> _createMediaHashIndex() {
    return customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS media_items_media_hash_unique '
      'ON media_items (media_hash) WHERE media_hash IS NOT NULL',
    );
  }

  Future<void> _createCategoryNameIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS categories_root_name_unique '
      'ON categories (normalized_name) WHERE parent_id IS NULL',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS categories_child_name_unique '
      'ON categories (parent_id, normalized_name) '
      'WHERE parent_id IS NOT NULL',
    );
  }

  Future<void> _createClassificationJobIndexes() {
    return customStatement(
      'CREATE INDEX IF NOT EXISTS classification_jobs_available_idx '
      'ON classification_jobs (state, available_at, created_at, media_item_id)',
    );
  }

  Future<void> _backfillNormalizedOcrText() async {
    final rows = await customSelect(
      'SELECT media_item_id, full_text FROM ocr_results '
      "WHERE normalized_text = '' AND full_text <> ''",
      readsFrom: {ocrResults},
    ).get();
    const normalizer = TextNormalizer();
    for (final row in rows) {
      await customUpdate(
        'UPDATE ocr_results SET normalized_text = ? WHERE media_item_id = ?',
        variables: [
          Variable<String>(normalizer.normalize(row.read<String>('full_text'))),
          Variable<int>(row.read<int>('media_item_id')),
        ],
        updates: {ocrResults},
      );
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'contexto');
  }
}
