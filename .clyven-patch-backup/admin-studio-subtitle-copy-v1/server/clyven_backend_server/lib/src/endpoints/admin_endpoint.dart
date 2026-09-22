import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

class AdminEndpoint extends Endpoint {
  @override
  Set<Scope> get requiredScopes => {Scope.admin};

  Future<bool> ping(Session session) async {
    return true;
  }

  Future<List<Video>> getVideosWithSubtitles(Session session) async {
    final tracks = await SubtitleTrack.db.find(session);

    if (tracks.isEmpty) {
      return [];
    }

    final videoIds = tracks.map((track) => track.videoId).toSet();

    return Video.db.find(
      session,
      where: (video) => video.id.inSet(videoIds),
      orderBy: (video) => video.createdAt,
      orderDescending: true,
    );
  }

  Future<List<SubtitleTrack>> getSubtitleTracks(
    Session session, {
    required int videoId,
  }) async {
    final tracks = await SubtitleTrack.db.find(
      session,
      where: (track) => track.videoId.equals(videoId),
      orderBy: (track) => track.createdAt,
    );

    tracks.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }

      return a.languageCode.compareTo(b.languageCode);
    });

    return tracks;
  }
}
