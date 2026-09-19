import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/shop_profile.dart';
import '../services/shop_profile_repository.dart';
import 'billing_history_screen.dart';
import 'categories_screen.dart';
import 'printer_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ShopProfileRepository.instance;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSub = Color(0xFF627D98);

  @override
  void initState() {
    super.initState();
    _repo.fetchProfile();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: isError ? Colors.red.shade700 : _blue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  Future<void> _openEditForm(ShopProfile current) async {
    final saved = await Navigator.of(context).push<ShopProfile>(
      MaterialPageRoute(builder: (_) => EditBusinessProfileScreen(current: current)),
    );
    if (saved != null && mounted) {
      _snack('Business profile saved successfully');
    }
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textDark)),
        ]),
        content: Text('Are you sure you want to logout from Swamidatta Agencies ERP?',
            style: GoogleFonts.poppins(fontSize: 14, color: _textSub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: _textSub))),
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _snack('Logged out successfully');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Business Profile',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _textDark)),
        actions: [
          ValueListenableBuilder<ShopProfile>(
            valueListenable: _repo.profile,
            builder: (_, profile, __) => IconButton(
              icon: const Icon(Icons.edit_rounded, color: _blue),
              tooltip: 'Edit Profile',
              onPressed: () => _openEditForm(profile),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _repo.isLoading,
          builder: (_, isLoading, __) {
            return ValueListenableBuilder<ShopProfile>(
              valueListenable: _repo.profile,
              builder: (_, profile, __) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(profile: profile, primaryColor: _blue, onEditTap: () => _openEditForm(profile)),
                      const SizedBox(height: 16),
                      _BusinessInfoCard(
                        profile: profile,
                        isLoading: isLoading,
                        primaryColor: _blue,
                        textDark: _textDark,
                        textSub: _textSub,
                        onEditTap: () => _openEditForm(profile),
                      ),
                      const SizedBox(height: 16),
                      _SettingsCard(
                        primaryColor: _blue,
                        textDark: _textDark,
                        textSub: _textSub,
                        onTap: (title) {
                          if (title == 'Categories') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const CategoriesScreen()),
                            );
                          } else if (title == 'Billing History') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BillingHistoryScreen()),
                            );
                          } else if (title == 'Shop Information') {
                            _openEditForm(profile);
                          } else if (title == 'Printer Settings') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrinterSettingsScreen(),
                              ),
                            );
                          } else if (title == 'Logout') {
                            _showLogoutDialog();
                          } else {
                            _snack('$title coming soon');
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _showLogoutDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 22),
                          label: Text('Logout from Account',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text('Swamidatta ERP v2.4.0 • Wholesale Footwear Edition',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Header card ────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final ShopProfile profile;
  final Color primaryColor;
  final VoidCallback onEditTap;

  const _HeaderCard({required this.profile, required this.primaryColor, required this.onEditTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: primaryColor.withAlpha(12), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withAlpha(150)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFFE8F1FB),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.roller_skating_rounded, size: 38, color: primaryColor),
                      const SizedBox(height: 2),
                      Text('SA',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w700, color: primaryColor, letterSpacing: 1.0)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(profile.shopName,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w700, color: const Color(0xFF102A43))),
          const SizedBox(height: 4),
          Text('Wholesale Footwear Billing System',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF627D98))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FB),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: primaryColor.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Text('Admin',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Business Info Card ─────────────────────────────────────────────────────────

class _BusinessInfoCard extends StatelessWidget {
  final ShopProfile profile;
  final bool isLoading;
  final Color primaryColor;
  final Color textDark;
  final Color textSub;
  final VoidCallback onEditTap;

  const _BusinessInfoCard({
    required this.profile,
    required this.isLoading,
    required this.primaryColor,
    required this.textDark,
    required this.textSub,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.business_center_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 8),
                Text('Business Information',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textDark)),
              ]),
              InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Edit',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else ...[
            _InfoRow(icon: Icons.store_rounded, label: 'Shop Name', value: profile.shopName, primaryColor: primaryColor, textDark: textDark),
            _InfoRow(icon: Icons.person_outline_rounded, label: 'Owner Name', value: profile.ownerName, primaryColor: primaryColor, textDark: textDark),
            _InfoRow(icon: Icons.phone_outlined, label: 'Mobile Number', value: profile.mobile, primaryColor: primaryColor, textDark: textDark),
            _InfoRow(icon: Icons.email_outlined, label: 'Email Address', value: profile.email, primaryColor: primaryColor, textDark: textDark),
            _InfoRow(icon: Icons.receipt_long_outlined, label: 'GST Number', value: profile.gstNumber, primaryColor: primaryColor, textDark: textDark, badgeText: profile.gstNumber.isNotEmpty ? 'VERIFIED' : null),
            _InfoRow(icon: Icons.location_on_outlined, label: 'Shop Address', value: profile.address, primaryColor: primaryColor, textDark: textDark),
            _InfoRow(icon: Icons.access_time_outlined, label: 'Business Hours', value: profile.businessHours, primaryColor: primaryColor, textDark: textDark, isLast: true),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color primaryColor;
  final Color textDark;
  final String? badgeText;
  final bool isLast;

  const _InfoRow({
    required this.icon, required this.label, required this.value,
    required this.primaryColor, required this.textDark,
    this.badgeText, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF829AB1))),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: textDark))),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade300, width: 0.8),
                        ),
                        child: Text(badgeText!, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings Card ──────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Color primaryColor;
  final Color textDark;
  final Color textSub;
  final Function(String) onTap;

  const _SettingsCard({required this.primaryColor, required this.textDark, required this.textSub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text('Settings & Options', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textDark)),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          _SettingsTile(icon: Icons.category_rounded, iconBg: const Color(0xFFFFF9C4), iconColor: const Color(0xFFF57F17), title: 'Categories', subtitle: 'Manage product categories & sizes', textDark: textDark, textSub: textSub, onTap: () => onTap('Categories')),
          const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
          _SettingsTile(icon: Icons.receipt_long_rounded, iconBg: const Color(0xFFE8F5E9), iconColor: const Color(0xFF2E7D32), title: 'Billing History', subtitle: 'View & download all generated bills', textDark: textDark, textSub: textSub, onTap: () => onTap('Billing History')),
          const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
          _SettingsTile(icon: Icons.storefront_rounded, iconBg: const Color(0xFFE8F1FB), iconColor: primaryColor, title: 'Shop Information', subtitle: 'Address, GST, logo & contact info', textDark: textDark, textSub: textSub, onTap: () => onTap('Shop Information')),
          const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
          _SettingsTile(icon: Icons.person_outline_rounded, iconBg: const Color(0xFFEAF5EA), iconColor: const Color(0xFF2E7D32), title: 'User Profile', subtitle: 'Edit admin credentials & role', textDark: textDark, textSub: textSub, onTap: () => onTap('User Profile')),
          const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
          _SettingsTile(icon: Icons.print_rounded, iconBg: const Color(0xFFF3E5F5), iconColor: const Color(0xFF7B1FA2), title: 'Printer Settings', subtitle: 'Configure thermal & Bluetooth printer', textDark: textDark, textSub: textSub, onTap: () => onTap('Printer Settings')),
          const Divider(height: 1, indent: 64, color: Color(0xFFF0F0F0)),
          _SettingsTile(icon: Icons.cloud_sync_rounded, iconBg: const Color(0xFFE0F7FA), iconColor: const Color(0xFF00838F), title: 'Backup & Restore', subtitle: 'Database auto-backup & cloud export', textDark: textDark, textSub: textSub, onTap: () => onTap('Backup & Restore'), isLast: true),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textDark;
  final Color textSub;
  final VoidCallback onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle,
    required this.textDark, required this.textSub,
    required this.onTap, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: textSub)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF829AB1)),
    );
  }
}

// ── Edit Business Profile Screen ───────────────────────────────────────────────

class EditBusinessProfileScreen extends StatefulWidget {
  final ShopProfile current;

  const EditBusinessProfileScreen({super.key, required this.current});

  @override
  State<EditBusinessProfileScreen> createState() => _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _hoursCtrl;

  bool _isSaving = false;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);

  @override
  void initState() {
    super.initState();
    final p = widget.current;
    _shopNameCtrl = TextEditingController(text: p.shopName);
    _ownerNameCtrl = TextEditingController(text: p.ownerName);
    _mobileCtrl = TextEditingController(text: p.mobile);
    _emailCtrl = TextEditingController(text: p.email);
    _gstCtrl = TextEditingController(text: p.gstNumber);
    _addressCtrl = TextEditingController(text: p.address);
    _hoursCtrl = TextEditingController(text: p.businessHours);
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = ShopProfile(
      shopName: _shopNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      businessHours: _hoursCtrl.text.trim(),
    );

    try {
      final saved = await ShopProfileRepository.instance.saveProfile(updated);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save business information: $e',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Edit Business Profile',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: _textDark)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text('Save',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _blue)),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCard(children: [
                  _buildField(
                    ctrl: _shopNameCtrl,
                    label: 'Shop Name *',
                    hint: 'e.g. Swamidatta Agencies',
                    icon: Icons.store_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Shop name is required' : null,
                  ),
                  _buildField(
                    ctrl: _ownerNameCtrl,
                    label: 'Owner Name *',
                    hint: 'e.g. Ajay Kumar',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Owner name is required' : null,
                  ),
                  _buildField(
                    ctrl: _mobileCtrl,
                    label: 'Mobile Number *',
                    hint: 'e.g. +91 98765 43210',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Mobile number is required' : null,
                  ),
                  _buildField(
                    ctrl: _emailCtrl,
                    label: 'Email Address',
                    hint: 'e.g. contact@swamidatta.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildField(
                    ctrl: _gstCtrl,
                    label: 'GST Number',
                    hint: 'e.g. 27AABCU9603R1ZM',
                    icon: Icons.receipt_long_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  _buildField(
                    ctrl: _addressCtrl,
                    label: 'Shop Address *',
                    hint: 'e.g. Plot No. 42, Footwear Market, Kolhapur',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Shop address is required' : null,
                  ),
                  _buildField(
                    ctrl: _hoursCtrl,
                    label: 'Business Hours',
                    hint: 'e.g. Mon - Sat: 9:00 AM - 8:30 PM',
                    icon: Icons.access_time_outlined,
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Business Profile',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    bool isLast = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: _textDark)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(icon, size: 20, color: _blue),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}