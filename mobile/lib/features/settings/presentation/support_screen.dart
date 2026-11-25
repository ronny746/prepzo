import 'package:flutter/material.dart';
import 'package:lms/core/constants/app_strings.dart';
import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _loading = true;
  String _phone = '';
  String _email = '';
  String _whatsapp = '';
  String _website = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Prepzo: contact details are admin-managed on the server
  /// (`supportContact` in public-settings) instead of baked into the app.
  Future<void> _load() async {
    try {
      final response = await ApiClient().get('/public-settings');
      final data = response['data'] ?? response;
      final contact = data is Map ? data['supportContact'] : null;
      if (contact is Map) {
        String s(String k) => (contact[k] ?? '').toString().trim();
        _phone = s('phone');
        _email = s('email');
        _whatsapp = s('whatsapp');
        _website = s('website');
      }
    } catch (e) {
      debugPrint('Support contact load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _launchUrl(String urlString) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.supportCannotOpen),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Only channels with a configured value get a tile.
  List<Widget> _channelTiles() {
    final tiles = <Widget>[];
    void add(Widget tile) {
      if (tiles.isNotEmpty) tiles.add(const Divider(height: 1));
      tiles.add(tile);
    }

    if (_phone.isNotEmpty) {
      // Strip spaces/dashes so the dialer gets a clean number.
      final dial = _phone.replaceAll(RegExp(r'[\s\-()]'), '');
      add(_supportChannelTile(
        title: 'Call Support Counselor',
        subtitle: 'Direct phone line: $_phone',
        icon: PhosphorIcons.phoneCall,
        color: const Color(0xFF0284C7),
        onTap: () => _launchUrl('tel:$dial'),
      ));
    }
    if (_email.isNotEmpty) {
      add(_supportChannelTile(
        title: 'Email Helpdesk',
        subtitle: 'Official mailbox: $_email',
        icon: PhosphorIcons.envelope,
        color: const Color(0xFFEA580C),
        onTap: () => _launchUrl('mailto:$_email?subject=Prepzo%20Support%20Request'),
      ));
    }
    // wa.me only accepts digits (country code included, no '+').
    final waDigits = _whatsapp.replaceAll(RegExp(r'\D'), '');
    if (waDigits.isNotEmpty) {
      add(_supportChannelTile(
        title: 'WhatsApp Support',
        subtitle: 'Instant messaging & batch inquiries',
        icon: PhosphorIcons.whatsappLogo,
        color: const Color(0xFF16A34A),
        onTap: () => _launchUrl('https://wa.me/$waDigits?text=Hello%20Prepzo%20Team'),
      ));
    }
    if (_website.isNotEmpty) {
      // Admins may enter a bare domain; launchers need a scheme.
      final url = RegExp(r'^https?://', caseSensitive: false).hasMatch(_website)
          ? _website
          : 'https://$_website';
      add(_supportChannelTile(
        title: 'Visit Official Website',
        subtitle: 'Portal and admissions: $_website',
        icon: PhosphorIcons.globe,
        color: AppTheme.primary,
        onTap: () => _launchUrl(url),
      ));
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Help & Support',
      header: const SectionCard(
        title: 'Customer & Academic Helpdesk',
        subtitle:
            'Connect with support counselors, raise service tickets, or browse common resolutions.',
        child: SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Quick Connect Cards Grid
            SectionCard(
              title: 'Direct Channels',
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Builder(builder: (context) {
                      final tiles = _channelTiles();
                      if (tiles.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(AppStrings.supportUnavailable),
                        );
                      }
                      return Column(children: tiles);
                    }),
            ),
            const SizedBox(height: 20),

            // Frequently Asked Questions
            SectionCard(
              title: 'Frequently Asked Questions (FAQs)',
              child: Column(
                children: [
                  _faqTile(
                    question: 'How do I enroll in a course?',
                    answer:
                        'On Home, open "Available Courses" (or "View all"), select the course you want to join, and tap "Enroll Now". For paid courses, complete the secure Razorpay payment to immediately unlock batches, exams, and materials.',
                  ),
                  _faqTile(
                    question: 'Why does an exam say "No questions available"?',
                    answer:
                        'This occurs if the exam paper is scheduled for a future date, or if your current enrolled plan does not include the Test Series module. Please confirm with your instructor or coordinator.',
                  ),
                  _faqTile(
                    question: 'Payment was deducted but course not enrolled?',
                    answer:
                        'Payments are automatically verified by Razorpay. In rare cases of bank network delay, contact us using the options above with your payment transaction ID.',
                  ),
                  _faqTile(
                    question: 'How do I ask doubts to my teachers?',
                    answer:
                        'Tap "Ask Doubt" on the Home screen, choose the subject and type your question. If no teacher is assigned to your batch yet, contact us using the options above.',
                  ),
                  _faqTile(
                    question: 'Can I change my email and personal info?',
                    answer:
                        'Yes! Navigate to Profile > Edit Personal Info. You can update your name, email address, mobile number, class, city, and state at any time.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _supportChannelTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: PhosphorIcon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: const PhosphorIcon(
          PhosphorIcons.arrowSquareOut,
          size: 16,
          color: Color(0xFF94A3B8),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _faqTile({required String question, required String answer}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
