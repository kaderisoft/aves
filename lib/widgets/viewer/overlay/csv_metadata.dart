import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/services/metadata/csv_metadata_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CsvMetadataOverlay extends StatefulWidget {
  final AvesEntry entry;

  const CsvMetadataOverlay({
    super.key,
    required this.entry,
  });

  @override
  State<CsvMetadataOverlay> createState() => _CsvMetadataOverlayState();
}

class _CsvMetadataOverlayState extends State<CsvMetadataOverlay> {
  Map<String, String>? _metadata;
  String? _lastFilename;
  String? _lastAlbum;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant CsvMetadataOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.filename != widget.entry.filename || oldWidget.entry.directory != widget.entry.directory) {
      _loadMetadata();
    }
  }

  Future<void> _loadMetadata() async {
    final filename = widget.entry.filename;
    final album = widget.entry.directory;
    if (filename == null || album == null) return;

    final albumMetadata = await CsvMetadataService.loadCsv(album);
    if (mounted) {
      setState(() {
        _metadata = albumMetadata[filename];
        _lastFilename = filename;
        _lastAlbum = album;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOverlay = context.select<ValueNotifier<bool>, bool>((v) => v.value);
    if (!showOverlay || _metadata == null || _metadata!.isEmpty) {
      return const SizedBox();
    }

    final children = <Widget>[];
    _metadata!.forEach((key, value) {
      if (value.isNotEmpty) {
        if (key == 'title' || key == 'tags') {
          children.add(Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ));
        } else {
          children.add(Text(
            '$key: $value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ));
        }
      }
    });

    if (children.isEmpty) return const SizedBox();

    return Positioned(
      bottom: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
