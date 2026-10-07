import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

/// All demo monetary values use USD, without currency conversion.
abstract final class ClinicFormatters {
  static final _money = NumberFormat.currency(
    locale: 'en_US',
    name: 'USD',
    symbol: 'USD ',
    decimalDigits: 2,
  );
  static String money(double value) =>
      value.isFinite ? _money.format(value) : 'Unavailable';
  static String initial(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
