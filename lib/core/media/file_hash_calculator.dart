import 'dart:io';

import 'package:crypto/crypto.dart';

abstract interface class FileHashCalculator {
  Future<String> calculate(String filePath);
}

class Sha256FileHashCalculator implements FileHashCalculator {
  const Sha256FileHashCalculator();

  @override
  Future<String> calculate(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FileSystemException('Arquivo indisponível.');
    }

    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
