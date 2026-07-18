import 'dart:io';

import '../../../core/text/text_normalizer.dart';
import '../../library/domain/media_item.dart';
import '../domain/tag.dart';
import 'tag_store.dart';

enum TagValidationError { empty, tooLong, duplicate }

class TagValidationException implements Exception {
  const TagValidationException(this.error);

  final TagValidationError error;
}

abstract interface class TagRepository {
  Future<Tag> createTag(String name);

  Future<List<Tag>> loadTags();

  Future<Tag?> findById(int id);

  Future<Tag?> findByNormalizedName(String normalizedName);

  Future<Tag> renameTag(Tag tag, String name);

  Future<void> deleteTag(int tagId);

  Future<void> addToMedia({required int tagId, required int mediaItemId});

  Future<void> removeFromMedia({required int tagId, required int mediaItemId});

  Future<bool> isAssociated({required int tagId, required int mediaItemId});

  Future<List<Tag>> loadForMedia(int mediaItemId);

  Future<List<MediaItem>> loadMediaForTag(int tagId);
}

class LocalTagRepository implements TagRepository {
  LocalTagRepository({
    required TagStore store,
    TextNormalizer normalizer = const TextNormalizer(),
  }) : this._(store, normalizer);

  LocalTagRepository._(this._store, this._normalizer);

  final TagStore _store;
  final TextNormalizer _normalizer;

  @override
  Future<Tag> createTag(String name) async {
    final (visibleName, normalizedName) = _validateName(name);
    if (await _store.findByNormalizedName(normalizedName) != null) {
      throw const TagValidationException(TagValidationError.duplicate);
    }
    final now = DateTime.now();
    try {
      final id = await _store.insertTag(
        name: visibleName,
        normalizedName: normalizedName,
        createdAt: now,
        updatedAt: now,
      );
      return Tag(
        id: id,
        name: visibleName,
        normalizedName: normalizedName,
        createdAt: now,
        updatedAt: now,
      );
    } catch (_) {
      if (await _store.findByNormalizedName(normalizedName) != null) {
        throw const TagValidationException(TagValidationError.duplicate);
      }
      rethrow;
    }
  }

  @override
  Future<List<Tag>> loadTags() => _store.listTags();

  @override
  Future<Tag?> findById(int id) => _store.findById(id);

  @override
  Future<Tag?> findByNormalizedName(String normalizedName) {
    return _store.findByNormalizedName(_normalizer.normalize(normalizedName));
  }

  @override
  Future<Tag> renameTag(Tag tag, String name) async {
    final (visibleName, normalizedName) = _validateName(name);
    final existing = await _store.findByNormalizedName(normalizedName);
    if (existing != null && existing.id != tag.id) {
      throw const TagValidationException(TagValidationError.duplicate);
    }
    final updatedAt = DateTime.now();
    try {
      await _store.updateTag(
        id: tag.id,
        name: visibleName,
        normalizedName: normalizedName,
        updatedAt: updatedAt,
      );
    } catch (_) {
      final conflict = await _store.findByNormalizedName(normalizedName);
      if (conflict != null && conflict.id != tag.id) {
        throw const TagValidationException(TagValidationError.duplicate);
      }
      rethrow;
    }
    return Tag(
      id: tag.id,
      name: visibleName,
      normalizedName: normalizedName,
      createdAt: tag.createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> deleteTag(int tagId) => _store.deleteTag(tagId);

  @override
  Future<void> addToMedia({required int tagId, required int mediaItemId}) {
    return _store.addToMedia(
      tagId: tagId,
      mediaItemId: mediaItemId,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeFromMedia({required int tagId, required int mediaItemId}) {
    return _store.removeFromMedia(tagId: tagId, mediaItemId: mediaItemId);
  }

  @override
  Future<bool> isAssociated({required int tagId, required int mediaItemId}) {
    return _store.associationExists(tagId: tagId, mediaItemId: mediaItemId);
  }

  @override
  Future<List<Tag>> loadForMedia(int mediaItemId) {
    return _store.listForMedia(mediaItemId);
  }

  @override
  Future<List<MediaItem>> loadMediaForTag(int tagId) async {
    final items = await _store.listMediaForTag(tagId);
    return items
        .where((item) => File(item.privatePath).existsSync())
        .toList(growable: false);
  }

  (String, String) _validateName(String name) {
    final visibleName = name.trim();
    final normalizedName = _normalizer.normalize(visibleName);
    if (normalizedName.isEmpty) {
      throw const TagValidationException(TagValidationError.empty);
    }
    if (visibleName.length > 40) {
      throw const TagValidationException(TagValidationError.tooLong);
    }
    return (visibleName, normalizedName);
  }
}
