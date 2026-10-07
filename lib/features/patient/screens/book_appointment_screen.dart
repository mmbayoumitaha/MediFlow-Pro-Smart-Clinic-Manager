import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';

import 'package:intl/intl.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  final String? doctorId;
  const BookAppointmentScreen({super.key, this.doctorId});
  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  String? _doctorId;
  DateTime? _selectedDate;
  DateTime? _selectedTime;
  final _reasonCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _doctorId = widget.doctorId;
  }

  @override
  void didUpdateWidget(covariant BookAppointmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctorId != widget.doctorId) {
      _doctorId = widget.doctorId;
      _selectedTime = null;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_doctorId == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    final booked = await ref
        .read(bookingProvider.notifier)
        .book(
          doctorId: _doctorId!,
          dateTime: _selectedTime!,
          reason: _reasonCtrl.text,
        );
    if (!mounted) return;
    if (!booked) {
      final error = ref.read(bookingProvider).error;
      await ref.read(clinicViewModelProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Booking is already in progress.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Appointment booked successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    context.go('/patient/appointments');
  }

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsProvider);
    final booking = ref.watch(bookingProvider);
    final dates = ref.watch(bookingDateOptionsProvider);
    final matches = doctors.where((d) => d.id == _doctorId);
    final selectedDoctor = matches.length == 1 ? matches.single : null;
    final times = selectedDoctor != null && dates.contains(_selectedDate)
        ? ref.watch(
            bookingSlotsProvider((
              doctorId: selectedDoctor.id,
              date: _selectedDate!,
            )),
          )
        : const <DateTime>[];
    final validTime = times.contains(_selectedTime);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/patient/doctors');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step 1: Choose Doctor
            Text('Select Doctor', style: theme.textTheme.titleLarge),
            if (_doctorId != null && selectedDoctor == null)
              const Text(
                'This doctor no longer exists. Choose another doctor.',
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: doctors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final doc = doctors[i];
                  final sel = _doctorId == doc.id;
                  return GestureDetector(
                    onTap: booking.isSubmitting || !doc.isAvailable
                        ? null
                        : () => setState(() {
                            _doctorId = doc.id;
                            _selectedTime = null;
                          }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 100,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : (isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkDivider
                                    : AppColors.lightDivider),
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            doc.specialty.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            doc.fullName.split(' ').last,
                            style: theme.textTheme.labelMedium,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            doc.isAvailable
                                ? doc.specialty.labelEn
                                : 'Unavailable',
                            style: theme.textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Step 2: Select Date
            Text('Select Date', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: dates.length,
                itemBuilder: (ctx, i) {
                  final date = dates[i];
                  final sel = _selectedDate == date;
                  return GestureDetector(
                    key: ValueKey(date),
                    onTap: booking.isSubmitting
                        ? null
                        : () => setState(() {
                            _selectedDate = date;
                            _selectedTime = null;
                          }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkDivider
                                    : AppColors.lightDivider),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: sel ? Colors.white70 : AppColors.slate500,
                            ),
                          ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : null,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: sel ? Colors.white70 : AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Step 3: Select Time
            Text('Select Time', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (selectedDoctor == null || _selectedDate == null)
              const Text('Select a doctor and date to see available times.')
            else if (times.isEmpty)
              const Text(
                'No available times on this date. Choose another date or doctor.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: times.map((t) {
                final sel = _selectedTime == t;
                return ChoiceChip(
                  key: ValueKey(t),
                  label: Text(DateFormat('hh:mm a').format(t)),
                  selected: sel,
                  onSelected: booking.isSubmitting
                      ? null
                      : (_) => setState(() => _selectedTime = t),
                  selectedColor: AppColors.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? AppColors.primary : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Reason
            Text('Reason (optional)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            TextField(
              enabled: !booking.isSubmitting,
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe your symptoms...',
              ),
            ),
            const SizedBox(height: 32),

            // Summary & Book
            if (selectedDoctor != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Consultation fee: \$${selectedDoctor.consultationFee.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: booking.isSubmitting || !validTime ? null : _book,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                booking.isSubmitting ? 'Booking...' : 'Confirm Booking',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
