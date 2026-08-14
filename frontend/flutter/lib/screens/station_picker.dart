import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/terminal_theme.dart';

class StationPicker extends StatefulWidget {
  final List<Station> stations;
  const StationPicker({super.key, required this.stations});

  @override
  State<StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<StationPicker> {
  String _query = '';
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.stations
        .where((s) =>
            _showAll ||
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            s.code.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('SELECT STATION', style: Terminal.mono(15, color: Terminal.white, spacing: 2)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: Terminal.mono(16, color: Terminal.amber),
              decoration: InputDecoration(
                hintText: 'SEARCH STATION / CODE',
                hintStyle: Terminal.mono(14, color: Terminal.dim),
                prefixIcon: const Icon(Icons.search, color: Terminal.dim),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Terminal.hairline)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Terminal.amber, width: 2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} STOPS IN RANGE',
                style: Terminal.mono(11, color: Terminal.green, spacing: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Terminal.hairline),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return ListTile(
                    onTap: () => setState(() => _showAll = !_showAll),
                    title: Text(
                      _showAll ? '<< COLLAPSE TO MATCHES' : '<< SHOW ALL ${widget.stations.length} STOPS',
                      style: Terminal.mono(12, color: Terminal.cyan, spacing: 1.5),
                    ),
                  );
                }
                final s = filtered[i - 1];
                return ListTile(
                  onTap: () => Navigator.of(context).pop(s),
                  leading: Text(s.code, style: Terminal.mono(11, color: Terminal.amber, spacing: 1)),
                  title: Text(s.name.toUpperCase(), style: Terminal.mono(14, color: Terminal.white, weight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, color: Terminal.dim),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}