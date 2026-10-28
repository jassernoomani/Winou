import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'models.dart';

final lostReportProvider = FutureProvider.autoDispose.family<LostReport, String>(
  (ref, id) => ref.watch(apiProvider).lostReport(id),
);

final sightingProvider = FutureProvider.autoDispose.family<Sighting, String>(
  (ref, id) => ref.watch(apiProvider).sighting(id),
);

final myLostReportsProvider = FutureProvider.autoDispose<List<LostReport>>(
  (ref) => ref.watch(apiProvider).myLostReports(),
);

final mySightingsProvider = FutureProvider.autoDispose<List<Sighting>>((ref) => ref.watch(apiProvider).mySightings());

final myMatchesProvider = FutureProvider.autoDispose<List<Match>>((ref) => ref.watch(apiProvider).myMatches());
