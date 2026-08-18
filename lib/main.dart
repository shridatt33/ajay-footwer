import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/billing_history_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profile_screen.dart';
import 'services/dashboard_service.dart';
import 'services/shop_profile_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-fetch business profile so bill/invoice always has latest data
  ShopProfileRepository.instance.fetchProfile();
  runApp(const SwamidattaAgenciesApp());
}

class SwamidattaAgenciesApp extends StatelessWidget {
  const SwamidattaAgenciesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swamidatta Agencies',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF102A43),
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF102A43),
          ),
        ),
      ),
      routes: <String, WidgetBuilder>{
        '/billing': (_) => const BillingScreen(),
        '/products': (_) => const ProductsScreen(),
        '/customers': (_) => const CustomersScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/categories': (_) => const CategoriesScreen(),
        '/billing-history': (_) => const BillingHistoryScreen(),
        '/purchase-entry': (_) =>
            const PlaceholderRoutePage(title: 'Purchase Entry'),
        '/companies': (_) => const PlaceholderRoutePage(title: 'Companies'),
        '/retailers': (_) => const PlaceholderRoutePage(title: 'Retailers'),
        '/payments': (_) => const PaymentsScreen(),
        '/settings': (_) => const PlaceholderRoutePage(title: 'Settings'),
      },
      home: const DashboardShell(),
    );
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> with RouteAware {
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
      body: const DashboardHome(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => _handleBottomNavigation(context, i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded), label: 'Billing'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_rounded), label: 'Products'),
          NavigationDestination(
              icon: Icon(Icons.people_alt_rounded), label: 'Customers'),
          NavigationDestination(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Dashboard Home (live data) ────────────────────────────────────────────────

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  DashboardSummary? _summary;
  bool _isLoading = false;
  String? _error;

  // Quick-action definitions (static — routes only)
  static const List<QuickActionData> _quickActions = <QuickActionData>[
    QuickActionData(
        title: 'Purchase Entry',
        icon: Icons.shopping_bag_rounded,
        routeName: '/purchase-entry',
        color: Color(0xFF1565C0)),
    QuickActionData(
        title: 'Products',
        icon: Icons.category_rounded,
        routeName: '/products',
        color: Color(0xFF2E7D32)),
    QuickActionData(
        title: 'Billing History',
        icon: Icons.history_rounded,
        routeName: '/billing-history',
        color: Color(0xFF7B1FA2)),
    QuickActionData(
        title: 'Billing',
        icon: Icons.receipt_long_rounded,
        routeName: '/billing',
        color: Color(0xFF00838F)),
    QuickActionData(
        title: 'Customers',
        icon: Icons.people_alt_rounded,
        routeName: '/customers',
        color: Color(0xFFF57C00)),
    QuickActionData(
        title: 'Payments',
        icon: Icons.payments_rounded,
        routeName: '/payments',
        color: Color(0xFFD32F2F)),
    QuickActionData(
        title: 'Settings',
        icon: Icons.settings_rounded,
        routeName: '/settings',
        color: Color(0xFF5D4037)),
  ];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch every time this widget is shown (e.g. returning from sub-screens)
    _loadSummary();
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
          _error = 'Unable to load dashboard data.\nPlease check server connection.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Formatters ──────────────────────────────────────────────────────────────

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹ ${(value / 10000000).toStringAsFixed(2)}Cr';
    } else if (value >= 100000) {
      return '₹ ${(value / 100000).toStringAsFixed(2)}L';
    }
    // Indian grouping: 1,28,450
    final intPart = value.toInt();
    return '₹ ${_indianFormat(intPart)}';
  }

  String _indianFormat(int n) {
    if (n == 0) return '0';
    final s = n.toString();
    if (s.length <= 3) return s;
    // Last 3 digits, then groups of 2
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buffer.write(',');
      buffer.write(rest[i]);
    }
    return '${buffer.toString()},$last3';
  }

  String _formatCount(int n) => _indianFormat(n);

  String _formatToday() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final today = DateTime.now();
    return '${today.day} ${months[today.month - 1]} ${today.year}';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadSummary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App bar
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 76,
              titleSpacing: 0,
              title: const _AppBarContent(),
              actions: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _loadSummary,
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: 'Notifications',
                  ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF1565C0),
                    child: Text('A',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _GreetingSection(dateLabel: _formatToday()),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Overview'),
                  const SizedBox(height: 12),

                  // ── Overview Cards ────────────────────────────────────────
                  _error != null
                      ? _buildErrorCard()
                      : _buildOverviewCards(),

                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _quickActions
                            .map((a) => SizedBox(
                                  width: w,
                                  child: QuickActionCard(
                                    action: a,
                                    onTap: () => Navigator.pushNamed(
                                        context, a.routeName),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final s = _summary;

    final cards = <SummaryCardData>[
      SummaryCardData(
        title: "Today's Bills",
        value: s == null ? '—' : _formatCount(s.todayBills),
        icon: Icons.receipt_rounded,
        accentColor: const Color(0xFF1565C0),
        backgroundColor: const Color(0xFFE8F1FB),
      ),
      SummaryCardData(
        title: 'Total Products',
        value: s == null ? '—' : _formatCount(s.totalProducts),
        icon: Icons.inventory_2_rounded,
        accentColor: const Color(0xFF2E7D32),
        backgroundColor: const Color(0xFFEAF5EA),
      ),
      SummaryCardData(
        title: 'Retailers',
        value: s == null ? '—' : _formatCount(s.retailers),
        icon: Icons.storefront_rounded,
        accentColor: const Color(0xFFF57C00),
        backgroundColor: const Color(0xFFFFF2E5),
      ),
      SummaryCardData(
        title: 'Stock Value',
        value: s == null ? '—' : _formatCurrency(s.stockValue),
        icon: Icons.account_balance_wallet_rounded,
        accentColor: const Color(0xFF6D4C41),
        backgroundColor: const Color(0xFFF5ECE8),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) => SizedBox(
                    width: cardWidth,
                    child: SummaryCard(data: card, isLoading: _isLoading && s == null),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(
            'Unable to load dashboard data',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please check server connection.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loadSummary,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _AppBarContent extends StatelessWidget {
  const _AppBarContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F1FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text('SA',
                style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Swamidatta Agencies',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Wholesale Footwear Billing System',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Admin 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF102A43),
          ),
    );
  }
}

class SummaryCardData {
  const SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.data, this.isLoading = false});

  final SummaryCardData data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: data.backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.accentColor),
          ),
          const SizedBox(height: 14),
          isLoading
              ? Container(
                  height: 22,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF102A43),
                      ),
                ),
          const SizedBox(height: 6),
          Text(
            data.title,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class QuickActionData {
  const QuickActionData({
    required this.title,
    required this.icon,
    required this.routeName,
    required this.color,
  });

  final String title;
  final IconData icon;
  final String routeName;
  final Color color;
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard(
      {super.key, required this.action, required this.onTap});

  final QuickActionData action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: action.color.withValues(alpha: 0.12),
                child: Icon(action.icon, color: action.color),
              ),
              const SizedBox(height: 14),
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF102A43),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceholderRoutePage extends StatelessWidget {
  const PlaceholderRoutePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                '$title screen coming soon',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This is a placeholder route for future module navigation.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
