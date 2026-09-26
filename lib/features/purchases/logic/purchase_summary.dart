import 'package:equatable/equatable.dart';

import '../../items/logic/item_validation.dart';
import '../../receipts/logic/receipt_alias.dart';
import 'money.dart';
import 'purchase_draft.dart';

/// Where the receipt photo of a saved purchase stands.
enum SavedPhoto {
  /// The purchase had no photo.
  none,

  /// On its way to the bucket right now.
  uploading,

  /// In the bucket.
  uploaded,

  /// Queued on the phone, and goes up once there is signal.
  waiting,

  /// Could not be kept; the purchase was saved without it.
  notSaved,
}

/// What one save did, for the summary shown after it.
final class PurchaseSummary extends Equatable {
  const PurchaseSummary({
    required this.purchaseId,
    required this.total,
    required this.shopName,
    required this.payerName,
    required this.restocked,
    required this.created,
    required this.cleared,
    required this.learned,
    required this.spendOnly,
    required this.photo,
    this.photoProblem,
  });

  final String purchaseId;
  final double total;
  final String shopName;
  final String payerName;

  /// Items already in the pantry whose stock went up.
  final int restocked;

  /// Names of the items this purchase added to the pantry.
  final List<String> created;

  /// Shopping list entries the purchase ticked off.
  final int cleared;

  /// Receipt lines taught for next time, not counting ones already known.
  final int learned;

  /// Lines saved as spend only, because nobody matched them.
  final int spendOnly;

  final SavedPhoto photo;

  /// Why the photo was not kept, already worded for the member.
  final String? photoProblem;

  PurchaseSummary withPhoto(SavedPhoto photo, {String? problem}) =>
      PurchaseSummary(
        purchaseId: purchaseId,
        total: total,
        shopName: shopName,
        payerName: payerName,
        restocked: restocked,
        created: created,
        cleared: cleared,
        learned: learned,
        spendOnly: spendOnly,
        photo: photo,
        photoProblem: problem,
      );

  @override
  List<Object?> get props => [
    purchaseId,
    total,
    shopName,
    payerName,
    restocked,
    created,
    cleared,
    learned,
    spendOnly,
    photo,
    photoProblem,
  ];
}

/// The summary of saving [draft] as [purchaseId].
///
/// A line counts as learned when a member matched it on this purchase: one
/// an alias matched on its own was already known. Two lines with the same
/// wording teach one alias, so they count once.
PurchaseSummary summarizePurchase(
  PurchaseDraft draft, {
  required String purchaseId,
  required String payerName,
  required int cleared,
  required SavedPhoto photo,
  String? photoProblem,
}) {
  final targets = restockTargets(draft.lines);
  final taught = {
    for (final line in draft.lines)
      if (line.item != null && line.scannedText != null && !line.learned)
        normalizeReceiptText(line.scannedText ?? ''),
  }..remove('');

  return PurchaseSummary(
    purchaseId: purchaseId,
    total: parseDecimal(draft.totalText) ?? 0,
    shopName: draft.shopName.trim(),
    payerName: payerName,
    restocked: targets.where((target) => target.item.id.isNotEmpty).length,
    created: [
      for (final target in targets)
        if (target.item.id.isEmpty) target.item.name,
    ],
    cleared: cleared,
    learned: taught.length,
    spendOnly: draft.lines.where((line) => !line.isMatched).length,
    photo: photo,
    photoProblem: photoProblem,
  );
}

/// The line under `Purchase saved`: `40,80 € at Conad City, paid by Rahat`.
String savedHeadline(PurchaseSummary summary) =>
    '${formatEuro(summary.total)} at ${summary.shopName}, '
    'paid by ${summary.payerName}';

/// What an outcome row is about, which picks its icon.
enum OutcomeKind {
  spend,
  restocked,
  created,
  cleared,
  learned,
  spendOnly,
  photo,
}

/// How an outcome's value reads: plain, done, needs signal, or lost.
enum OutcomeTone { neutral, positive, warning, negative }

/// One row of the saved summary.
final class Outcome extends Equatable {
  const Outcome({
    required this.kind,
    required this.label,
    required this.value,
    this.tone = OutcomeTone.neutral,
    this.detail,
  });

  final OutcomeKind kind;
  final String label;
  final String value;
  final OutcomeTone tone;

  /// A line under the label, when the value needs explaining.
  final String? detail;

  @override
  List<Object?> get props => [kind, label, value, tone, detail];
}

/// The rows the saved summary shows for [summary]. The spend is always
/// there; everything else only when the save did it.
List<Outcome> outcomesOf(PurchaseSummary summary) {
  final created = summary.created;
  return [
    Outcome(
      kind: OutcomeKind.spend,
      label: 'Spend recorded',
      value: formatEuro(summary.total),
    ),
    if (summary.restocked > 0)
      Outcome(
        kind: OutcomeKind.restocked,
        label: 'Pantry restocked',
        value: _count(summary.restocked, 'item'),
      ),
    if (created.isNotEmpty)
      Outcome(
        kind: OutcomeKind.created,
        label: created.length == 1 ? 'New pantry item' : 'New pantry items',
        value: created.length == 1
            ? created.single
            : _count(created.length, 'item'),
      ),
    if (summary.cleared > 0)
      Outcome(
        kind: OutcomeKind.cleared,
        label: 'Ticked off the list',
        value: _count(summary.cleared, 'entry', 'entries'),
      ),
    if (summary.learned > 0)
      Outcome(
        kind: OutcomeKind.learned,
        label: 'Learned for next time',
        value: _count(summary.learned, 'receipt line'),
      ),
    if (summary.spendOnly > 0)
      Outcome(
        kind: OutcomeKind.spendOnly,
        label: 'Saved as spend only',
        value: _count(summary.spendOnly, 'line'),
        tone: OutcomeTone.negative,
      ),
    ...switch (summary.photo) {
      SavedPhoto.none => const <Outcome>[],
      SavedPhoto.uploading => const [
        Outcome(
          kind: OutcomeKind.photo,
          label: 'Receipt photo',
          value: 'Uploading',
        ),
      ],
      SavedPhoto.uploaded => const [
        Outcome(
          kind: OutcomeKind.photo,
          label: 'Receipt photo',
          value: 'Uploaded',
          tone: OutcomeTone.positive,
        ),
      ],
      SavedPhoto.waiting => const [
        Outcome(
          kind: OutcomeKind.photo,
          label: 'Receipt photo',
          value: 'Uploads when online',
          tone: OutcomeTone.warning,
        ),
      ],
      SavedPhoto.notSaved => [
        Outcome(
          kind: OutcomeKind.photo,
          label: 'Receipt photo',
          value: 'Not saved',
          tone: OutcomeTone.negative,
          detail: summary.photoProblem,
        ),
      ],
    },
  ];
}

String _count(int count, String singular, [String? plural]) =>
    count == 1 ? '1 $singular' : '$count ${plural ?? '${singular}s'}';
