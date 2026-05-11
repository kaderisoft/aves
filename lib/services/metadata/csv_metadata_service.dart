import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

/// نموذج البيانات الوصفية
class ImageMetadata {
  final String filename;
  final String title;
  final String tags;
  final Map<String, String> customData;

  ImageMetadata({
    required this.filename,
    required this.title,
    required this.tags,
    this.customData = const {},
  });

  factory ImageMetadata.fromCsvRow(List<dynamic> row, List<String> headers) {
    final data = <String, String>{};
    for (int i = 0; i < headers.length; i++) {
      if (i < row.length) {
        data[headers[i]] = row[i]?.toString() ?? '';
      }
    }

    return ImageMetadata(
      filename: data['file name'] ?? '',
      title: data['title'] ?? '',
      tags: data['tages'] ?? '',
      customData: data,
    );
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'title': title,
    'tags': tags,
    'customData': customData,
  };
}

/// خدمة إدارة ملفات CSV للبيانات الوصفية
class CsvMetadataService {
  static const String _dataFolderName = 'data';
  static const String _csvFileName = 'metadata.csv';

  /// إنشاء مسار مجلد البيانات
  static Future<Directory> getDataDirectory() async {
    final appDocDir = Directory.systemTemp;
    final dataDir = Directory(p.join(appDocDir.path, _dataFolderName));
    
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    
    return dataDir;
  }

  /// الحصول على مسار ملف CSV
  static Future<File> getMetadataFile() async {
    final dataDir = await getDataDirectory();
    return File(p.join(dataDir.path, _csvFileName));
  }

  /// إنشاء ملف CSV جديد مع أسماء الصور من مجلد
  static Future<void> createCsvFromFolder(Directory folderPath, List<String> imageExtensions) async {
    try {
      final metadataFile = await getMetadataFile();
      
      // الحصول على الصور من المجلد
      final imageFiles = folderPath
          .listSync()
          .whereType<File>()
          .where((file) => imageExtensions.contains(p.extension(file.path).toLowerCase()))
          .toList();

      // إنشاء رؤوس CSV
      final headers = ['title', 'file name', 'tages'];
      
      // إنشاء البيانات
      final rows = <List<String>>[];
      for (var file in imageFiles) {
        final filename = p.basename(file.path);
        rows.add(['', filename, '']);
      }

      // تحويل إلى CSV
      final csvContent = const ListToCsvConverter().convert([headers, ...rows]);
      
      // كتابة الملف
      await metadataFile.writeAsString(csvContent);
    } catch (e) {
      throw Exception('فشل إنشاء ملف CSV: $e');
    }
  }

  /// قراءة البيانات من ملف CSV
  static Future<Map<String, ImageMetadata>> readMetadata() async {
    try {
      final metadataFile = await getMetadataFile();
      
      if (!await metadataFile.exists()) {
        return {};
      }

      final csvContent = await metadataFile.readAsString();
      final rows = const CsvToListConverter().convert(csvContent);
      
      if (rows.isEmpty) return {};

      // استخراج الرؤوس
      final headers = rows[0].cast<String>();
      
      // تحويل الصفوف إلى كائنات ImageMetadata
      final metadata = <String, ImageMetadata>{};
      for (int i = 1; i < rows.length; i++) {
        final imageData = ImageMetadata.fromCsvRow(rows[i], headers);
        if (imageData.filename.isNotEmpty) {
          metadata[imageData.filename] = imageData;
        }
      }
      
      return metadata;
    } catch (e) {
      throw Exception('فشل قراءة ملف CSV: $e');
    }
  }

  /// الحصول على البيانات الوصفية لصورة معينة
  static Future<ImageMetadata?> getImageMetadata(String filename) async {
    final metadata = await readMetadata();
    return metadata[filename];
  }

  /// تحديث البيانات الوصفية
  static Future<void> updateMetadata(Map<String, ImageMetadata> metadata) async {
    try {
      final metadataFile = await getMetadataFile();
      
      // إنشاء رؤوس CSV
      final headers = ['title', 'file name', 'tages'];
      
      // إنشاء الصفوف
      final rows = <List<String>>[];
      for (var data in metadata.values) {
        rows.add([
          data.title,
          data.filename,
          data.tags,
        ]);
      }

      // تحويل إلى CSV
      final csvContent = const ListToCsvConverter().convert([headers, ...rows]);
      
      // كتابة الملف
      await metadataFile.writeAsString(csvContent);
    } catch (e) {
      throw Exception('فشل تحديث ملف CSV: $e');
    }
  }

  /// حذف ملف CSV
  static Future<void> deleteMetadataFile() async {
    try {
      final metadataFile = await getMetadataFile();
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
    } catch (e) {
      throw Exception('فشل حذف ملف CSV: $e');
    }
  }

  /// الحصول على مسار ملف CSV (للمستخدم)
  static Future<String> getMetadataFilePath() async {
    final file = await getMetadataFile();
    return file.path;
  }
}
