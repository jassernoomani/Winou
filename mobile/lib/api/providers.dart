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

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(apiProvider).conversations(),
);

/// The signed-in user: role and association name.
final meProvider = FutureProvider.autoDispose<User>((ref) => ref.watch(apiProvider).me());

final myAssociationRequestProvider = FutureProvider.autoDispose<AssociationRequest?>(
  (ref) => ref.watch(apiProvider).myAssociationRequest(),
);

final pendingAssociationRequestsProvider = FutureProvider.autoDispose<List<AssociationRequest>>(
  (ref) => ref.watch(apiProvider).pendingAssociationRequests(),
);

final hiddenContentProvider = FutureProvider.autoDispose<List<HiddenItem>>(
  (ref) => ref.watch(apiProvider).hiddenContent(),
);

final conversationProvider = FutureProvider.autoDispose.family<Conversation, String>(
  (ref, id) => ref.watch(apiProvider).conversation(id),
);

/// Admin search: (query, banned only).
final adminUsersProvider = FutureProvider.autoDispose.family<List<AdminUser>, (String, bool)>(
  (ref, filter) => ref.watch(apiProvider).adminUsers(query: filter.$1, bannedOnly: filter.$2),
);

final adminUserProvider = FutureProvider.autoDispose.family<AdminUserDetail, String>(
  (ref, id) => ref.watch(apiProvider).adminUser(id),
);
