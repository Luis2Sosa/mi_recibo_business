import 'dart:io' show Platform;
import 'package:intl/intl.dart';

/// Devuelve el monto con símbolo y formato según el país real del usuario.
/// RD (República Dominicana): `RD$ 8,800.00`
/// Otros países: símbolo y formato locales (ej. $ 8,800.00, R$ 8.800,00, etc.)
String monedaLocal(num valor) {
  final locale = Platform.localeName; // p.ej: es_DO, es_CO, en_US, pt_BR…

  // Caso especial RD: formato profesional local
  if (locale.toUpperCase().contains('_DO')) {
    return 'RD\$ ${NumberFormat("#,##0.00", "es_DO").format(valor)}';
  }

  // Resto de países: usar símbolo + número según locale
  final symbol = NumberFormat.simpleCurrency(locale: locale).currencySymbol;
  final number = NumberFormat.currency(locale: locale, symbol: '', decimalDigits: 2).format(valor);
  return '$symbol $number';
}
