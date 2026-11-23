import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/barcode_studio_screen.dart';
import 'screens/billing_history_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/purchase_entry_screen.dart';
import 'screens/settings_screen.dart';
import 'services/dashboard_service.dart';
import 'services/local_customer_repository.dart';
import 'services/local_product_repository.dart';
import 'services/shop_profile_repository.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable runtime downloading from fonts.gstatic.com to ensure 100% offline support
  GoogleFonts.config.allowRuntimeFetching = false;

  ShopProfileRepository.instance.fetchProfile();
  LocalProductRepository.instance.fetchProducts();
  LocalCustomerRepository.instance.fetchCustomers();
  runApp(const SwamidattaAgenciesApp());
}

class SwamidattaAgenciesApp extends StatelessWidget {
  const SwamidattaAgenciesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swamidatta Agencies',
      theme: AppTheme.lightTheme,
      routes: <String, WidgetBuilder>{
        '/billing': (_) => const BillingScreen(),
        '/products': (_) => const ProductsScreen(),
        '/barcode-studio': (_) => const BarcodeStudioScreen(),
        '/customers': (_) => const CustomersScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/categories': (_) => const CategoriesScreen(),
        '/billing-history': (_) => const BillingHistoryScreen(),
        '/purchase-entry': (_) => const PurchaseEntryScreen(),
        '/companies': (_) => const PlaceholderRoutePage(title: 'Companies'),
        '/retailers': (_) => const CustomersScreen(),
        '/payments': (_) => const PaymentsScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      home: const DashboardShell(),
    );
  }
}

// ── Dashboard Shell with Modern Bottom Navigation ────────────────────────────

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  static const List<String> _bottomRoutes = <String>[
    '/billing',
    '/products',
    '/customers',
    '/profile',
  ];

  void _handleBottomNavigation(BuildContext context, int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    Navigator.pushNamed(context, _bottomRoutes[index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const DashboardHome(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 0.8),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => _handleBottomNavigation(context, i),
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppColors.primaryLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 68,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              label: 'Billing',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.people_alt_rounded, color: AppColors.primary),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Home (Live Data & Modern Architecture) ─────────────────────────

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  DashboardSummary? _summary;
  bool _isLoading = false;
  String? _error;

  // 8 Quick Actions in required order
  static const List<QuickActionData> _quickActions = <QuickActionData>[
    QuickActionData(
      title: 'Purchase Entry',
      subtitle: 'Inward stock & bills',
      icon: Icons.add_shopping_cart_rounded,
      routeName: '/purchase-entry',
      color: AppColors.primary,
      bgColor: Color(0xFFEFF6FF),
      isPrimaryAction: true,
    ),
    QuickActionData(
      title: 'Products',
      subtitle: 'Catalog & sizes',
      icon: Icons.inventory_2_rounded,
      routeName: '/products',
      color: Color(0xFF059669),
      bgColor: Color(0xFFECFDF5),
    ),
    QuickActionData(
      title: 'Barcode Studio',
      subtitle: 'Print Code 128',
      icon: Icons.barcode_reader,
      routeName: '/barcode-studio',
      color: Color(0xFF2563EB),
      bgColor: Color(0xFFEFF6FF),
    ),
    QuickActionData(
      title: 'Billing History',
      subtitle: 'Recent invoices',
      icon: Icons.history_rounded,
      routeName: '/billing-history',
      color: Color(0xFF7C3AED),
      bgColor: Color(0xFFF5F3FF),
    ),
    QuickActionData(
      title: 'Billing',
      subtitle: 'POS scan & sale',
      icon: Icons.point_of_sale_rounded,
      routeName: '/billing',
      color: Color(0xFF2563EB),
      bgColor: Color(0xFFEFF6FF),
      isPrimaryAction: true,
    ),
    QuickActionData(
      title: 'Customers',
      subtitle: 'Retailers ledger',
      icon: Icons.people_alt_rounded,
      routeName: '/customers',
      color: Color(0xFFD97706),
      bgColor: Color(0xFFFFFBEB),
    ),
    QuickActionData(
      title: 'Payments',
      subtitle: 'Collections & dues',
      icon: Icons.account_balance_wallet_rounded,
      routeName: '/payments',
      color: Color(0xFFDC2626),
      bgColor: Color(0xFFFEF2F2),
    ),
    QuickActionData(
      title: 'Settings',
      subtitle: 'Printer & system',
      icon: Icons.settings_rounded,
      routeName: '/settings',
      color: Color(0xFF4B5563),
      bgColor: Color(0xFFF3F4F6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initDashboardData();
  }

  Future<void> _initDashboardData() async {
    // 1. Immediately display cached summary if present
    final cached = await DashboardService.instance.loadCachedSummary();
    if (mounted && cached != null && _summary == null) {
      setState(() {
        _summary = cached;
      });
    }
    // 2. Fetch fresh live data from API
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final summary = await DashboardService.instance.fetchSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _error = null;
          _isLoading = false;
        });
      }
    } on DashboardException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to refresh: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    final intPart = value.toInt();
    return '₹${_indianFormat(intPart)}';
  }

  String _indianFormat(int n) {
    if (n == 0) return '0';
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buffer.write(',');
      buffer.write(rest[i]);
    }
    return '${buffer.toString()},$last3';
  }

  String _formatToday() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = DateTime.now();
    return '${today.day} ${months[today.month - 1]} ${today.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadSummary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Swamidatta Agencies',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Wholesale Footwear Billing System',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('All systems operational • ${_formatToday()}'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.textPrimary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
                      tooltip: 'Notifications',
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Date banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Business Overview',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _formatToday(),
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_summary == null && _isLoading) ...[
                    Container(
                      height: 160,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: AppDecorations.card(),
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                            SizedBox(height: 14),
                            Text(
                              'Loading business statistics...',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_summary == null && _error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: AppDecorations.card(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.warningLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 24),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to Load Statistics',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _loadSummary,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text(
                              'Retry',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$_error (Showing cached overview)',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadSummary,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // 6 Modern Statistic Cards Grid
                    _buildStatCardsGrid(),
                  ],

                  const SizedBox(height: 24),

                  // Quick Actions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '8 Modules',
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2-Column Quick Actions Grid
                  _buildQuickActionsGrid(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6 Modern Business Statistic Cards ───────────────────────────────────────

  Widget _buildStatCardsGrid() {
    final s = _summary;
    final isLoaded = s != null;

    final stats = <StatCardModel>[
      StatCardModel(
        title: 'Total Retailers',
        value: isLoaded ? _indianFormat(s.retailers) : '—',
        icon: Icons.storefront_rounded,
        accentColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
      ),
      StatCardModel(
        title: 'Total Products',
        value: isLoaded ? _indianFormat(s.totalProducts) : '—',
        icon: Icons.inventory_2_rounded,
        accentColor: const Color(0xFF059669),
        bgColor: const Color(0xFFECFDF5),
      ),
      StatCardModel(
        title: 'Total Stock Value',
        value: isLoaded ? _formatCurrency(s.stockValue) : '—',
        icon: Icons.wallet_rounded,
        accentColor: AppColors.primary,
        bgColor: const Color(0xFFEFF6FF),
      ),
      StatCardModel(
        title: "Today's Sales",
        value: isLoaded ? _formatCurrency(s.todaySales) : '—',
        icon: Icons.trending_up_rounded,
        accentColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
      ),
      StatCardModel(
        title: "Today's Purchases",
        value: isLoaded ? _formatCurrency(s.todayPurchases > 0 ? s.todayPurchases : 0.0) : '₹0',
        icon: Icons.shopping_cart_checkout_rounded,
        accentColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
      ),
      StatCardModel(
        title: 'Pending Payments',
        value: isLoaded ? _formatCurrency(s.pendingPayments > 0 ? s.pendingPayments : 0.0) : '₹0',
        icon: Icons.pending_actions_rounded,
        accentColor: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((stat) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: stat.bgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(stat.icon, color: stat.accentColor, size: 20),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── 2-Column Quick Actions Grid (8 Modules) ────────────────────────────────

  Widget _buildQuickActionsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _quickActions.map((action) {
            return SizedBox(
              width: cardWidth,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, action.routeName),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: action.isPrimaryAction
                        ? BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : AppDecorations.card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: action.bgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(action.icon, color: action.color, size: 24),
                            ),
                            if (action.isPrimaryAction)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DAILY',
                                  style: TextStyle(fontFamily: 'Poppins', 
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          action.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Models & Placeholders ───────────────────────────────────────────────────

class StatCardModel {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;

  const StatCardModel({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
  });
}

class QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final Color color;
  final Color bgColor;
  final bool isPrimaryAction;

  const QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    required this.color,
    required this.bgColor,
    this.isPrimaryAction = false,
  });
}

class PlaceholderRoutePage extends StatelessWidget {
  const PlaceholderRoutePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.handyman_rounded, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                '$title Coming Soon',
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is integrated and will be activated in the next workflow.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', 
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
