// lib/src/services/share_file_staging_service.dart
// Android共有のcontent URIをアプリ管理下の一時領域へ安全にコピーする。
// receive_sharing_intentが通常返す一時ファイルパスも再度Stagingへ隔離する。

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';

class ShareFileStagingException implements Exception {
  const ShareFileStagingException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

@immutable
class StagedShareFile {
  const StagedShareFile({
    required this.path,
    required this.type,
    this.mimeType,
  });

  final String path;
  final SharedMediaType type;
  final String? mimeType;
}

class ShareFileStagingService {
  ShareFileStagingService({
    Future<Directory> Function()? temporaryDirectoryProvider,
    Uuid? uuid,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _uuid = uuid ?? const Uuid();

  static const _channel = MethodChannel('ashita_motsumono/share_file_staging');
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _maxPdfBytes = 25 * 1024 * 1024;

  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Uuid _uuid;

  Future<T> withStagedFiles<T>({
    required List<SharedMediaFile> files,
    required Future<T> Function(List<StagedShareFile> files) action,
  }) async {
    final root = await _temporaryDirectoryProvider();
    final staging = Directory(p.join(root.path, 'share_${_uuid.v4()}'));
    await staging.create(recursive: true);

    try {
      final staged = <StagedShareFile>[];
      for (final file in files) {
        staged.add(await _stage(file, staging));
      }
      return await action(List<StagedShareFile>.unmodifiable(staged));
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } on Object catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              'ShareFileStagingService: cleanup failed: '
              '$error\n$stackTrace',
            );
          }
        }
      }
    }
  }

  Future<StagedShareFile> _stage(
    SharedMediaFile file,
    Directory staging,
  ) async {
    final sourcePath = file.path.trim();
    if (sourcePath.isEmpty) {
      throw const ShareFileStagingException('共有ファイルのパスが空です。');
    }

    final mimeType = file.mimeType?.trim().toLowerCase();
    final extension = _extensionFor(sourcePath, mimeType);
    final maxBytes = _maxBytesFor(file, mimeType);
    final uri = Uri.tryParse(sourcePath);

    final stagedPath = uri?.scheme == 'content'
        ? await _copyContentUri(
            uri: sourcePath,
            destinationDirectory: staging,
            extension: extension,
            mimeType: mimeType,
            maxBytes: maxBytes,
          )
        : await _copyLocalFile(
            sourcePath: sourcePath,
            destinationDirectory: staging,
            extension: extension,
            maxBytes: maxBytes,
          );

    return StagedShareFile(
      path: stagedPath,
      type: file.type,
      mimeType: mimeType,
    );
  }

  Future<String> _copyContentUri({
    required String uri,
    required Directory destinationDirectory,
    required String extension,
    required String? mimeType,
    required int maxBytes,
  }) async {
    if (!Platform.isAndroid) {
      throw const ShareFileStagingException(
        'content URIの共有受信はAndroidでのみ利用できます。',
      );
    }

    try {
      final copiedPath = await _channel
          .invokeMethod<String>('copyContentUriToStaging', <String, Object?>{
            'uri': uri,
            'destinationDirectory': destinationDirectory.path,
            'extension': extension,
            'mimeType': mimeType,
            'maxBytes': maxBytes,
          });
      if (copiedPath == null || copiedPath.trim().isEmpty) {
        throw const ShareFileStagingException('共有ファイルのコピー結果が空です。');
      }
      final copied = File(copiedPath);
      if (!await copied.exists() || await copied.length() <= 0) {
        throw const ShareFileStagingException('共有ファイルをStagingへコピーできませんでした。');
      }
      return copied.path;
    } on ShareFileStagingException {
      rethrow;
    } on PlatformException catch (error) {
      throw ShareFileStagingException(
        error.message ?? '共有ファイルを読み込めませんでした。',
        cause: error,
      );
    } on MissingPluginException catch (error) {
      throw ShareFileStagingException(
        '共有ファイルのネイティブコピー処理が見つかりません。アプリを再ビルドしてください。',
        cause: error,
      );
    }
  }

  Future<String> _copyLocalFile({
    required String sourcePath,
    required Directory destinationDirectory,
    required String extension,
    required int maxBytes,
  }) async {
    final uri = Uri.tryParse(sourcePath);
    final resolvedPath = uri?.scheme == 'file' ? uri!.toFilePath() : sourcePath;
    final source = File(resolvedPath);

    try {
      if (!await source.exists()) {
        throw const ShareFileStagingException('共有ファイルが見つかりません。');
      }
      final length = await source.length();
      if (length <= 0) {
        throw const ShareFileStagingException('共有ファイルが空です。');
      }
      if (length > maxBytes) {
        throw ShareFileStagingException(
          maxBytes == _maxImageBytes
              ? '画像サイズが大きすぎます（上限5MB）。'
              : 'PDFサイズが大きすぎます（上限25MB）。',
        );
      }

      final destination = File(
        p.join(destinationDirectory.path, '${_uuid.v4()}$extension'),
      );
      await source.copy(destination.path);
      return destination.path;
    } on ShareFileStagingException {
      rethrow;
    } on Object catch (error) {
      throw ShareFileStagingException(
        '共有ファイルをStagingへコピーできませんでした。',
        cause: error,
      );
    }
  }

  int _maxBytesFor(SharedMediaFile file, String? mimeType) {
    if (mimeType == 'application/pdf' || _isPdfPath(file.path)) {
      return _maxPdfBytes;
    }
    if (file.type == SharedMediaType.image ||
        (mimeType?.startsWith('image/') ?? false)) {
      return _maxImageBytes;
    }
    return _maxPdfBytes;
  }

  bool _isPdfPath(String sourcePath) {
    final uriPath = Uri.tryParse(sourcePath)?.path ?? sourcePath;
    return uriPath.toLowerCase().endsWith('.pdf');
  }

  String _extensionFor(String sourcePath, String? mimeType) {
    final uriPath = Uri.tryParse(sourcePath)?.path ?? sourcePath;
    final pathExtension = p.extension(uriPath).toLowerCase();
    if (_isSafeExtension(pathExtension)) return pathExtension;

    return switch (mimeType) {
      'application/pdf' => '.pdf',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/jpeg' || 'image/jpg' => '.jpg',
      _ => '.bin',
    };
  }

  bool _isSafeExtension(String extension) =>
      RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension);
}
