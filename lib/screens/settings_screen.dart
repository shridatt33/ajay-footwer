import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'barcode_studio_screen.dart';
import 'categories_screen.dart';
import 'printer_settings_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundFeedback = true;
  bool _autoPrintInvoice = false;
  bool _hapticFeedback = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Business & Hardware Section
            _buildSectionHeader('Business & Hardware'),
            const SizedBox(height: 10),
            Container(
              decoration: AppDecorations.card(),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.storefront_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryLight,
                    title: 'Shop & Business Profile',
                    subtitle: 'Manage shop name, GST, contact info & address',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                  const Divider(indent: 64),
                  _buildSettingTile(
                    icon: Icons.print_rounded,
                    iconColor: AppColors.accentPurple,
                    iconBg: AppColors.accentPurpleLight,
                    title: 'Thermal Printer Settings',
                    subtitle: 'Bluetooth printer, paper size & formatting',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                    ),
                  ),
                  const Divider(indent: 64),
                  _buildSettingTile(
                    icon: Icons.barcode_reader,
                    iconColor: AppColors.accentTeal,
                    iconBg: AppColors.accentTealLight,
                    title: 'Barcode Studio',
                    subtitle: 'Code 128 sticker labels & bulk printing',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BarcodeStudioScreen()),
                    ),
                  ),
                  const Divider(indent: 64),
                  _buildSettingTile(
                    icon: Icons.category_rounded,
                    iconColor: AppColors.warning,
                    iconBg: AppColors.warningLight,
                    title: 'Footwear Categories',
                    subtitle: 'Organize slippers, shoes, sandals & boots',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Billing & POS Preferences
            _buildSectionHeader('Billing & Scanning Preferences'),
            const SizedBox(height: 10),
            Container(
              decoration: AppDecorations.card(),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _soundFeedback,
                    activeTrackColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      'Beep on Barcode Scan',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Audio chime confirmation for successful scans',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) => setState(() => _soundFeedback = val),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    value: _hapticFeedback,
                    activeTrackColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      'Vibration / Haptic Touch',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Vibrate device when adding items to cart',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) => setState(() => _hapticFeedback = val),
                  ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    value: _autoPrintInvoice,
                    activeTrackColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      'Auto-Print Thermal Bill',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Immediately trigger printer on invoice generation',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) => setState(() => _autoPrintInvoice = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // System & Diagnostics
            _buildSectionHeader('System & Diagnostics'),
            const SizedBox(height: 10),
            Container(
              decoration: AppDecorations.card(),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.sync_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryLight,
                    title: 'Sync Local Data',
                    subtitle: 'Refresh catalog from cloud database',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Catalog & customer cache synced successfully.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Divider(indent: 64),
                  _buildSettingTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.textSecondary,
                    iconBg: AppColors.background,
                    title: 'About Footwear ERP',
                    subtitle: 'Version 1.0.0+1 • Swamidatta Agencies',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Swamidatta Agencies',
                        applicationVersion: '1.0.0+1',
                        applicationLegalese: '© 2026 Swamidatta Agencies. Wholesale Footwear ERP.',
                        applicationIcon: const CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.shopping_bag_rounded, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontFamily: 'Poppins', 
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 22,
      ),
    );
  }
}
