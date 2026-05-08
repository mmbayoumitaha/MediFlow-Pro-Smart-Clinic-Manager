import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../shared/models/app_models.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});
  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  DoctorModel? _selectedDoctor;
  DateTime? _selectedDate;
  String? _selectedTime;
  final _reasonCtrl = TextEditingController();
  final _times = ['09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM', '01:00 PM', '01:30 PM', '02:00 PM', '02:30 PM', '03:00 PM'];

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  void _book() {
    if (_selectedDoctor == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    final user = ref.read(authProvider).currentUser!;
    final now = DateTime.now();
    final apt = AppointmentModel(
      id: const Uuid().v4(), patientId: user.id, patientName: user.fullName,
      doctorId: _selectedDoctor!.id, doctorName: _selectedDoctor!.fullName,
      specialty: _selectedDoctor!.specialty, dateTime: _selectedDate!,
      status: AppointmentStatus.pending, reason: _reasonCtrl.text,
      fee: _selectedDoctor!.consultationFee, createdAt: now, updatedAt: now,
    );
    ref.read(appointmentsProvider.notifier).update((s) => [apt, ...s]);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Appointment booked successfully!'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Step 1: Choose Doctor
          Text('Select Doctor', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: doctors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final doc = doctors[i];
                final sel = _selectedDoctor?.id == doc.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDoctor = doc),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 100, padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withValues(alpha: 0.1) : (isDark ? AppColors.darkCard : AppColors.lightCard),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(color: sel ? AppColors.primary : (isDark ? AppColors.darkDivider : AppColors.lightDivider), width: sel ? 2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(doc.specialty.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(doc.fullName.split(' ').last, style: theme.textTheme.labelMedium, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                      Text(doc.specialty.labelEn, style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                    ]),
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
              itemCount: 14,
              itemBuilder: (ctx, i) {
                final date = DateTime.now().add(Duration(days: i + 1));
                final sel = _selectedDate != null && _selectedDate!.day == date.day && _selectedDate!.month == date.month;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : (isDark ? AppColors.darkCard : AppColors.lightCard),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(color: sel ? AppColors.primary : (isDark ? AppColors.darkDivider : AppColors.lightDivider)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(DateFormat('EEE').format(date), style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : AppColors.slate500)),
                      Text('${date.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: sel ? Colors.white : null)),
                      Text(DateFormat('MMM').format(date), style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : AppColors.slate500)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Step 3: Select Time
          Text('Select Time', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _times.map((t) {
            final sel = _selectedTime == t;
            return ChoiceChip(label: Text(t), selected: sel, onSelected: (_) => setState(() => _selectedTime = t),
              selectedColor: AppColors.primaryContainer,
              labelStyle: TextStyle(fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? AppColors.primary : null),
            );
          }).toList()),
          const SizedBox(height: 24),

          // Reason
          Text('Reason (optional)', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(controller: _reasonCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe your symptoms...')),
          const SizedBox(height: 32),

          // Summary & Book
          if (_selectedDoctor != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(color: AppColors.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('Consultation fee: \$${_selectedDoctor!.consultationFee.toStringAsFixed(0)}', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary))),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(onPressed: _book, icon: const Icon(Icons.check_circle_outline), label: const Text('Confirm Booking'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
