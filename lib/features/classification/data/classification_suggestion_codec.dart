import 'dart:convert';

import '../domain/classification_models.dart';

class ClassificationSuggestionPayloadCodec {
  const ClassificationSuggestionPayloadCodec();

  String encodeTags(List<SuggestedTag> tags) {
    return jsonEncode(
      tags
          .map(
            (tag) => <String, Object>{
              'name': tag.name,
              'confidence': tag.confidence,
              'evidence': tag.evidence.map(_encodeEvidence).toList(),
            },
          )
          .toList(),
    );
  }

  String encodeEvidence(List<ClassificationEvidence> evidence) {
    return jsonEncode(evidence.map(_encodeEvidence).toList());
  }

  List<SuggestedTag> decodeTags(String payload) {
    final values = _decodeList(payload, 'etiquetas');
    return List.unmodifiable(
      values.map((value) {
        final map = _asMap(value, 'etiqueta');
        return SuggestedTag(
          name: _string(map, 'name'),
          confidence: _number(map, 'confidence'),
          evidence: List.unmodifiable(
            _list(map, 'evidence').map(_decodeEvidence),
          ),
        );
      }),
    );
  }

  List<ClassificationEvidence> decodeEvidence(String payload) {
    return List.unmodifiable(
      _decodeList(payload, 'evidências').map(_decodeEvidence),
    );
  }

  Map<String, Object?> _encodeEvidence(ClassificationEvidence evidence) {
    return <String, Object?>{
      'ruleId': evidence.ruleId,
      'type': evidence.type.name,
      'description': evidence.description,
      'weight': evidence.weight,
      'safeMatch': evidence.safeMatch,
      'position': evidence.position,
      'count': evidence.count,
    };
  }

  ClassificationEvidence _decodeEvidence(Object? value) {
    final map = _asMap(value, 'evidência');
    final typeName = _string(map, 'type');
    final type = ClassificationEvidenceType.values.where(
      (item) => item.name == typeName,
    );
    if (type.length != 1) {
      throw FormatException('Tipo de evidência inválido: $typeName');
    }
    return ClassificationEvidence(
      ruleId: _string(map, 'ruleId'),
      type: type.single,
      description: _string(map, 'description'),
      weight: _number(map, 'weight'),
      safeMatch: _nullableString(map, 'safeMatch'),
      position: _nullableInt(map, 'position'),
      count: _nullableInt(map, 'count'),
    );
  }

  List<Object?> _decodeList(String payload, String label) {
    try {
      final value = jsonDecode(payload);
      if (value is! List<Object?>) throw FormatException('$label inválidas.');
      return value;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Payload de $label inválido.', error);
    }
  }

  Map<String, Object?> _asMap(Object? value, String label) {
    if (value is! Map<String, Object?>) {
      throw FormatException('$label inválida.');
    }
    return value;
  }

  List<Object?> _list(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! List<Object?>) throw FormatException('$key inválido.');
    return value;
  }

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key inválido.');
    return value;
  }

  String? _nullableString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw FormatException('$key inválido.');
    }
    return value as String?;
  }

  double _number(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! num) throw FormatException('$key inválido.');
    return value.toDouble();
  }

  int? _nullableInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! int) {
      throw FormatException('$key inválido.');
    }
    return value as int?;
  }
}
