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
import 'package:serverpod/serverpod.dart' as _i1;
import 'video_feed_item.dart' as _i2;
import 'package:glyphora_backend_server/src/generated/protocol.dart' as _i3;

abstract class VideoFeedPage
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  VideoFeedPage._({
    required this.items,
    required this.hasMore,
  });

  factory VideoFeedPage({
    required List<_i2.VideoFeedItem> items,
    required bool hasMore,
  }) = _VideoFeedPageImpl;

  factory VideoFeedPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return VideoFeedPage(
      items: _i3.Protocol().deserialize<List<_i2.VideoFeedItem>>(
        jsonSerialization['items'],
      ),
      hasMore: _i1.BoolJsonExtension.fromJson(jsonSerialization['hasMore']),
    );
  }

  List<_i2.VideoFeedItem> items;

  bool hasMore;

  /// Returns a shallow copy of this [VideoFeedPage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  VideoFeedPage copyWith({
    List<_i2.VideoFeedItem>? items,
    bool? hasMore,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VideoFeedPage',
      'items': items.toJson(valueToJson: (v) => v.toJson()),
      'hasMore': hasMore,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VideoFeedPage',
      'items': items.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'hasMore': hasMore,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _VideoFeedPageImpl extends VideoFeedPage {
  _VideoFeedPageImpl({
    required List<_i2.VideoFeedItem> items,
    required bool hasMore,
  }) : super._(
         items: items,
         hasMore: hasMore,
       );

  /// Returns a shallow copy of this [VideoFeedPage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  VideoFeedPage copyWith({
    List<_i2.VideoFeedItem>? items,
    bool? hasMore,
  }) {
    return VideoFeedPage(
      items: items ?? this.items.map((e0) => e0.copyWith()).toList(),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
