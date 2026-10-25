import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:makco/models/models.dart';
import 'package:makco/services/location.dart';
import 'package:makco/state/favourites.dart';
import 'package:makco/theme/madras_flow.dart';

Future<Station?> showStationPicker(
  BuildContext context,
  List<Station> stations, {
  String title = 'Choose a station',
}) {
  return showModalBottomSheet<Station>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StationPickerSheet(stations: stations, title: title),
  );
}

class _StationPickerSheet extends ConsumerStatefulWidget {
  final List<Station> stations;
  final String title;

  const _StationPickerSheet({required this.stations, required this.title});

  @override
  ConsumerState<_StationPickerSheet> createState() =>
      _StationPickerSheetState();
}

class _StationPickerSheetState extends ConsumerState<_StationPickerSheet> {
  final _search = TextEditingController();
  String _query = '';
  bool _favouritesOnly = false;
  bool _nearMe = false;
  bool _locating = false;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  double? _distance(Station station) {
    final pos = _position;
    if (pos == null || station.lat == null || station.lon == null) return null;
    return distanceKm(pos.latitude, pos.longitude, station.lat!, station.lon!);
  }

  List<Station> get _filtered {
    final q = _query.trim().toLowerCase();
    final favourites = ref.read(favouritesProvider);
    var list = widget.stations;
    if (q.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.code.toLowerCase().contains(q),
          )
          .toList();
    } else if (_favouritesOnly) {
      list = list.where((s) => favourites.contains(s.code)).toList();
    }
    if (_nearMe && _position != null && q.isEmpty) {
      list = [...list]
        ..sort((a, b) {
          final da = _distance(a);
          final db = _distance(b);
          if (da == null && db == null) return a.name.compareTo(b.name);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    }
    return list;
  }

  Future<void> _toggleNearMe() async {
    if (_nearMe) {
      setState(() => _nearMe = false);
      return;
    }
    setState(() => _locating = true);
    final position = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (position != null) {
        _position = position;
        _nearMe = true;
      }
    });
    if (position == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Location is unavailable. Enable it or search by name.',
              style: Mf.body(14, color: Mf.surface),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouritesProvider);
    final filtered = _filtered;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Mf.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Mf.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(widget.title, style: Mf.display(24)),
              const SizedBox(height: 4),
              Text(
                '${filtered.length} of ${widget.stations.length} metro stations',
                style: Mf.body(14, color: Mf.inkMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                style: Mf.body(16, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search by name or code',
                  hintStyle: Mf.body(15, color: Mf.inkFaint),
                  prefixIcon: const Icon(Icons.search_rounded, color: Mf.teal),
                  filled: true,
                  fillColor: Mf.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Mf.amber, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChoiceChip(
                      label: 'All',
                      selected: !_favouritesOnly,
                      onTap: () => setState(() => _favouritesOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceChip(
                      label: 'Favourites (${favourites.length})',
                      selected: _favouritesOnly,
                      onTap: () => setState(() => _favouritesOnly = true),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceChip(
                      label: _locating ? 'Locating…' : 'Near me',
                      icon: _nearMe
                          ? Icons.near_me_rounded
                          : Icons.place_outlined,
                      selected: _nearMe,
                      onTap: _locating ? null : _toggleNearMe,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: Mf.inkFaint,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _favouritesOnly && _query.isEmpty
                                  ? 'No favourites yet. Tap a star to save a station.'
                                  : 'No stations match “$_query”',
                              textAlign: TextAlign.center,
                              style: Mf.body(14, color: Mf.inkMuted),
                            ),
                          ],
                        ),
                      )
                    : Material(
                        color: Colors.transparent,
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: Mf.hairline),
                          itemBuilder: (context, index) {
                            final station = filtered[index];
                            final saved = favourites.contains(station.code);
                            final distance = _distance(station);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              onTap: () => Navigator.of(context).pop(station),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Mf.tealSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_subway_rounded,
                                  size: 18,
                                  color: Mf.teal,
                                ),
                              ),
                              title: Text(
                                station.name,
                                style: Mf.body(16, weight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                distance == null
                                    ? station.code
                                    : '${station.code} · ${distance.toStringAsFixed(1)} km',
                                style: Mf.overline(
                                  color: Mf.inkFaint,
                                ).copyWith(letterSpacing: 0.6),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: saved
                                        ? 'Remove from favourites'
                                        : 'Save to favourites',
                                    icon: Icon(
                                      saved
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: saved ? Mf.amber : Mf.inkFaint,
                                    ),
                                    onPressed: () => ref
                                        .read(favouritesProvider.notifier)
                                        .toggle(station.code),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Mf.inkFaint,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Mf.teal : Mf.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Mf.teal : Mf.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Mf.surface : Mf.inkMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Mf.body(
                  13,
                  color: selected ? Mf.surface : Mf.inkMuted,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
