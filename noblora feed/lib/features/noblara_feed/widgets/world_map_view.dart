import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// WorldMapView — Real interactive world map for Noblara
// ---------------------------------------------------------------------------
//
// Bundled Natural Earth 110m country polygons (slimmed: ~180 KB).
// Equirectangular projection, drawn with CustomPaint, hit-tested via
// ray-casting point-in-polygon. Pinch-zoomable via InteractiveViewer.
//
// Self-contained — no circular import with mood_map_screen.dart.
// Caller passes:
//   * coloredCountries: { canonical_name → fill color } (data-bearing only)
//   * onCountryTap: callback with the canonical country name (data or not)
//
// Country-name normalization is exposed for the parent so both sides match
// regardless of the spelling stored in posts.country_code.
// ---------------------------------------------------------------------------

/// Normalize a country name so post-stored names and GeoJSON canonical names
/// can be matched. Returns lowercased canonical key.
String normalizeCountryName(String name) {
  final lower = name.trim().toLowerCase();
  switch (lower) {
    case 'usa':
    case 'us':
    case 'united states':
    case 'united states of america':
      return 'united states of america';
    case 'uk':
    case 'great britain':
    case 'united kingdom':
    case 'united kingdom of great britain and northern ireland':
      return 'united kingdom';
    case 'türkiye':
    case 'turkiye':
    case 'turkey':
      return 'turkey';
    case 'russia':
    case 'russian federation':
      return 'russia';
    case 'south korea':
    case 'republic of korea':
    case 'korea, south':
      return 'south korea';
    case 'north korea':
    case "democratic people's republic of korea":
    case 'korea, north':
      return 'north korea';
    case 'czech republic':
    case 'czechia':
      return 'czechia';
    case 'ivory coast':
    case "côte d'ivoire":
    case "cote d'ivoire":
      return "côte d'ivoire";
    default:
      return lower;
  }
}

// ---------------------------------------------------------------------------
// Parsed geo data
// ---------------------------------------------------------------------------

class GeoCountry {
  final String name;
  final String? iso;
  // [polygon-ring][point-index] => [lon, lat]
  final List<List<List<double>>> rings;
  final double minLon, maxLon, minLat, maxLat;

  GeoCountry({
    required this.name,
    required this.iso,
    required this.rings,
    required this.minLon,
    required this.maxLon,
    required this.minLat,
    required this.maxLat,
  });
}

class WorldGeoData {
  final List<GeoCountry> countries;
  WorldGeoData(this.countries);

  static WorldGeoData? _cached;

  static Future<WorldGeoData> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle
        .loadString('assets/data/world_countries.geojson');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;
    final countries = <GeoCountry>[];
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>;
      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;
      final name = (props['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final iso = props['iso'] as String?;
      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List;
      final rings = <List<List<double>>>[];
      double minLon = 180, maxLon = -180, minLat = 90, maxLat = -90;

      List<List<double>> readRing(List ring) {
        final out = <List<double>>[];
        for (final pt in ring) {
          final lon = (pt[0] as num).toDouble();
          final lat = (pt[1] as num).toDouble();
          out.add([lon, lat]);
          if (lon < minLon) minLon = lon;
          if (lon > maxLon) maxLon = lon;
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
        }
        return out;
      }

      if (type == 'Polygon') {
        for (final ring in coords) {
          rings.add(readRing(ring as List));
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          for (final ring in poly as List) {
            rings.add(readRing(ring as List));
          }
        }
      }
      if (rings.isEmpty) continue;

      countries.add(GeoCountry(
        name: name,
        iso: iso,
        rings: rings,
        minLon: minLon,
        maxLon: maxLon,
        minLat: minLat,
        maxLat: maxLat,
      ));
    }
    _cached = WorldGeoData(countries);
    return _cached!;
  }
}

// ---------------------------------------------------------------------------
// WorldMapView widget
// ---------------------------------------------------------------------------

class WorldMapView extends StatefulWidget {
  /// Map keyed by **canonical** country name (e.g. 'Turkey') to fill color.
  /// Use [normalizeCountryName] for matching when building this map.
  final Map<String, Color> coloredCountries;

  /// Called with the canonical GeoJSON country name when a country is tapped.
  /// Always invoked, even for countries with no data — the parent decides
  /// how to render the empty case.
  final void Function(String countryName) onCountryTap;

  const WorldMapView({
    super.key,
    required this.coloredCountries,
    required this.onCountryTap,
  });

  @override
  State<WorldMapView> createState() => _WorldMapViewState();
}

class _WorldMapViewState extends State<WorldMapView> {
  WorldGeoData? _geo;
  String? _selectedName;

  // Cached projected paths — rebuilt only when widget size changes.
  final Map<String, Path> _pathCache = {};
  Size _cachedSize = Size.zero;
  double _mapW = 0, _mapH = 0, _offsetX = 0, _offsetY = 0;

  // For repaint coalescing
  Map<String, Color>? _normalizedColored;

  // InteractiveViewer transform — used so tap coords map back to map coords
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    WorldGeoData.load().then((g) {
      if (mounted) setState(() => _geo = g);
    });
  }

  @override
  void didUpdateWidget(covariant WorldMapView old) {
    super.didUpdateWidget(old);
    if (old.coloredCountries != widget.coloredCountries) {
      _normalizedColored = null;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Map<String, Color> _normalized() {
    final cached = _normalizedColored;
    if (cached != null) return cached;
    final m = <String, Color>{};
    widget.coloredCountries.forEach((name, color) {
      m[normalizeCountryName(name)] = color;
    });
    _normalizedColored = m;
    return m;
  }

  Offset _project(double lon, double lat) {
    final x = _offsetX + ((lon + 180) / 360) * _mapW;
    final y = _offsetY + ((90 - lat) / 180) * _mapH;
    return Offset(x, y);
  }

  void _rebuildLayoutAndPaths(Size size) {
    final geo = _geo;
    if (geo == null) return;
    if (_cachedSize == size && _pathCache.isNotEmpty) return;

    final w = size.width;
    final h = size.height;
    const aspect = 2.0; // 360° / 180°
    if (w / h > aspect) {
      _mapH = h;
      _mapW = h * aspect;
    } else {
      _mapW = w;
      _mapH = w / aspect;
    }
    _offsetX = (w - _mapW) / 2;
    _offsetY = (h - _mapH) / 2;

    _pathCache.clear();
    for (final c in geo.countries) {
      final path = Path();
      for (final ring in c.rings) {
        if (ring.isEmpty) continue;
        final p0 = _project(ring[0][0], ring[0][1]);
        path.moveTo(p0.dx, p0.dy);
        for (int i = 1; i < ring.length; i++) {
          final p = _project(ring[i][0], ring[i][1]);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
      _pathCache[c.name] = path;
    }
    _cachedSize = size;
  }

  void _handleTap(Offset localPos) {
    final geo = _geo;
    if (geo == null) return;

    // Account for InteractiveViewer's current transform: convert from the
    // visible viewport position to the underlying scene (map) coordinate.
    final scene = _transform.toScene(localPos);

    // Convert scene point → lon/lat
    final localX = scene.dx - _offsetX;
    final localY = scene.dy - _offsetY;
    if (localX < 0 || localX > _mapW || localY < 0 || localY > _mapH) return;
    final lon = (localX / _mapW) * 360 - 180;
    final lat = 90 - (localY / _mapH) * 180;

    GeoCountry? hit;
    for (final c in geo.countries) {
      // Cheap bbox reject
      if (lon < c.minLon - 0.5 ||
          lon > c.maxLon + 0.5 ||
          lat < c.minLat - 0.5 ||
          lat > c.maxLat + 0.5) {
        continue;
      }
      for (final ring in c.rings) {
        if (_pointInRing(lon, lat, ring)) {
          hit = c;
          break;
        }
      }
      if (hit != null) break;
    }

    if (hit == null) return;
    setState(() => _selectedName = hit!.name);
    widget.onCountryTap(hit.name);
  }

  bool _pointInRing(double lon, double lat, List<List<double>> ring) {
    bool inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i][0];
      final yi = ring[i][1];
      final xj = ring[j][0];
      final yj = ring[j][1];
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / ((yj - yi) + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    if (_geo == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.emerald600),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _rebuildLayoutAndPaths(size);
        return InteractiveViewer(
          transformationController: _transform,
          minScale: 1.0,
          maxScale: 4.0,
          panEnabled: true,
          scaleEnabled: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _handleTap(d.localPosition),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                painter: _WorldMapPainter(
                  geo: _geo!,
                  pathCache: _pathCache,
                  colored: _normalized(),
                  selectedName: _selectedName,
                  oceanRect: Rect.fromLTWH(_offsetX, _offsetY, _mapW, _mapH),
                  projectFn: _project,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

typedef _Project = Offset Function(double lon, double lat);

class _WorldMapPainter extends CustomPainter {
  final WorldGeoData geo;
  final Map<String, Path> pathCache;
  final Map<String, Color> colored; // normalized
  final String? selectedName;
  final Rect oceanRect;
  final _Project projectFn;

  _WorldMapPainter({
    required this.geo,
    required this.pathCache,
    required this.colored,
    required this.selectedName,
    required this.oceanRect,
    required this.projectFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ocean background — dark gradient
    final ocean = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF101816),
          Color(0xFF0A100E),
        ],
      ).createShader(oceanRect);
    canvas.drawRect(oceanRect, ocean);

    // Subtle graticule
    final grid = Paint()
      ..color = AppColors.nobBorder.withValues(alpha: 0.18)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (int lon = -180; lon <= 180; lon += 30) {
      canvas.drawLine(
        projectFn(lon.toDouble(), 85),
        projectFn(lon.toDouble(), -85),
        grid,
      );
    }
    for (int lat = -60; lat <= 60; lat += 30) {
      canvas.drawLine(
        projectFn(-180, lat.toDouble()),
        projectFn(180, lat.toDouble()),
        grid,
      );
    }
    // Equator slightly brighter
    final equator = Paint()
      ..color = AppColors.emerald600.withValues(alpha: 0.10)
      ..strokeWidth = 0.6;
    canvas.drawLine(projectFn(-180, 0), projectFn(180, 0), equator);

    // Countries
    final dimFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF192722);
    final dimStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.nobBorder.withValues(alpha: 0.55);

    for (final c in geo.countries) {
      final path = pathCache[c.name];
      if (path == null) continue;
      final norm = normalizeCountryName(c.name);
      final color = colored[norm];
      final isSelected = selectedName == c.name;

      if (color != null) {
        // Has data
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: isSelected ? 0.82 : 0.58);
        canvas.drawPath(path, fill);

        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 1.6 : 0.7
          ..color = color.withValues(alpha: isSelected ? 1.0 : 0.85);
        canvas.drawPath(path, stroke);

        if (isSelected) {
          final glow = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = color.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawPath(path, glow);
        }
      } else {
        // No data — dim landmass
        canvas.drawPath(path, dimFill);
        canvas.drawPath(path, dimStroke);
        if (isSelected) {
          final hoverStroke = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = AppColors.emerald350.withValues(alpha: 0.7);
          canvas.drawPath(path, hoverStroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter old) {
    return old.selectedName != selectedName ||
        !identical(old.colored, colored) ||
        old.oceanRect != oceanRect ||
        !identical(old.pathCache, pathCache);
  }
}
