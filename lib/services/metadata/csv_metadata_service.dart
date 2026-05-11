import 'dart:io';
import 'package:aves/model/entry/entry.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CsvMetadataService {
  static const String dataFolderName = 'AvesData';

  // Get the base directory for AvesData: /storage/emulated/0/AvesData/
  static Future<Directory> getBaseDataDirectory() async {
    // path_provider's getExternalStorageDirectory() usually returns
    // /storage/emulated/0/Android/data/com.dekart.aves/files
    // We want /storage/emulated/0/AvesData/
    // On Android, we can try to navigate up from external storage directory.

    Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('External storage not available');
    }

    // externalDir is /storage/emulated/0/Android/data/package_name/files
    // We want to go up to /storage/emulated/0/
    String rootPath = externalDir.path;
    for (int i = 0; i < 4; i++) {
      rootPath = p.dirname(rootPath);
    }

    final dataDir = Directory(p.join(rootPath, dataFolderName));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir;
  }

  // Map album path to CSV filename
  // /storage/emulated/0/DCIM/Camera -> DCIM_Camera.csv
  static String _getSafeCsvName(String albumPath) {
    // Remove leading slash
    String path = albumPath;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    // Replace separators with underscore
    String name = path.replaceAll('/', '_').replaceAll(RegExp(r'[<>:"|?*]'), '_');
    return '$name.csv';
  }

  static Future<File> _getCsvFileForAlbum(String albumPath) async {
    final baseDir = await getBaseDataDirectory();
    final fileName = _getSafeCsvName(albumPath);
    return File(p.join(baseDir.path, fileName));
  }

  /// Create CSV for a given album and list of entries
  static Future<void> createCsv(String albumPath, List<AvesEntry> entries) async {
    final csvFile = await _getCsvFileForAlbum(albumPath);

    final headers = ['title', 'file_name', 'tags'];
    final rows = <List<dynamic>>[headers];

    for (final entry in entries) {
      rows.add(['', entry.filename ?? '', '']);
    }

    final csvContent = const ListToCsvConverter().convert(rows);
    await csvFile.writeAsString(csvContent);
  }

  static final Map<String, (DateTime, Map<String, Map<String, String>>)> _cache = {};

  /// Load CSV metadata for an album
  /// Returns a Map where key is file_name and value is a Map of column headers to values
  static Future<Map<String, Map<String, String>>> loadCsv(String albumPath) async {
    final csvFile = await _getCsvFileForAlbum(albumPath);

    if (!await csvFile.exists()) {
      _cache.remove(albumPath);
      return {};
    }

    try {
      final lastModified = await csvFile.lastModified();
      if (_cache.containsKey(albumPath)) {
        final (cachedTime, cachedData) = _cache[albumPath]!;
        if (cachedTime == lastModified) {
          return cachedData;
        }
      }

      final csvContent = await csvFile.readAsString();
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.isEmpty) return {};

      final headers = rows[0].map((e) => e.toString()).toList();
      final fileNameIndex = headers.indexOf('file_name');
      if (fileNameIndex == -1) return {};

      final metadataMap = <String, Map<String, String>>{};
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final fileName = row[fileNameIndex].toString();
        if (fileName.isEmpty) continue;

        final entryMetadata = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          if (j == fileNameIndex) continue;
          if (j < row.length) {
            entryMetadata[headers[j]] = row[j]?.toString() ?? '';
          } else {
            entryMetadata[headers[j]] = '';
          }
        }
        metadataMap[fileName] = entryMetadata;
      }
      _cache[albumPath] = (lastModified, metadataMap);
      return metadataMap;
    } catch (e) {
      // ignore errors
      return {};
    }
  }
}
