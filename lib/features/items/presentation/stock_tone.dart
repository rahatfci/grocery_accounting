import '../../../core/widgets/status_tag.dart';
import '../logic/stock_status.dart';

/// Colour follows meaning: out and low are against the household, soon is a
/// warning, a healthy staple is in its favour.
Tone toneFor(StockStatus status) => switch (status) {
  StockStatus.out || StockStatus.low => Tone.negative,
  StockStatus.soon => Tone.warning,
  StockStatus.healthy => Tone.positive,
  StockStatus.untracked => Tone.neutral,
};
