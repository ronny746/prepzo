import 'package:flutter/material.dart';
import 'package:lms/core/constants/app_strings.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// One tappable contact row: label, the value shown, and the URI it opens.
class _SupportRow {
  const _SupportRow(this.label, this.value, this.icon, this.uri);
  final String label;
  final String value;
  final IconData icon;
  final Uri uri;
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _loading = true;
  List<_SupportRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Contact details are admin-managed on the server (`supportContact` in
  /// public-settings), so they are fetched instead of baked into the app.
  Future<void> _load() async {
    var rows = <_SupportRow>[];
    try {
      final response = await ApiClient().get('/public-settings');
      final data = response['data'] ?? response;
      final contact = data is Map ? data['supportContact'] : null;
      if (contact is Map) rows = _buildRows(contact);
    } catch (e) {
      debugPrint('Support contact load error: $e');
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  static String _s(Map m, String k) => (m[k] ?? '').toString().trim();

  /// Only non-empty fields become rows.
  List<_SupportRow> _buildRows(Map c) {
    final rows = <_SupportRow>[];
    final phone = _s(c, 'phone');
    if (phone.isNotEmpty) {
      // Strip spaces/dashes so the dialer gets a clean number.
      rows.add(_SupportRow(
        AppStrings.supportPhone,
        phone,
        Icons.call_rounded,
        Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[\s\-()]'), '')),
      ));
    }
    final email = _s(c, 'email');
    if (email.isNotEmpty) {
      rows.add(_SupportRow(
        AppStrings.supportEmail,
        email,
        Icons.email_rounded,
        Uri(scheme: 'mailto', path: email),
      ));
    }
    final website = _s(c, 'website');
    if (website.isNotEmpty) {
      // Admins may enter a bare domain; launchers need a scheme.
      final url = RegExp(r'^https?://', caseSensitive: false).hasMatch(website)
          ? website
          : 'https://$website';
      final uri = Uri.tryParse(url);
      if (uri != null) {
        rows.add(_SupportRow(
          AppStrings.supportWebsite,
          website,
          Icons.language_rounded,
          uri,
        ));
      }
    }
    final whatsapp = _s(c, 'whatsapp');
    // wa.me only accepts digits (country code included, no '+').
    final waDigits = whatsapp.replaceAll(RegExp(r'\D'), '');
    if (waDigits.isNotEmpty) {
      rows.add(_SupportRow(
        AppStrings.supportWhatsapp,
        whatsapp,
        Icons.chat_rounded,
        Uri.parse('https://wa.me/$waDigits'),
      ));
    }
    return rows;
  }

  Future<void> _open(Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.supportCannotOpen)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_rows.isEmpty) {
      body = const Center(child: Text(AppStrings.supportUnavailable));
    } else {
      body = Column(
        children: _rows
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  title: item.label,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.icon),
                      title: Text(item.value),
                      onTap: () => _open(item.uri),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
    return AppScaffold(title: AppStrings.supportTitle, body: body);
  }
}
