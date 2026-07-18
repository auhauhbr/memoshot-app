import 'dart:io';

import 'package:memoshot/core/media/file_hash_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  const calculator = Sha256FileHashCalculator();

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'memoshot_hash_test_',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('calcula o mesmo hash para conteúdos idênticos', () async {
    final first = File('${temporaryDirectory.path}/primeiro.bin')
      ..writeAsBytesSync([1, 2, 3, 4]);
    final second = File('${temporaryDirectory.path}/segundo.bin')
      ..writeAsBytesSync([1, 2, 3, 4]);

    expect(
      await calculator.calculate(first.path),
      await calculator.calculate(second.path),
    );
  });

  test('calcula hashes diferentes para conteúdos diferentes', () async {
    final first = File('${temporaryDirectory.path}/primeiro.bin')
      ..writeAsBytesSync([1, 2, 3, 4]);
    final second = File('${temporaryDirectory.path}/segundo.bin')
      ..writeAsBytesSync([4, 3, 2, 1]);

    expect(
      await calculator.calculate(first.path),
      isNot(await calculator.calculate(second.path)),
    );
  });
}
