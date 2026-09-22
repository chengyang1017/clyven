import 'package:glyphora_language_core/glyphora_language_core.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/deepgram_asr_service.dart';

class AsrFutureCall extends FutureCall {
  static const _service = DeepgramAsrService();

  Future<void> transcribe(
    Session session,
    int jobId,
  ) async {
    final job = await AsrJob.db.findById(
      session,
      jobId,
    );

    if (job == null) {
      return;
    }

    // Safe against accidental duplicate future-call execution.
    if (job.status == AsrJobStatus.readyForReview) {
      return;
    }

    job
      ..status = AsrJobStatus.processing
      ..errorMessage = null
      ..updatedAt = DateTime.now();

    await AsrJob.db.updateRow(
      session,
      job,
    );

    try {
      final video = await Video.db.findById(
        session,
        job.videoId,
      );

      if (video == null) {
        throw StateError('Video ${job.videoId} no longer exists');
      }

      final videoUri = await session.storage.getPublicUrl(
        storageId: 'public',
        path: video.videoStorageKey,
      );

      if (videoUri == null) {
        throw StateError(
          'Could not create a public URL for ${video.videoStorageKey}',
        );
      }

      final transcript = await _service.transcribe(
        videoUrl: videoUri.toString(),
        requestedLanguageCode: job.requestedLanguageCode,
      );

      final resolvedLanguage = transcript.languageCode.trim();

      if (resolvedLanguage.isEmpty) {
        throw StateError('ASR returned an empty language code');
      }

      final existingTrack = await SubtitleTrack.db.findFirstRow(
        session,
        where: (track) =>
            track.videoId.equals(video.id!) &
            track.languageCode.equals(resolvedLanguage),
      );

      if (existingTrack != null) {
        final existingCues = await SubtitleCue.db.find(
          session,
          where: (cue) => cue.trackId.equals(existingTrack.id),
          limit: 1,
        );

        if (existingCues.isNotEmpty) {
          throw StateError(
            'Subtitle track $resolvedLanguage already has content; '
            'ASR will not overwrite it',
          );
        }
      }

      final fullText = transcript.segments
          .map((segment) => segment.text)
          .join('\n');

      final scriptCode = _resolveScriptCode(
        languageCode: resolvedLanguage,
        text: fullText,
      );

      final now = DateTime.now();

      final track =
          existingTrack ??
          await SubtitleTrack.db.insertRow(
            session,
            SubtitleTrack(
              videoId: video.id!,
              languageCode: resolvedLanguage,
              variantCode: null,
              label: _languageLabel(resolvedLanguage),
              defaultScriptCode: scriptCode,
              isDefault: true,
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (track.id == null) {
        throw StateError('Failed to create subtitle track');
      }

      // Important:
      // Creating a publish-state row with NO publishedPayload makes this
      // track a real draft. The viewer app will not expose it before review.
      final existingPublishState =
          await SubtitlePublishState.db.findFirstRow(
            session,
            where: (state) => state.trackId.equals(track.id!),
          );

      if (existingPublishState == null) {
        await SubtitlePublishState.db.insertRow(
          session,
          SubtitlePublishState(
            trackId: track.id!,
            publishedPayload: null,
            publishedAt: null,
            draftRevision: 1,
            publishedRevision: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      for (final segment in transcript.segments) {
        final text = segment.text.trim();

        if (text.isEmpty) {
          continue;
        }

        final cue = await SubtitleCue.db.insertRow(
          session,
          SubtitleCue(
            trackId: track.id!,
            startMs: segment.startMs,
            endMs: segment.endMs <= segment.startMs
                ? segment.startMs + 500
                : segment.endMs,
            text: text,
            createdAt: now,
            updatedAt: now,
          ),
        );

        if (cue.id == null) {
          continue;
        }

        await SubtitleCueText.db.insertRow(
          session,
          SubtitleCueText(
            cueId: cue.id!,
            scriptCode: scriptCode,
            text: text,
            normalizedText: null,
            isPrimary: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Save the actual detected/used language on the video itself.
      video
        ..languageCode = resolvedLanguage
        ..updatedAt = DateTime.now();

      await Video.db.updateRow(
        session,
        video,
      );

      job
        ..detectedLanguageCode = resolvedLanguage
        ..trackId = track.id
        ..status = AsrJobStatus.readyForReview
        ..errorMessage = null
        ..updatedAt = DateTime.now();

      await AsrJob.db.updateRow(
        session,
        job,
      );
    } catch (error, stackTrace) {
      session.log(
        'ASR job $jobId failed: $error',
        level: LogLevel.error,
        stackTrace: stackTrace,
      );

      job
        ..status = AsrJobStatus.failed
        ..errorMessage = error.toString()
        ..updatedAt = DateTime.now();

      await AsrJob.db.updateRow(
        session,
        job,
      );
    }
  }

  String _languageLabel(String code) {
    final base = _baseLanguageCode(code);
    final language = LanguageConfig.findByCode(base);

    return language?.nameOf('en') ?? code;
  }

  String _resolveScriptCode({
    required String languageCode,
    required String text,
  }) {
    final normalized = languageCode.toLowerCase();

    // BCP-47 region/script hints take priority for Chinese.
    if (normalized.startsWith('zh')) {
      if (normalized.contains('hant') ||
          normalized.contains('-tw') ||
          normalized.contains('-hk') ||
          normalized.contains('-mo')) {
        return 'Hant';
      }

      return 'Hans';
    }

    final base = _baseLanguageCode(languageCode);
    final language = LanguageConfig.findByCode(base);

    if (language != null && language.scriptCodes.isNotEmpty) {
      return language.scriptCodes.first;
    }

    // Unicode fallback for a language not yet present in the language registry.
    for (final rune in text.runes) {
      if (rune >= 0x0400 && rune <= 0x052F) return 'Cyrl';
      if (rune >= 0x0600 && rune <= 0x06FF) return 'Arab';
      if (rune >= 0x0590 && rune <= 0x05FF) return 'Hebr';
      if (rune >= 0x0900 && rune <= 0x097F) return 'Deva';
      if (rune >= 0x0E00 && rune <= 0x0E7F) return 'Thai';
      if (rune >= 0x0E80 && rune <= 0x0EFF) return 'Laoo';
      if (rune >= 0x10A0 && rune <= 0x10FF) return 'Geor';
      if (rune >= 0x0530 && rune <= 0x058F) return 'Armn';
      if (rune >= 0xAC00 && rune <= 0xD7AF) return 'Hang';
      if (rune >= 0x3040 && rune <= 0x30FF) return 'Jpan';
      if (rune >= 0x4E00 && rune <= 0x9FFF) return 'Hani';
    }

    return 'Latn';
  }

  String _baseLanguageCode(String code) {
    return code
        .trim()
        .toLowerCase()
        .split(RegExp(r'[-_]'))
        .first;
  }
}
