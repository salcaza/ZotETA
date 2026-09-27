import 'package:flutter/material.dart';

import '../data/uci_classroom_catalog.dart';
import '../models/campus_destination.dart';

/// Searchable list of exact rooms from UCI Classroom Technologies.
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({required this.currentDestination, super.key});

  final CampusDestination currentDestination;

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
      const suggestedRooms = ['DBH 1100', 'ALP 1300', 'ICS 174', 'SSL 248'];
      return [for (final code in suggestedRooms) destinationByRoomCode(code)!];
    }

    return uciClassroomDestinations.where((destination) {
      final searchable = _normalize(
        '${destination.roomCode} ${destination.building.name}',
      );
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a classroom')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SearchBar(
                controller: _searchController,
                autoFocus: true,
                leading: const Icon(Icons.search),
                hintText: 'Try “DBH 1100” or “Donald Bren”',
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
                          ? 'Suggested classrooms'
                          : '${results.length} exact room results',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const Text('139 rooms · 29 buildings'),
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
                            destination.roomCode ==
                            widget.currentDestination.roomCode;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(destination.building.abbreviation),
                          ),
                          title: Text(
                            destination.roomCode,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${destination.building.name} · inferred level '
                            '${destination.inferredFloor}',
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, destination),
                        );
                      },
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              color: const Color(0xFFFFF4CF),
              child: const Text(
                'Room names are official. The map endpoint is the official '
                'building location; indoor walking is estimated separately.',
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
          'No general-assignment classroom matched. Try a building '
          'abbreviation, room number, or full building name.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
