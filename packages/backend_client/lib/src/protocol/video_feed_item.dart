/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'video.dart' as _i2;
import 'package:glyphora_backend_client/src/protocol/protocol.dart' as _i3;

abstract class VideoFeedItem implements _i1.SerializableModel {
  VideoFeedItem._({
    required this.video,
    this.coverUrl,
  });

  factory VideoFeedItem({
    required _i2.Video video,
    String? coverUrl,
  }) = _VideoFeedItemImpl;

  factory VideoFeedItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoFeedItem(
      video: _i3.Protocol().deserialize<_i2.Video>(jsonSerialization['video']),
      coverUrl: jsonSerialization['coverUrl'] as String?,
    );
  }

  _i2.Video video;

  String? coverUrl;

  /// Returns a shallow copy of this [VideoFeedItem]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoFeedItem copyWith({
    _i2.Video? video,
    String? coverUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoFeedItem',
      'video': video.toJson(),
      if (coverUrl != null) 'coverUrl': coverUrl,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VideoFeedItemImpl extends VideoFeedItem {
  _VideoFeedItemImpl({
    required _i2.Video video,
    String? coverUrl,
  }) : super._(
         video: video,
         coverUrl: coverUrl,
       );

  /// Returns a shallow copy of this [VideoFeedItem]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoFeedItem copyWith({
    _i2.Video? video,
    Object? coverUrl = _Undefined,
  }) {
    return VideoFeedItem(
      video: video ?? this.video.copyWith(),
      coverUrl: coverUrl is String? ? coverUrl : this.coverUrl,
    );
  }
}
