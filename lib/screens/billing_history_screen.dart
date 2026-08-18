import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bill.dart';
import '../services/bill_service.dart';
import 'bill_details_screen.dart';

class BillingHistoryScreen extends StatefulWidget {
  const BillingHistoryScreen({super.key});

  @override
  State<BillingHistoryScreen> createState() => _BillingHistoryScreenState();
}

class _BillingHistoryScreenState extends State<BillingHistoryScreen> {
  List<Bill> _bills = <Bill>[];
  bool _isLoading = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = ''; // '' = All, 'Paid', 'Pending'

  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bills = await BillService.instance.fetchBills(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
      if (mounted) setState(() => _bills = bills);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Unable to load billing history. Please check server connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v.trim());
    // Debounce: reload after short pause
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchQuery == v.trim()) _loadBills();
    });
  }

  void _setStatusFilter(String status) {
    setState(() => _statusFilter = _statusFilter == status ? '' : status);
    _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(
          'Billing History',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: _textDark),
        ),
        actions: [
          IconButton(
            onPressed: _loadBills,
            icon: const Icon(Icons.refresh_rounded, color: _blue),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Search invoice, customer name or mobile...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _blue),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: _blue, width: 1.8),
                  ),
                ),
              ),
            ),

            // Status filter chips
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                children: [
                  _filterChip('All', ''),
                  const SizedBox(width: 8),
                  _filterChip('Paid', 'Paid'),
                  const SizedBox(width: 8),
                  _filterChip('Added to A/C', 'Added to A/C'),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected =
        value.isEmpty ? _statusFilter.isEmpty : _statusFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600),
      ),
      selected: isSelected,
      onSelected: (_) => _setStatusFilter(value),
      selectedColor: _blue.withAlpha(30),
      checkmarkColor: _blue,
      side: BorderSide(
          color: isSelected ? _blue : Colors.grey.shade300),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 56, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Unable to load billing history',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textDark),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check server connection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: _textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadBills,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Retry',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    if (_bills.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBills,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No Billing History',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _textDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your generated bills will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _bills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return _BillCard(
            bill: bill,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BillDetailsScreen(bill: bill),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  static const Color _blue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(amount % 1 == 0 ? 0 : 2)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = bill.status.toLowerCase() == 'paid';
    final isOnAccount = bill.status.toLowerCase() == 'added to a/c';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: _blue, size: 22),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.invoiceNo,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bill.customerName,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _blue),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          bill.displayDate,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: _textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.inventory_2_outlined,
                            size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${bill.products.length} Item${bill.products.length == 1 ? '' : 's'}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: _textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: amount + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${_formatAmount(bill.grandTotal)}',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _textDark),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? Colors.green.shade50
                          : isOnAccount
                              ? Colors.orange.shade50
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPaid
                            ? Colors.green.shade300
                            : isOnAccount
                                ? Colors.orange.shade300
                                : Colors.grey.shade300,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      bill.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isPaid
                            ? Colors.green.shade700
                            : isOnAccount
                                ? Colors.orange.shade800
                                : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
