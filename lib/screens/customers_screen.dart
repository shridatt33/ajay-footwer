import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer.dart';
import '../services/local_customer_repository.dart';
import 'add_edit_customer_screen.dart';
import 'customer_details_screen.dart';

class CustomersScreen extends StatefulWidget {
  final bool isSelectingCustomer;

  const CustomersScreen({
    super.key,
    this.isSelectingCustomer = false,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final LocalCustomerRepository _repository = LocalCustomerRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _surfaceBg = Color(0xFFF5F7FA);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  @override
  void initState() {
    super.initState();
    _repository.fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade700 : _primaryRoyalBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _openAddCustomerScreen() async {
    final result = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => const AddEditCustomerScreen(),
      ),
    );
    if (result != null && mounted) {
      _searchController.clear();
      _showSnackBar('Added new customer "${result.name}"');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _openEditCustomerScreen(Customer customer) async {
    final updated = await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => AddEditCustomerScreen(customerToEdit: customer),
      ),
    );
    if (updated != null && mounted) {
      _showSnackBar('Updated "${updated.name}" details');
    }
  }

  Future<void> _openCustomerDetailsScreen(Customer customer) async {
    await Navigator.of(context).push<Customer>(
      MaterialPageRoute<Customer>(
        builder: (_) => CustomerDetailsScreen(customer: customer),
      ),
    );
  }

  Future<void> _confirmDeleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Customer',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: _textDark),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${customer.name}" (${customer.shopName})? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500, color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteCustomer(customer.id);
        if (mounted) _showSnackBar('Deleted customer "${customer.name}"');
      } catch (e) {
        if (mounted) _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  List<Customer> _filterCustomers(List<Customer> all, String query) {
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase();
    return all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.shopName.toLowerCase().contains(q) ||
          c.mobile.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(
          widget.isSelectingCustomer ? 'Select Customer' : 'Customers',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        actions: [
          if (!widget.isSelectingCustomer)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _openAddCustomerScreen,
                icon: const Icon(Icons.add_rounded, color: _primaryRoyalBlue),
                tooltip: 'Add Customer',
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isSelectingCustomer
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddCustomerScreen,
              backgroundColor: _primaryRoyalBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: Text(
                'Add Customer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
                decoration: InputDecoration(
                  hintText: 'Search customer, shop or mobile...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _primaryRoyalBlue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: _primaryRoyalBlue, width: 1.8),
                  ),
                ),
              ),
            ),

            // List
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _repository.isLoading,
                builder: (context, isLoading, _) {
                  if (isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return ValueListenableBuilder<String?>(
                    valueListenable: _repository.errorMessage,
                    builder: (context, errorMsg, _) {
                      if (errorMsg != null) {
                        return _buildErrorState(errorMsg);
                      }

                      return ValueListenableBuilder<List<Customer>>(
                        valueListenable: _repository.customers,
                        builder: (context, allCustomers, _) {
                          final filtered = _filterCustomers(
                            allCustomers,
                            _searchController.text,
                          );

                          if (allCustomers.isEmpty) {
                            return _buildEmptyState();
                          }

                          if (filtered.isEmpty) {
                            return _buildNoResultsState(
                                _searchController.text);
                          }

                          return Column(
                            children: [
                              // Summary strip
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Total Customers: ${allCustomers.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.green.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade600,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'ERP Directory Active',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Customer list
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: _repository.fetchCustomers,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 100),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      return _CustomerCard(
                                        customer: filtered[index],
                                        isSelectingCustomer:
                                            widget.isSelectingCustomer,
                                        onTap: () {
                                          if (widget.isSelectingCustomer) {
                                            Navigator.of(context)
                                                .pop(filtered[index]);
                                          } else {
                                            _openCustomerDetailsScreen(
                                                filtered[index]);
                                          }
                                        },
                                        onEdit: () => _openEditCustomerScreen(
                                            filtered[index]),
                                        onDelete: () =>
                                            _confirmDeleteCustomer(
                                                filtered[index]),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No customers found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first customer to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 24),
            if (!widget.isSelectingCustomer)
              ElevatedButton.icon(
                onPressed: _openAddCustomerScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRoyalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.person_add_rounded),
                label: Text(
                  'Add Customer',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
              'Unable to load customers',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check server connection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _repository.fetchCustomers,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRoyalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer Card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.isSelectingCustomer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Customer customer;
  final bool isSelectingCustomer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _primaryRoyalBlue = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF102A43);
  static const Color _textSecondary = Color(0xFF627D98);

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'C';
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = customer.outstandingBalance > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _primaryRoyalBlue,
                child: Text(
                  _getInitials(customer.name),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 12, color: _primaryRoyalBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primaryRoyalBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          customer.mobile,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (hasOutstanding) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.orange.shade300, width: 0.8),
                        ),
                        child: Text(
                          'Due ₹${_formatAmount(customer.outstandingBalance)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              if (!isSelectingCustomer) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_rounded,
                      size: 18, color: Colors.blueGrey.shade400),
                  tooltip: 'Edit',
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red.shade400),
                  tooltip: 'Delete',
                ),
              ] else ...[
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
