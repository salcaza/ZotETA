import 'package:flutter_test/flutter_test.dart';
import 'package:zot_eta/data/sample_parking_data.dart';
import 'package:zot_eta/data/uci_classroom_catalog.dart';
import 'package:zot_eta/services/destination_walk_estimator.dart';

void main() {
  test('catalog contains the researched building and exact-room coverage', () {
    expect(uciClassroomBuildings, hasLength(29));
    expect(uciClassroomDestinations, hasLength(139));
    expect(
      uciClassroomDestinations
          .map((destination) => destination.roomCode)
          .toSet(),
      hasLength(139),
    );
  });

  test('resolves an exact room with its official building endpoint', () {
    final destination = destinationByRoomCode('DBH 1427')!;

    expect(destination.building.name, 'Donald Bren Hall');
    expect(destination.building.mapLocationId, 1117348);
    expect(destination.inferredFloor, 1);
    expect(
      destination.officialClassroomUrl,
      'https://classrooms.uci.edu/classrooms/dbh/dbh-1427',
    );
  });

  test('floor inference handles three- and four-digit room conventions', () {
    expect(destinationByRoomCode('SSL 248')!.inferredFloor, 2);
    expect(destinationByRoomCode('ALP 3600')!.inferredFloor, 3);
  });

  test('walking estimate changes when the classroom destination changes', () {
    const estimator = DestinationWalkEstimator();
    final ssps = sampleParkingOptions.firstWhere(
      (option) => option.id == 'ssps',
    );
    final socialScience = destinationByRoomCode('SSL 248')!;
    final engineering = destinationByRoomCode('DBH 1100')!;

    expect(
      estimator.estimateMinutes(ssps, socialScience),
      lessThan(estimator.estimateMinutes(ssps, engineering)),
    );
  });
}
