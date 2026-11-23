import 'package:flutter/material.dart';
import '../models/shop_profile.dart';
import '../services/shop_profile_repository.dart';
import '../theme/app_theme.dart';
import 'barcode_studio_screen.dart';
import 'billing_history_screen.dart';
import 'categories_screen.dart';
import 'printer_settings_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ShopProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.fetchProfile();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _openEditForm(ShopProfile current) async {
    final saved = await Navigator.of(context).push<ShopProfile>(
      MaterialPageRoute(builder: (_) => EditBusinessProfileScreen(current: current)),
    );
    if (saved != null && mounted) {
      _snack('Business profile updated successfully');
    }
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(fontFamily: 'Poppins', 
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out from Swamidatta Agencies ERP?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', 
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _snack('Logged out successfully');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Logout',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Business Profile',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          ValueListenableBuilder<ShopProfile>(
            valueListenable: _repo.profile,
            builder: (_, profile, _) => TextButton.icon(
              onPressed: () => _openEditForm(profile),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                'Edit',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _repo.isLoading,
          builder: (_, isLoading, _) {
            return ValueListenableBuilder<ShopProfile>(
              valueListenable: _repo.profile,
              builder: (_, profile, _) {
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _repo.fetchProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Business Profile Header Card
                        _HeaderCard(
                          profile: profile,
                          onEditTap: () => _openEditForm(profile),
                        ),
                        const SizedBox(height: 14),

                        // 2. Business Information Card
                        _BusinessInfoCard(
                          profile: profile,
                          isLoading: isLoading,
                          onEditTap: () => _openEditForm(profile),
                        ),
                        const SizedBox(height: 14),

                        // 3. Settings & Options Card
                        _SettingsCard(
                          onTap: (destination) {
                            switch (destination) {
                              case 'Categories':
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                                );
                                break;
                              case 'Barcode Studio':
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const BarcodeStudioScreen()),
                                );
                                break;
                              case 'Billing History':
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const BillingHistoryScreen()),
                                );
                                break;
                              case 'Printer Settings':
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                                );
                                break;
                              case 'System Settings':
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                                break;
                              case 'Shop Information':
                                _openEditForm(profile);
                                break;
                              default:
                                _snack('$destination setting is up-to-date');
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // 4. Logout Action Button
                        OutlinedButton.icon(
                          onPressed: _showLogoutDialog,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(
                            'Sign Out of Account',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // App Version Footer
                        Center(
                          child: Text(
                            'Swamidatta ERP v2.5.0 • Wholesale Footwear Edition',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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

// ── 1. Compact Header Card ───────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.profile,
    required this.onEditTap,
  });

  final ShopProfile profile;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          // Logo with change camera badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 30, color: AppColors.primary),
                      Text(
                        'SA',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Business Name
          Text(
            profile.shopName,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),

          // Category Subtitle
          Text(
            'Wholesale Footwear Billing System',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Admin / Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Verified Business • Admin',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Organized Business Information Card ───────────────────────────────────

class _BusinessInfoCard extends StatelessWidget {
  const _BusinessInfoCard({
    required this.profile,
    required this.isLoading,
    required this.onEditTap,
  });

  final ShopProfile profile;
  final bool isLoading;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final hasGst = profile.gstNumber.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.business_center_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Business Information',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onEditTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Edit',
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _InfoRow(
              icon: Icons.store_rounded,
              label: 'Shop Name',
              value: profile.shopName,
            ),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Owner Name',
              value: profile.ownerName,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile Number',
              value: profile.mobile,
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email Address',
              value: profile.email.isNotEmpty ? profile.email : 'Not set',
            ),
            _InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'GST Number',
              value: hasGst ? profile.gstNumber : 'Unregistered',
              badgeText: hasGst ? 'GST REGISTERED' : null,
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Shop Address',
              value: profile.address,
              isMultiline: true,
            ),
            _InfoRow(
              icon: Icons.access_time_outlined,
              label: 'Business Hours',
              value: profile.businessHours,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.badgeText,
    this.isMultiline = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? badgeText;
  final bool isMultiline;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
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

// ── 3. Clean Settings & Options Card ─────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onTap});

  final void Function(String destination) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  'Settings & Options',
                  style: TextStyle(fontFamily: 'Poppins', 
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          _SettingsTile(
            icon: Icons.category_rounded,
            iconBg: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFD97706),
            title: 'Categories',
            subtitle: 'Manage product categories & footwear sizes',
            onTap: () => onTap('Categories'),
          ),
          const Divider(height: 1, indent: 60, color: AppColors.borderLight),

          _SettingsTile(
            icon: Icons.barcode_reader,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: AppColors.primary,
            title: 'Barcode Studio',
            subtitle: 'Print Code 128 stickers and A4 sheets',
            onTap: () => onTap('Barcode Studio'),
          ),
          const Divider(height: 1, indent: 60, color: AppColors.borderLight),

          _SettingsTile(
            icon: Icons.receipt_long_rounded,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            title: 'Billing History',
            subtitle: 'View and download generated invoices',
            onTap: () => onTap('Billing History'),
          ),
          const Divider(height: 1, indent: 60, color: AppColors.borderLight),

          _SettingsTile(
            icon: Icons.print_rounded,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'Printer Settings',
            subtitle: 'Configure thermal & Bluetooth printer',
            onTap: () => onTap('Printer Settings'),
          ),
          const Divider(height: 1, indent: 60, color: AppColors.borderLight),

          _SettingsTile(
            icon: Icons.settings_rounded,
            iconBg: const Color(0xFFF3F4F6),
            iconColor: const Color(0xFF4B5563),
            title: 'System Preferences',
            subtitle: 'Barcode scan sounds, haptic & auto-print',
            onTap: () => onTap('System Settings'),
          ),
          const Divider(height: 1, indent: 60, color: AppColors.borderLight),

          _SettingsTile(
            icon: Icons.storefront_rounded,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: AppColors.primary,
            title: 'Shop Information',
            subtitle: 'Address, GST, logo & contact info',
            onTap: () => onTap('Shop Information'),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.textMuted,
      ),
    );
  }
}

// ── 4. Edit Business Profile Screen ──────────────────────────────────────────

class EditBusinessProfileScreen extends StatefulWidget {
  const EditBusinessProfileScreen({super.key, required this.current});

  final ShopProfile current;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save business details: $e',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Edit Business Profile',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(
                      'Save',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        ctrl: _shopNameCtrl,
                        label: 'Shop / Agency Name *',
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving Changes...' : 'Save Business Profile',
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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
          Text(
            label,
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textPrimary),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted),
              prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
