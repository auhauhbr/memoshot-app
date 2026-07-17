import 'text_normalizer.dart';

class SearchSnippetBuilder {
  const SearchSnippetBuilder({
    this.maxLength = 140,
    this.normalizer = const TextNormalizer(),
  });

  final int maxLength;
  final TextNormalizer normalizer;

  String build(String fullText, String query) {
    final words = RegExp(r'\S+')
        .allMatches(fullText)
        .map((match) {
          return match.group(0)!;
        })
        .toList(growable: false);
    if (words.isEmpty) {
      return '';
    }

    final normalizedWords = words.map(normalizer.normalize).toList();
    final normalizedText = normalizedWords.join(' ');
    final normalizedQuery = normalizer.normalize(query);
    final matchIndex = normalizedText.indexOf(normalizedQuery);
    var centerWord = 0;
    if (matchIndex >= 0) {
      var offset = 0;
      for (var index = 0; index < normalizedWords.length; index++) {
        final end = offset + normalizedWords[index].length;
        if (matchIndex <= end) {
          centerWord = index;
          break;
        }
        offset = end + 1;
      }
    }

    var start = centerWord;
    var end = centerWord + 1;
    var length = words[centerWord].length;
    while (true) {
      final canAddBefore = start > 0;
      final canAddAfter = end < words.length;
      if (!canAddBefore && !canAddAfter) {
        break;
      }
      final beforeLength = canAddBefore ? words[start - 1].length + 1 : 1 << 30;
      final afterLength = canAddAfter ? words[end].length + 1 : 1 << 30;
      final addBefore = beforeLength <= afterLength;
      final addedLength = addBefore ? beforeLength : afterLength;
      if (length + addedLength > maxLength) {
        break;
      }
      if (addBefore) {
        start--;
      } else {
        end++;
      }
      length += addedLength;
    }

    final snippet = words.sublist(start, end).join(' ');
    return '${start > 0 ? '…' : ''}$snippet${end < words.length ? '…' : ''}';
  }
}
