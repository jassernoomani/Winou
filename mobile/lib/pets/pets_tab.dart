import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../api/providers.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/common.dart';

/// "My pets" on the Me tab: each pet ready to be marked lost in one step, and a way to add one.
class PetsTab extends ConsumerWidget {
  const PetsTab({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String location, {Object? extra}) async {
    await pushChain(context, location, extra: extra);
    ref
      ..invalidate(myPetsProvider)
      ..invalidate(myLostReportsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(myPetsProvider)) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () => ref.refresh(myPetsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (value.isEmpty)
              FadeSlideIn(
                child: EmptyState(icon: LucideIcons.pawPrint, text: l10n.noPetsYet),
              ),
            for (final (i, pet) in value.indexed)
              FadeSlideIn(
                index: i,
                child: _PetCard(
                  pet,
                  onEdit: () => _open(context, ref, '/pets/${pet.id}/edit', extra: pet),
                  onLost: () =>
                      _open(context, ref, pet.lost ? '/lost/${pet.openReportId}' : '/pets/${pet.id}/lost', extra: pet),
                ),
              ),
            const SizedBox(height: 8),
            FadeSlideIn(
              index: value.length,
              child: OutlinedButton.icon(
                onPressed: () => _open(context, ref, '/pets/new'),
                icon: const Icon(LucideIcons.plus),
                label: Text(l10n.addPet),
              ),
            ),
          ],
        ),
      ),
      AsyncError(:final error) => ErrorView(error: error, onRetry: () => ref.invalidate(myPetsProvider)),
      _ => const SkeletonList(picture: 76),
    };
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard(this.pet, {required this.onEdit, required this.onLost});

  final Pet pet;
  final VoidCallback onEdit;
  final VoidCallback onLost;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 12,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(dimension: 76, child: NetworkPhoto(pet.photos.firstOrNull?.url)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(pet.name, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [speciesLabel(l10n, pet.species), l10n.photosCount(pet.photos.length)].join(' · '),
                      style: TextStyle(color: context.tokens.muted, fontSize: 13),
                    ),
                    if (pet.lost)
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(l10n.statusOpen, tone: Tone.lost, icon: LucideIcons.search),
                          TextButton(onPressed: onLost, child: Text(l10n.seeReport)),
                        ],
                      )
                    else if (pet.photos.isEmpty)
                      Text(l10n.addPhotoToMarkLost, style: TextStyle(color: context.tokens.muted, fontSize: 12))
                    else ...[
                      if (pet.photos.length < 3)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            l10n.morePhotosHint,
                            style: const TextStyle(color: Brand.amber, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: onLost,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.tokens.tone(Tone.lost).$1,
                          foregroundColor: context.tokens.tone(Tone.lost).$2,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(LucideIcons.megaphone, size: 18),
                        label: Text(l10n.markLost),
                      ),
                    ],
                  ],
                ),
              ),
              const ForwardIcon(),
            ],
          ),
        ),
      ),
    );
  }
}
