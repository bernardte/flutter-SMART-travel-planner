// lib/core/utils/cached_tile_provider.dart
//
// Caches OpenStreetMap tiles to disk via CachedNetworkImageProvider so that
// tiles already seen are served instantly from the device cache instead of
// being re-downloaded on every screen open.
//
// No extra packages needed — cached_network_image (already in pubspec) brings
// flutter_cache_manager as a transitive dependency.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {'User-Agent': 'SmartTravelPlanner/1.0'},
    );
  }
}
