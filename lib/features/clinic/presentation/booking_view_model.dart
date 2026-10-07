import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/book_appointment.dart';
import '../domain/clinic_failure.dart';
import '../domain/entities.dart';

class BookingState {
  final bool isSubmitting;
  final String? error;
  final Appointment? appointment;

  const BookingState({this.isSubmitting = false, this.error, this.appointment});
}

class BookingViewModel extends StateNotifier<BookingState> {
  final BookAppointment _book;
  final ClinicUser? Function() _currentUser;
  String? _requestId;
  (String, DateTime, String?)? _selection;

  BookingViewModel(this._book, this._currentUser) : super(const BookingState());

  Future<bool> book({
    required String doctorId,
    required DateTime dateTime,
    String? reason,
  }) async {
    if (!mounted || state.isSubmitting) return false;
    final normalizedReason = reason?.trim();
    final selection = (
      doctorId,
      dateTime,
      normalizedReason == '' ? null : normalizedReason,
    );
    if (_selection == selection && state.appointment != null) return true;
    if (_selection != selection) {
      _selection = selection;
      _requestId = _book.newId();
    }
    state = const BookingState(isSubmitting: true);
    try {
      final appointment = await _book(
        patient: _currentUser(),
        doctorId: doctorId,
        dateTime: dateTime,
        reason: reason,
        requestId: _requestId,
      );
      if (!mounted) return false;
      state = BookingState(appointment: appointment);
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = BookingState(
        error: error is ClinicFailure
            ? error.message
            : 'Could not book the appointment. Please try again.',
      );
      return false;
    }
  }
}
