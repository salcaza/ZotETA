import 'package:flutter/material.dart';

import '../models/permit_profile.dart';

/// First-launch and edit screen for the locally stored parking profile.
class PermitOnboardingScreen extends StatefulWidget {
  const PermitOnboardingScreen({
    required this.onSave,
    this.initialProfile,
    super.key,
  });

  /// Existing value when editing; null means this is first-launch onboarding.
  final PermitProfile? initialProfile;

  /// Persists a valid profile and returns to the parking planner.
  final Future<void> Function(PermitProfile profile) onSave;

  @override
  State<PermitOnboardingScreen> createState() => _PermitOnboardingScreenState();
}

class _PermitOnboardingScreenState extends State<PermitOnboardingScreen> {
  late PermitType _type;
  int? _zone;
  ResidentPermitType? _residentPermit;
  AccCommunity? _accCommunity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _type = profile?.type ?? PermitType.s;
    _zone = profile?.zone ?? 5;
    _residentPermit = profile?.residentPermit;
    _accCommunity = profile?.accCommunity;
  }

  List<int> get _availableZones =>
      _type == PermitType.p ? PermitProfile.pZones : PermitProfile.sZones;

  PermitProfile get _draft => PermitProfile(
    type: _type,
    zone: _type == PermitType.s || _type == PermitType.p ? _zone : null,
    residentPermit: _type == PermitType.r ? _residentPermit : null,
    accCommunity: _type == PermitType.acc ? _accCommunity : null,
  );

  void _selectType(PermitType type) {
    setState(() {
      _type = type;
      if (type == PermitType.s && !PermitProfile.sZones.contains(_zone)) {
        _zone = PermitProfile.sZones.first;
      }
      if (type == PermitType.p && !PermitProfile.pZones.contains(_zone)) {
        _zone = PermitProfile.pZones.first;
      }
    });
  }

  Future<void> _save() async {
    final profile = _draft;
    if (!profile.isComplete || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(profile);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit parking profile' : 'Welcome to ZotETA'),
        automaticallyImplyLeading: editing,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              editing
                  ? 'Update the permit ZotETA uses for recommendations.'
                  : 'Tell ZotETA what parking access you have.',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'This choice stays on your phone. No account, UCInetID, license '
              'plate, or location history is required.',
            ),
            const SizedBox(height: 20),
            Text(
              'Permit type',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            RadioGroup<PermitType>(
              groupValue: _type,
              onChanged: (value) {
                if (value != null) _selectType(value);
              },
              child: Column(
                children: [
                  for (final type in PermitType.values)
                    Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      clipBehavior: Clip.antiAlias,
                      child: RadioListTile<PermitType>(
                        value: type,
                        title: Text(type.title),
                        subtitle: Text(type.description),
                      ),
                    ),
                ],
              ),
            ),
            if (_type == PermitType.s || _type == PermitType.p) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _zone,
                decoration: const InputDecoration(
                  labelText: 'Assigned zone',
                  border: OutlineInputBorder(),
                  helperText: 'Use the zone shown on your permit.',
                ),
                items: [
                  for (final zone in _availableZones)
                    DropdownMenuItem(value: zone, child: Text('Zone $zone')),
                ],
                onChanged: (value) => setState(() => _zone = value),
              ),
            ],
            if (_type == PermitType.r) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<ResidentPermitType>(
                initialValue: _residentPermit,
                decoration: const InputDecoration(
                  labelText: 'Resident permit',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final permit in ResidentPermitType.values)
                    DropdownMenuItem(value: permit, child: Text(permit.label)),
                ],
                onChanged: (value) => setState(() => _residentPermit = value),
              ),
            ],
            if (_type == PermitType.acc) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<AccCommunity>(
                initialValue: _accCommunity,
                decoration: const InputDecoration(
                  labelText: 'ACC community',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final community in AccCommunity.values)
                    DropdownMenuItem(
                      value: community,
                      child: Text(community.label),
                    ),
                ],
                onChanged: (value) => setState(() => _accCommunity = value),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4CF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Always follow posted signs. Reserved spaces, closures, and '
                '24-hour restrictions override ZotETA. Holiday rules are not '
                'included yet. Prices and rules researched September 2026.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _draft.isComplete && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(_saving ? 'Saving…' : 'Continue to parking'),
            ),
          ],
        ),
      ),
    );
  }
}
