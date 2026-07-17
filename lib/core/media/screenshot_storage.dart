import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract interface class ScreenshotStorage {
  Future<StoredScreenshot> copyToPrivate(String sourcePath);

  Future<void> deletePrivateCopy(String privatePath);
}

class StoredScreenshot {
  const StoredScreenshot({
    required this.privatePath,
    required this.internalName,
  });

  final String privatePath;
  final String internalName;
}

class PrivateScreenshotStorage implements ScreenshotStorage {
  PrivateScreenshotStorage({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  int _sequence = 0;

  @override
  Future<StoredScreenshot> copyToPrivate(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Arquivo de origem indisponível.');
    }

    final documents = await _documentsDirectory();
    final screenshotsDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}screenshots',
    );
    await screenshotsDirectory.create(recursive: true);

    final extension = _safeExtension(sourcePath);
    String internalName;
    File destination;
    do {
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      internalName = 'screenshot_${timestamp}_${_sequence++}$extension';
      destination = File(
        '${screenshotsDirectory.path}${Platform.pathSeparator}$internalName',
      );
    } while (await destination.exists());

    await source.copy(destination.path);
    return StoredScreenshot(
      privatePath: destination.path,
      internalName: internalName,
    );
  }

  @override
  Future<void> deletePrivateCopy(String privatePath) async {
    final copy = File(privatePath);
    if (await copy.exists()) {
      await copy.delete();
    }
  }

  String _safeExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
      return '';
    }

    final extension = fileName.substring(dotIndex).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension) ? extension : '';
  }
}
