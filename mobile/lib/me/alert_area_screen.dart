import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../auth/auth_controller.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

/// "Alerts near me": a place, how far around it, and what to hear about there.
class AlertAreaScreen extends ConsumerStatefulWidget {
  const AlertAreaScreen({super.key});

  @override
  ConsumerState<AlertAreaScreen> createState() => _AlertAreaScreenState();
}

class _AlertAreaScreenState extends ConsumerState<AlertAreaScreen> {
  LatLng? _center;
  double _radiusKm = 3;
  bool _lost = true;
  bool _help = true;
  bool _active = false; // an area is saved on the server
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final area = await ref.read(apiProvider).alertArea();
      if (area != null) {
        _center = area.location;
        _radiusKm = area.radiusKm;
        _lost = area.lost;
        _help = area.help;
        _active = true;
      } else {
        final position = await currentPosition(); // a first area around where the user is
        _center = position == null ? const LatLng(Config.defaultLat, Config.defaultLon) : toLatLng(position);
      }
    } catch (e) {
      if (mounted) showError(context, e);
      _center ??= const LatLng(Config.defaultLat, Config.defaultLon);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPlace() async {
    final picked = await context.push<LatLng>('/pick-location', extra: _center);
    if (picked != null) setState(() => _center = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).setAlertArea(location: _center!, radiusKm: _radiusKm, lost: _lost, help: _help);
      ref.invalidate(alertAreaProvider);
      if (!mounted) return;
      setState(() => _active = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.alertsSaved)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).clearAlertArea();
      ref.invalidate(alertAreaProvider);
      if (mounted) setState(() => _active = false);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertsNearMe)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                FadeSlideIn(
                  child: Text(l10n.alertsIntro, style: TextStyle(color: tokens.muted, height: 1.4)),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: _AreaMap(center: _center!, radiusKm: _radiusKm),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _pickPlace,
                    icon: const Icon(LucideIcons.mapPin, size: 18),
                    label: Text(l10n.changePlace),
                  ),
                ),
                FadeSlideIn(
                  index: 2,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(l10n.alertRadius, style: theme.textTheme.titleMedium)),
                              Text(l10n.kmRadius(_radiusKm.round()), style: theme.textTheme.titleMedium),
                            ],
                          ),
                          Slider(
                            value: _radiusKm,
                            min: 1,
                            max: 25,
                            divisions: 24,
                            label: '${_radiusKm.round()} km',
                            onChanged: (value) => setState(() => _radiusKm = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 3,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(LucideIcons.megaphone),
                          title: Text(l10n.alertLostPets),
                          subtitle: Text(l10n.alertLostPetsHelp),
                          value: _lost,
                          onChanged: (value) => setState(() => _lost = value),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(LucideIcons.heartPulse),
                          title: Text(l10n.alertAnimalsInNeed),
                          subtitle: Text(l10n.alertAnimalsInNeedHelp),
                          value: _help,
                          onChanged: (value) => setState(() => _help = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy || !(_lost || _help) ? null : _save,
                  icon: const Icon(LucideIcons.bellRing),
                  label: Text(_active ? l10n.saveAlerts : l10n.turnOnAlerts),
                ),
                if (_active) TextButton(onPressed: _busy ? null : _turnOff, child: Text(l10n.turnOffAlerts)),
              ],
            ),
    );
  }
}

/// The watched circle, the map zoomed to show all of it.
class _AreaMap extends StatelessWidget {
  const _AreaMap({required this.center, required this.radiusKm});

  final LatLng center;
  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    final color = Brand.blue;
    final dLat = radiusKm / 111.0;
    final dLon = radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));
    final bounds = LatLngBounds(
      LatLng(center.latitude - dLat, center.longitude - dLon),
      LatLng(center.latitude + dLat, center.longitude + dLon),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          key: ValueKey((center, radiusKm.round())), // fit again when the area changes
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(16)),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            osmTiles(context),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: radiusKm * 1000,
                  useRadiusInMeter: true,
                  color: color.withValues(alpha: 0.18),
                  borderColor: color,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 36,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on, color: color, size: 36),
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

/// "5 km · lost pets, animals in need", or "Off": for the Settings row.
String alertAreaSummary(BuildContext context, AlertArea? area) {
  final l10n = context.l10n;
  if (area == null) return l10n.alertsOff;
  return [
    l10n.kmRadius(area.radiusKm.round()),
    if (area.lost) l10n.alertLostPets,
    if (area.help) l10n.alertAnimalsInNeed,
  ].join(' · ');
}
