import 'package:flutter/material.dart';

import '../data/uci_classroom_catalog.dart';
import '../models/campus_destination.dart';

/// Searchable list of UCI buildings and exact general-assignment rooms.
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({
    required this.currentDestination,
    this.selectionRequired = false,
    this.onSelected,
    super.key,
  });

  final CampusDestination? currentDestination;
  final bool selectionRequired;
  final Future<void> Function(CampusDestination destination)? onSelected;

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<CampusDestination> get _results {
    final query = _normalize(_query);
    if (query.isEmpty) {
      const suggestedBuildings = ['DBH', 'ALP', 'ICS', 'SSL'];
      return [
        for (final abbreviation in suggestedBuildings)
          uciBuildingDestinations.firstWhere(
            (destination) => destination.building.abbreviation == abbreviation,
          ),
      ];
    }

    return uciCampusDestinations.where((destination) {
      final searchable = _normalize(
        '${destination.roomCode ?? ''} ${destination.building.abbreviation} '
        '${destination.building.name}',
      );
      return searchable.contains(query);
    }).toList()..sort((a, b) {
      if (a.isClassroom != b.isClassroom) return a.isClassroom ? 1 : -1;
      return a.label.compareTo(b.label);
    });
  }

  Future<void> _select(CampusDestination destination) async {
    final callback = widget.onSelected;
    if (callback != null) {
      await callback(destination);
      return;
    }
    if (mounted) Navigator.pop(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.selectionRequired,
        title: const Text('Where are you going?'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SearchBar(
                controller: _searchController,
                autoFocus: true,
                leading: const Icon(Icons.search),
                hintText: 'Try “DBH”, “DBH 1100”, or “Donald Bren”',
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _query.isEmpty
                          ? 'Suggested buildings'
                          : '${results.length} building and room results',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const Text('29 buildings · 139 rooms'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: results.isEmpty
                  ? const _NoResults()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final destination = results[index];
                        final selected =
                            destination.storageKey ==
                            widget.currentDestination?.storageKey;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(destination.building.abbreviation),
                          ),
                          title: Text(
                            destination.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            destination.isClassroom
                                ? '${destination.building.name} · inferred level '
                                      '${destination.inferredFloor}'
                                : '${destination.building.name} · whole building',
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: () => _select(destination),
                        );
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              color: const Color(0xFFFFF4CF),
              child: const Text(
                'Choose a building for a quick destination or a classroom for '
                'an extra indoor walking allowance. Room names are official.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No building or general-assignment classroom matched. Try a building '
          'abbreviation, room number, or full building name.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
