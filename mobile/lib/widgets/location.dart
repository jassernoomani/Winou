import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import 'common.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'tn.winou.winou';
const defaultCenter = LatLng(Config.defaultLat, Config.defaultLon);

/// OpenStreetMap tiles (their usage policy asks for an app identifier).
TileLayer osmTiles() => TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _userAgent);

/// OpenStreetMap requires visible attribution: a small (i) button that expands to the credit.
Widget osmAttribution() => const RichAttributionWidget(
  alignment: AttributionAlignment.bottomLeft,
  showFlutterMapAttribution: false,
  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
);

/// The phone's position, or null if location is off or the permission is refused.
Future<Position?> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
  } catch (_) {
    return null; // timeout or platform error: the user can pick the point on the map instead
  }
}

LatLng toLatLng(Position p) => LatLng(p.latitude, p.longitude);

/// A small, non-interactive map with one pin, or a circle when the position is approximate.
class LocationPreview extends StatelessWidget {
  const LocationPreview(this.point, {super.key, this.approximateRadiusM, this.height = 180});

  final LatLng point;
  final double? approximateRadiusM;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: approximateRadiusM != null ? 15 : 16,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            osmTiles(),
            if (approximateRadiusM != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: point,
                    radius: approximateRadiusM!,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: 0.2),
                    borderColor: color,
                    borderStrokeWidth: 2,
                  ),
                ],
              )
            else
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter, // the pin's tip sits on the point
                    child: Icon(Icons.location_on, color: color, size: 40),
                  ),
                ],
              ),
            osmAttribution(),
          ],
        ),
      ),
    );
  }
}

/// Full-screen map: tap to place the pin, confirm to return it.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  late LatLng? _picked = widget.initial;

  Future<void> _useMyLocation() async {
    final position = await currentPosition();
    if (position == null) return;
    setState(() => _picked = toLatLng(position));
    _map.move(_picked!, 17);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickLocationTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial ?? defaultCenter,
              initialZoom: 15,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              osmTiles(),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter, // the pin's tip sits on the point
                      child: Icon(Icons.location_on, size: 44, color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              osmAttribution(),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.pickLocationHint)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: null,
        onPressed: _useMyLocation,
        tooltip: l10n.myLocation,
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked),
            child: Text(l10n.confirmLocation),
          ),
        ),
      ),
    );
  }
}
