import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/local_customer_repository.dart';
import '../theme/app_theme.dart';
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
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
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
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Customer',
              style: TextStyle(fontFamily: 'Poppins', 
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${customer.name}" (${customer.shopName})? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
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
          widget.isSelectingCustomer ? 'Select Customer' : 'Customers',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (!widget.isSelectingCustomer)
            TextButton.icon(
              onPressed: _openAddCustomerScreen,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      floatingActionButton: widget.isSelectingCustomer
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddCustomerScreen,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: Text(
                'Add Customer',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search customer, shop or mobile...',
                    hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
              ),
            ),

            // ── Customer List & Summary ──────────────────────────────────
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _repository.isLoading,
                builder: (context, isLoading, _) {
                  if (isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                            return _buildNoResultsState(_searchController.text);
                          }

                          return Column(
                            children: [
                              // Compact Summary Row
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Total Customers: ${allCustomers.length}',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppColors.success,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'ERP Directory Active',
                                            style: TextStyle(fontFamily: 'Poppins', 
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Customer Cards List
                              Expanded(
                                child: RefreshIndicator(
                                  color: AppColors.primary,
                                  onRefresh: _repository.fetchCustomers,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                                    itemCount: filtered.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final customer = filtered[index];
                                      return _CustomerCard(
                                        customer: customer,
                                        isSelectingCustomer: widget.isSelectingCustomer,
                                        onTap: () {
                                          if (widget.isSelectingCustomer) {
                                            Navigator.of(context).pop(customer);
                                          } else {
                                            _openCustomerDetailsScreen(customer);
                                          }
                                        },
                                        onEdit: () => _openEditCustomerScreen(customer),
                                        onDelete: () => _confirmDeleteCustomer(customer),
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Customers Registered',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your wholesale footwear retailers to start billing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (!widget.isSelectingCustomer)
              FilledButton.icon(
                onPressed: _openAddCustomerScreen,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(
                  'Add First Customer',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
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
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 30, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              'No Customers Match "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Check name, shop name, or phone number.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 30, color: AppColors.error),
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to Load Customers',
              style: TextStyle(fontFamily: 'Poppins', 
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please check server connection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _repository.fetchCustomers,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer Card (Mobile-First, Shared POS Design) ─────────────────────────

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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'C';
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = customer.outstandingBalance > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: Customer avatar with initials
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _getInitials(customer.name),
                    style: TextStyle(fontFamily: 'Poppins', 
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // CENTER: Name, Shop, Mobile, Due
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.shopName.isNotEmpty ? customer.shopName : 'Independent Retailer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            customer.mobile,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (hasOutstanding) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            'Due: ₹${_formatAmount(customer.outstandingBalance)}',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // RIGHT: Actions
                if (isSelectingCustomer) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                  ),
                ] else ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    tooltip: 'Edit Customer',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    tooltip: 'Delete Customer',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
