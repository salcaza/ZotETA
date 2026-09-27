import '../models/parking_observation.dart';
import '../models/parking_option.dart';

/// Search-time result after combining historical seed data and fresh reports.
class LiveParkingPrediction {
  const LiveParkingPrediction({
    required this.typicalMinutes,
    required this.cautiousMinutes,
    required this.freshReportCount,
    required this.summary,
  });

  final int typicalMinutes;
  final int cautiousMinutes;
  final int freshReportCount;
  final String summary;

  bool get isLiveAdjusted => freshReportCount > 0;
  String get confidenceLabel => freshReportCount >= 4
      ? 'higher confidence'
      : freshReportCount >= 2
      ? 'medium confidence'
      : 'early estimate';
}

/// Transparent prototype model for a facility's current parking search time.
///
/// The seed median is first adjusted by time of day. Reports from the last
/// hour are then blended with a two-report prior, so one tap changes the ETA
/// immediately without allowing a single report to dominate it.
class LiveParkingEstimator {
  const LiveParkingEstimator();

  LiveParkingPrediction estimate({
    required ParkingOption option,
    required List<ParkingObservation> observations,
    required DateTime at,
  }) {
    final baselineFactor = _timeFactor(at);
    final baseline = (option.searchMedianMinutes * baselineFactor)
        .round()
        .clamp(1, 120);
    final cautiousBaseline = (option.searchP80Minutes * baselineFactor)
        .round()
        .clamp(baseline, 120);

    var weightedMinutes = baseline * 2.0;
    var totalWeight = 2.0;
    var freshCount = 0;
    for (final observation in observations) {
      if (observation.facilityId != option.id) continue;
      final ageMinutes = at.difference(observation.reportedAt).inMinutes;
      if (ageMinutes < 0 || ageMinutes > 60) continue;

      freshCount++;
      final weight = ageMinutes <= 10
          ? 1.0
          : ageMinutes <= 30
          ? 0.6
          : 0.3;
      // A direct Parked report is evidence of near-term availability but is
      // not falsely represented as a measured zero-minute search.
      final reportedMinutes = observation.searchDurationMinutes ?? 1;
      weightedMinutes += reportedMinutes * weight;
      totalWeight += weight;
    }

    final typical = (weightedMinutes / totalWeight).round().clamp(1, 118);
    final cautious = cautiousBaseline.clamp(typical + 2, 120);
    final summary = freshCount == 0
        ? '${_timeLabel(at)} baseline · no fresh device reports'
        : '$freshCount fresh device report${freshCount == 1 ? '' : 's'} · '
              'live adjusted';

    return LiveParkingPrediction(
      typicalMinutes: typical,
      cautiousMinutes: cautious,
      freshReportCount: freshCount,
      summary: summary,
    );
  }

  double _timeFactor(DateTime at) {
    final weekend =
        at.weekday == DateTime.saturday || at.weekday == DateTime.sunday;
    if (weekend) return 0.35;
    final minuteOfDay = at.hour * 60 + at.minute;
    if (minuteOfDay >= 570 && minuteOfDay < 840) return 1.0;
    if (minuteOfDay >= 420 && minuteOfDay < 1020) return 0.70;
    return 0.45;
  }

  String _timeLabel(DateTime at) {
    final weekend =
        at.weekday == DateTime.saturday || at.weekday == DateTime.sunday;
    if (weekend) return 'Weekend';
    final minuteOfDay = at.hour * 60 + at.minute;
    if (minuteOfDay >= 570 && minuteOfDay < 840) return 'Peak-hour';
    if (minuteOfDay >= 420 && minuteOfDay < 1020) return 'Daytime';
    return 'Evening';
  }
}
