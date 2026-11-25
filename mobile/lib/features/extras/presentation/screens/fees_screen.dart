import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/extras/presentation/cubit/extras_cubit.dart';
import 'package:lms/features/extras/presentation/widgets/receipt_download.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key, this.drawer});

  final Widget? drawer;

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData({bool force = false}) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final currentTxns = context.read<ExtrasCubit>().state.transactions;
    if (force || currentTxns.isEmpty) {
      context.read<ExtrasCubit>().loadTransactions(token);
    }
  }

  String _formatDateTime12Hr(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[local.month - 1];
    final year = local.year;

    final hour24 = local.hour;
    final hour12 = (hour24 % 12 == 0) ? 12 : hour24 % 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = local.minute.toString().padLeft(2, '0');
    final secStr = local.second.toString().padLeft(2, '0');
    final amPm = hour24 >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hourStr:$minStr:$secStr $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Transactions & Fees',
      showAppBar: true,
      drawer: widget.drawer,
      onRefresh: () async => _loadData(force: true),
      body: BlocBuilder<ExtrasCubit, ExtrasState>(
        builder: (context, state) {
          if (state.status == ExtrasStatus.loading &&
              state.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.error!,
                    style: const TextStyle(color: AppTheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredTxns = state.transactions.where((txn) {
            if (_searchQuery.trim().isEmpty) return true;
            final q = _searchQuery.trim().toLowerCase();
            return txn.batchName.toLowerCase().contains(q) ||
                txn.courseName.toLowerCase().contains(q) ||
                txn.transactionId.toLowerCase().contains(q) ||
                txn.paymentMethod.toLowerCase().contains(q) ||
                txn.status.toLowerCase().contains(q) ||
                txn.amountPaid.toString().contains(q);
          }).toList();

          if (state.transactions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No transaction records found.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your course purchase receipts will appear here.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            itemCount: 1 + (filteredTxns.isEmpty ? 1 : filteredTxns.length),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search batch, course, TXN ID or amount...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                );
              }

              if (filteredTxns.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching transactions for "$_searchQuery"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final txn = filteredTxns[index - 1];
              final isSuccess = txn.status == 'SUCCESS' || txn.status == 'PAID';
              final isFailed = txn.status == 'FAILED';

              final statusColor = isSuccess
                  ? AppTheme.success
                  : (isFailed ? AppTheme.error : Colors.amber.shade700);

              return SectionCard(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Batch Name & Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF1E1B4B,
                                    ).withValues(alpha: 0.5)
                                  : Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.indigo.shade800
                                    : Colors.indigo.shade100,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.layers_rounded,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    txn.batchName,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.indigo.shade200
                                          : Colors.indigo.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSuccess
                                    ? Icons.check_circle_rounded
                                    : (isFailed
                                          ? Icons.cancel_rounded
                                          : Icons.schedule_rounded),
                                size: 13,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                txn.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Amount Paid / Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount Paid:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '₹ ${txn.amountPaid.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Transaction ID & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.transactionId,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Via ${txn.paymentMethod}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (txn.createdAt != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDateTime12Hr(txn.createdAt),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (txn.hasReceipt) ...[
                      const SizedBox(height: 14),
                      ReceiptDownloadButton(
                        key: ValueKey('receipt-${txn.id}'),
                        transaction: txn,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
