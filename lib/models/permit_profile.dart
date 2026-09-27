/// The UCI parking permit families supported by ZotETA onboarding.
enum PermitType { s, p, r, e, mx, acc, none }

/// Resident permits are tied to a specific UCI housing community.
enum ResidentPermitType { rMc, rMe, rAv, rCvGrad, rOc }

/// American Campus Communities represented in the local user profile.
///
/// An ACC housing permit does not, by itself, grant UCI campus parking access.
enum AccCommunity {
  vistaDelCampo,
  vistaDelCampoNorte,
  caminoDelSol,
  puertaDelSol,
  plazaVerde,
  plazaVerdeTwo,
}

/// A user's locally stored parking selection.
///
/// This profile intentionally contains no UCInetID, license plate, home
/// address, or other identifying information. It is sufficient to evaluate
/// the prototype's permit rules without requiring an account or backend.
class PermitProfile {
  const PermitProfile({
    required this.type,
    this.zone,
    this.residentPermit,
    this.accCommunity,
  });

  /// The selected permit family.
  final PermitType type;

  /// The commuter zone for S and P permits; otherwise null.
  final int? zone;

  /// The housing-specific permit for R profiles; otherwise null.
  final ResidentPermitType? residentPermit;

  /// The user's ACC community when they selected an ACC-only profile.
  final AccCommunity? accCommunity;

  /// S and P permit zones that UCI currently offers.
  static const sZones = <int>[1, 2, 3, 4, 5, 6];
  static const pZones = <int>[1, 3, 4, 5, 6];

  /// Whether this combination contains every required conditional field.
  bool get isComplete => switch (type) {
    PermitType.s => zone != null && sZones.contains(zone),
    PermitType.p => zone != null && pZones.contains(zone),
    PermitType.r => residentPermit != null,
    PermitType.acc => accCommunity != null,
    PermitType.e || PermitType.mx || PermitType.none => true,
  };

  /// A compact label for headers and recommendation context.
  String get label => switch (type) {
    PermitType.s => 'S Zone $zone',
    PermitType.p => 'P Zone $zone',
    PermitType.r => residentPermit?.label ?? 'R Resident',
    PermitType.e => 'E Evening',
    PermitType.mx => 'MX Motorcycle',
    PermitType.acc => '${accCommunity?.label ?? 'ACC'} parking only',
    PermitType.none => 'No parking permit',
  };

  /// A stable value used to rebuild map state after a profile edit.
  String get cacheKey =>
      [type.name, zone, residentPermit?.name, accCommunity?.name].join(':');

  /// Converts this profile to JSON-compatible values for local storage.
  Map<String, Object?> toJson() => {
    'type': type.name,
    'zone': zone,
    'residentPermit': residentPermit?.name,
    'accCommunity': accCommunity?.name,
  };

  /// Restores and validates a profile previously produced by [toJson].
  static PermitProfile? fromJson(Map<String, Object?> json) {
    final type = PermitType.values.byNameOrNull(json['type'] as String?);
    if (type == null) return null;

    final residentPermit = ResidentPermitType.values.byNameOrNull(
      json['residentPermit'] as String?,
    );
    final accCommunity = AccCommunity.values.byNameOrNull(
      json['accCommunity'] as String?,
    );
    final profile = PermitProfile(
      type: type,
      zone: json['zone'] as int?,
      residentPermit: residentPermit,
      accCommunity: accCommunity,
    );
    return profile.isComplete ? profile : null;
  }
}

/// Safe enum lookup used when loading values written by an older app version.
extension _EnumLookup<T extends Enum> on Iterable<T> {
  T? byNameOrNull(String? name) {
    if (name == null) return null;
    for (final value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}

extension PermitTypeLabels on PermitType {
  String get title => switch (this) {
    PermitType.s => 'S — Zone Commuter',
    PermitType.p => 'P — Preferred Zone',
    PermitType.r => 'R — Resident',
    PermitType.e => 'E — Evening',
    PermitType.mx => 'MX — Motorcycle',
    PermitType.acc => 'ACC housing permit only',
    PermitType.none => 'No UCI parking permit',
  };

  String get description => switch (this) {
    PermitType.s => r'$16/day · $40/week · $81/month',
    PermitType.p => r'$20/day · $49/week · $101/month',
    PermitType.r => r'$20/day · $69/week · $150/month',
    PermitType.e => r'Evenings after 5 p.m. · $48/month',
    PermitType.mx => r'Motorcycle stalls only · $48/month',
    PermitType.acc => 'Home-community parking; no automatic campus access',
    PermitType.none => 'Use paid visitor, hourly, or day parking',
  };
}

extension ResidentPermitLabels on ResidentPermitType {
  String get label => switch (this) {
    ResidentPermitType.rMc => 'R-MC · Mesa Court',
    ResidentPermitType.rMe => 'R-ME · Middle Earth',
    ResidentPermitType.rAv => 'R-AV · Arroyo Vista',
    ResidentPermitType.rCvGrad => 'R-CVGRAD · Campus Village',
    ResidentPermitType.rOc => 'R-OC · Off-campus / approved ACC',
  };
}

extension AccCommunityLabels on AccCommunity {
  String get label => switch (this) {
    AccCommunity.vistaDelCampo => 'Vista del Campo',
    AccCommunity.vistaDelCampoNorte => 'Vista del Campo Norte',
    AccCommunity.caminoDelSol => 'Camino del Sol',
    AccCommunity.puertaDelSol => 'Puerta del Sol',
    AccCommunity.plazaVerde => 'Plaza Verde',
    AccCommunity.plazaVerdeTwo => 'Plaza Verde II',
  };
}
