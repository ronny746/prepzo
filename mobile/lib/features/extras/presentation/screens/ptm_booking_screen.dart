import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/core/widgets/section_card.dart';
import 'package:lms/features/extras/presentation/cubit/extras_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';

class PtmBookingScreen extends StatefulWidget {
  const PtmBookingScreen({super.key, this.drawer});
  
  final Widget? drawer;

  @override
  State<PtmBookingScreen> createState() => _PtmBookingScreenState();
}

class _PtmBookingScreenState extends State<PtmBookingScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ExtrasCubit>().loadPtmData(token);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'PTM Booking',
      showAppBar: true,
      drawer: widget.drawer,
      body: BlocBuilder<ExtrasCubit, ExtrasState>(
        builder: (context, state) {
          if (state.status == ExtrasStatus.loading && state.ptmSlots.isEmpty && state.ptmBookings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(child: Text(state.error!, style: const TextStyle(color: AppTheme.error)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (state.ptmBookings.isEmpty)
                  const Text('No bookings yet.', style: TextStyle(color: Colors.grey))
                else
                  ...state.ptmBookings.map((b) => SectionCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.success,
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                            title: Text('Date: ${b['date'] ?? 'TBA'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Time: ${b['startTime'] ?? ''} - ${b['endTime'] ?? ''}\nTeacher: ${b['teacherId']?['name'] ?? 'Assigned Teacher'}'),
                          ),
                        ),
                      )),
                const SizedBox(height: 24),
                const Text('Available Slots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (state.ptmSlots.isEmpty)
                  const Text('No slots available at this time.', style: TextStyle(color: Colors.grey))
                else
                  ...state.ptmSlots.map((slot) => SectionCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${slot['date'] ?? 'TBA'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Time: ${slot['startTime'] ?? ''} - ${slot['endTime'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
                                  context.read<ExtrasCubit>().bookPtmSlot(token, slot['_id'] ?? slot['id'], {});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking request sent')));
                                },
                                child: const Text('Book Slot'),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}
