part of 'add_todo_screen.dart';

extension _AddTodoImageReviewActions on _AddTodoScreenState {
  Future<void> _pickImagesWithReview() async {
    _update(() => _busy = true);
    try {
      final service = _ocrPickService();
      final picked = await service.pickMultipleImageFiles();
      if (!mounted || picked.isEmpty) return;

      _update(() => _busy = false);
      final selected = picked.length == 1
          ? picked
          : await Navigator.of(context).push<List<XFile>>(
              MaterialPageRoute(
                builder: (_) => ImageIntakeReviewScreen(files: picked),
              ),
            );
      if (!mounted || selected == null || selected.isEmpty) return;

      final token = IntakeCancellationToken();
      _update(() {
        _busy = true;
        _cancellationToken = token;
      });
      final result = await service.processPickedImages(
        selected,
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted) return;
          if (_intakeProgress == null) {
            _beginIntake(token, progress);
          } else {
            _updateIntakeProgress(progress);
          }
        },
      );
      if (!mounted || token.isCancelled) return;
      await _handleOcrPickResult(result, showNoCandidates: true);
    } on OcrException catch (error) {
      if (kDebugMode) debugPrint('Image intake error: ${error.cause ?? error}');
      _showOcrError(error.message);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Image intake error: $error');
      _showOcrError('画像の取り込みに失敗しました。');
    } finally {
      _endIntake();
    }
  }
}
