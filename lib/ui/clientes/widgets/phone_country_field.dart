// 📂 lib/ui/clientes/widgets/phone_country_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ──────────────────────────────────────────────
// Modelo de país
// ──────────────────────────────────────────────
class CountryCode {
  final String flag;
  final String name;
  final String dialCode; // Sin el "+". Ej: "1", "52", "57"

  const CountryCode({
    required this.flag,
    required this.name,
    required this.dialCode,
  });
}

const List<CountryCode> kCountryCodes = [
  // ── Caribe ──
  CountryCode(flag: '🇩🇴', name: 'República Dominicana', dialCode: '1'),
  CountryCode(flag: '🇵🇷', name: 'Puerto Rico',           dialCode: '1'),
  CountryCode(flag: '🇨🇺', name: 'Cuba',                  dialCode: '53'),
  CountryCode(flag: '🇯🇲', name: 'Jamaica',               dialCode: '1'),
  CountryCode(flag: '🇭🇹', name: 'Haití',                 dialCode: '509'),
  CountryCode(flag: '🇹🇹', name: 'Trinidad y Tobago',     dialCode: '1'),

  // ── América Central ──
  CountryCode(flag: '🇲🇽', name: 'México',                dialCode: '52'),
  CountryCode(flag: '🇬🇹', name: 'Guatemala',             dialCode: '502'),
  CountryCode(flag: '🇧🇿', name: 'Belice',                dialCode: '501'),
  CountryCode(flag: '🇭🇳', name: 'Honduras',              dialCode: '504'),
  CountryCode(flag: '🇸🇻', name: 'El Salvador',           dialCode: '503'),
  CountryCode(flag: '🇳🇮', name: 'Nicaragua',             dialCode: '505'),
  CountryCode(flag: '🇨🇷', name: 'Costa Rica',            dialCode: '506'),
  CountryCode(flag: '🇵🇦', name: 'Panamá',                dialCode: '507'),

  // ── América del Sur ──
  CountryCode(flag: '🇨🇴', name: 'Colombia',              dialCode: '57'),
  CountryCode(flag: '🇻🇪', name: 'Venezuela',             dialCode: '58'),
  CountryCode(flag: '🇪🇨', name: 'Ecuador',               dialCode: '593'),
  CountryCode(flag: '🇵🇪', name: 'Perú',                  dialCode: '51'),
  CountryCode(flag: '🇧🇴', name: 'Bolivia',               dialCode: '591'),
  CountryCode(flag: '🇧🇷', name: 'Brasil',                dialCode: '55'),
  CountryCode(flag: '🇵🇾', name: 'Paraguay',              dialCode: '595'),
  CountryCode(flag: '🇺🇾', name: 'Uruguay',               dialCode: '598'),
  CountryCode(flag: '🇦🇷', name: 'Argentina',             dialCode: '54'),
  CountryCode(flag: '🇨🇱', name: 'Chile',                 dialCode: '56'),
  CountryCode(flag: '🇬🇾', name: 'Guyana',                dialCode: '592'),
  CountryCode(flag: '🇸🇷', name: 'Surinam',               dialCode: '597'),

  // ── Norte América ──
  CountryCode(flag: '🇺🇸', name: 'Estados Unidos',        dialCode: '1'),
  CountryCode(flag: '🇨🇦', name: 'Canadá',                dialCode: '1'),

  // ── Europa ──
  CountryCode(flag: '🇪🇸', name: 'España',                dialCode: '34'),
  CountryCode(flag: '🇵🇹', name: 'Portugal',              dialCode: '351'),
];

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

/// Formateador automático xxx-xxx-xxxx (máx 10 dígitos).
class TelefonoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newValue.text.length < oldValue.text.length) return _build(digits);
    if (digits.length > 10) return oldValue;
    return _build(digits);
  }

  TextEditingValue _build(String digits) {
    var f = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) f += '-';
      f += digits[i];
    }
    return TextEditingValue(
      text: f,
      selection: TextSelection.collapsed(offset: f.length),
    );
  }
}

/// Construye el número E164 limpio (sin +, sin guiones).
/// Ejemplo: dialCode="52", localNumber="811-376-8166" → "528113768166"
/// Ejemplo: dialCode="1",  localNumber="809-123-4567" → "18091234567"
String buildE164(String dialCode, String localNumber) {
  final digits = localNumber.replaceAll(RegExp(r'[^0-9]'), '');
  return '$dialCode$digits';
}

/// Resuelve el número para WhatsApp:
/// - Usa telefonoE164 si existe.
/// - Fallback: agrega +1 (RD/US) a los dígitos del campo telefono.
String resolverNumeroWhatsApp(Map<String, dynamic> clienteData) {
  final e164 = clienteData['telefonoE164'] as String?;
  if (e164 != null && e164.isNotEmpty) return e164;
  // Fallback conservador: asumir RD (+1)
  final raw =
  (clienteData['telefono'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  return '1$raw';
}

// ──────────────────────────────────────────────
// Widget
// ──────────────────────────────────────────────

/// Fila con [selector de país] + [campo teléfono].
class PhoneWithCountryField extends StatefulWidget {
  final TextEditingController controller;
  final CountryCode initialCountry;
  final InputDecoration Function(String label, {IconData? icon}) decoBuilder;
  final void Function(CountryCode country) onCountryChanged;
  final String? Function(String?)? validator;

  const PhoneWithCountryField({
    super.key,
    required this.controller,
    required this.initialCountry,
    required this.decoBuilder,
    required this.onCountryChanged,
    this.validator,
  });

  @override
  State<PhoneWithCountryField> createState() => _PhoneWithCountryFieldState();
}

class _PhoneWithCountryFieldState extends State<PhoneWithCountryField> {
  late CountryCode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCountry;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selector de país ──
        GestureDetector(
          onTap: _showPicker,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selected.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 4),
                Text('+${_selected.dialCode}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Campo teléfono ──
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [TelefonoInputFormatter()],
            decoration: widget.decoBuilder('Teléfono', icon: Icons.call),
            validator: widget.validator ??
                    (v) {
                  final digits =
                  (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length < 7 ? 'Número inválido' : null;
                },
          ),
        ),
      ],
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Seleccionar país',
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          for (final c in kCountryCodes)
            ListTile(
              leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
              title: Text(c.name),
              trailing: Text('+${c.dialCode}',
                  style: const TextStyle(color: Colors.grey)),
              onTap: () {
                setState(() => _selected = c);
                widget.onCountryChanged(c);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}