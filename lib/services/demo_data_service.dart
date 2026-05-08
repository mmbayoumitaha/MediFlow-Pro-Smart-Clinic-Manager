import 'package:uuid/uuid.dart';
import '../shared/enums/app_enums.dart';
import '../shared/models/app_models.dart';

/// Provides realistic demo data for offline-first development.
class DemoDataService {
  static const _uuid = Uuid();
  
  static final List<DoctorModel> doctors = [
    DoctorModel(id: 'doc-001', userId: 'u-doc-001', fullName: 'Dr. Ahmed Hassan', email: 'ahmed@mediflow.com', phone: '+201001234567', specialty: MedicalSpecialty.cardiology, bio: 'Board-certified cardiologist with 15 years of experience in interventional cardiology and heart failure management.', consultationFee: 350.0, experienceYears: 15, rating: 4.9, totalReviews: 234, isAvailable: true, createdAt: DateTime(2024, 1, 15), availability: [
      const AvailabilitySlot(day: DayOfWeek.sunday, startTime: '09:00', endTime: '15:00'),
      const AvailabilitySlot(day: DayOfWeek.tuesday, startTime: '09:00', endTime: '15:00'),
      const AvailabilitySlot(day: DayOfWeek.thursday, startTime: '09:00', endTime: '13:00'),
    ]),
    DoctorModel(id: 'doc-002', userId: 'u-doc-002', fullName: 'Dr. Sara Mohamed', email: 'sara@mediflow.com', phone: '+201009876543', specialty: MedicalSpecialty.dermatology, bio: 'Specialist in cosmetic dermatology, laser treatments, and skin cancer screening.', consultationFee: 300.0, experienceYears: 10, rating: 4.8, totalReviews: 189, isAvailable: true, createdAt: DateTime(2024, 2, 1), availability: [
      const AvailabilitySlot(day: DayOfWeek.monday, startTime: '10:00', endTime: '16:00'),
      const AvailabilitySlot(day: DayOfWeek.wednesday, startTime: '10:00', endTime: '16:00'),
    ]),
    DoctorModel(id: 'doc-003', userId: 'u-doc-003', fullName: 'Dr. Omar Khalil', email: 'omar@mediflow.com', phone: '+201112223344', specialty: MedicalSpecialty.orthopedics, bio: 'Expert in sports medicine, joint replacement, and minimally invasive surgery.', consultationFee: 400.0, experienceYears: 20, rating: 4.7, totalReviews: 312, isAvailable: true, createdAt: DateTime(2024, 1, 10), availability: [
      const AvailabilitySlot(day: DayOfWeek.sunday, startTime: '08:00', endTime: '14:00'),
      const AvailabilitySlot(day: DayOfWeek.wednesday, startTime: '08:00', endTime: '14:00'),
    ]),
    DoctorModel(id: 'doc-004', userId: 'u-doc-004', fullName: 'Dr. Fatima Ali', email: 'fatima@mediflow.com', phone: '+201223334455', specialty: MedicalSpecialty.pediatrics, bio: 'Pediatric specialist focusing on newborn care and childhood developmental disorders.', consultationFee: 250.0, experienceYears: 12, rating: 4.9, totalReviews: 456, isAvailable: true, createdAt: DateTime(2024, 3, 5), availability: [
      const AvailabilitySlot(day: DayOfWeek.sunday, startTime: '09:00', endTime: '17:00'),
      const AvailabilitySlot(day: DayOfWeek.monday, startTime: '09:00', endTime: '17:00'),
      const AvailabilitySlot(day: DayOfWeek.tuesday, startTime: '09:00', endTime: '17:00'),
    ]),
    DoctorModel(id: 'doc-005', userId: 'u-doc-005', fullName: 'Dr. Youssef Nabil', email: 'youssef@mediflow.com', phone: '+201334445566', specialty: MedicalSpecialty.neurology, bio: 'Neurologist specialized in epilepsy, stroke, and neurodegenerative diseases.', consultationFee: 450.0, experienceYears: 18, rating: 4.6, totalReviews: 178, isAvailable: true, createdAt: DateTime(2024, 2, 20), availability: [
      const AvailabilitySlot(day: DayOfWeek.monday, startTime: '08:00', endTime: '14:00'),
      const AvailabilitySlot(day: DayOfWeek.thursday, startTime: '08:00', endTime: '14:00'),
    ]),
    DoctorModel(id: 'doc-006', userId: 'u-doc-006', fullName: 'Dr. Nora Ibrahim', email: 'nora@mediflow.com', phone: '+201445556677', specialty: MedicalSpecialty.gynecology, bio: 'OB/GYN specialist with expertise in high-risk pregnancies and fertility treatments.', consultationFee: 350.0, experienceYears: 14, rating: 4.8, totalReviews: 267, isAvailable: true, createdAt: DateTime(2024, 1, 25), availability: [
      const AvailabilitySlot(day: DayOfWeek.sunday, startTime: '10:00', endTime: '16:00'),
      const AvailabilitySlot(day: DayOfWeek.tuesday, startTime: '10:00', endTime: '16:00'),
      const AvailabilitySlot(day: DayOfWeek.thursday, startTime: '10:00', endTime: '14:00'),
    ]),
  ];

  static List<AppointmentModel> generateAppointments() {
    final now = DateTime.now();
    return [
      AppointmentModel(id: 'apt-001', patientId: 'pat-001', patientName: 'Mariam Saeed', doctorId: 'doc-001', doctorName: 'Dr. Ahmed Hassan', specialty: MedicalSpecialty.cardiology, dateTime: now.add(const Duration(days: 1, hours: 2)), status: AppointmentStatus.confirmed, reason: 'Routine heart checkup', fee: 350.0, paymentStatus: PaymentStatus.paid, createdAt: now.subtract(const Duration(days: 3)), updatedAt: now.subtract(const Duration(days: 2))),
      AppointmentModel(id: 'apt-002', patientId: 'pat-002', patientName: 'Hassan Tarek', doctorId: 'doc-003', doctorName: 'Dr. Omar Khalil', specialty: MedicalSpecialty.orthopedics, dateTime: now.add(const Duration(days: 2, hours: 4)), status: AppointmentStatus.pending, reason: 'Knee pain follow-up', fee: 400.0, paymentStatus: PaymentStatus.unpaid, createdAt: now.subtract(const Duration(days: 1)), updatedAt: now.subtract(const Duration(days: 1))),
      AppointmentModel(id: 'apt-003', patientId: 'pat-003', patientName: 'Layla Mahmoud', doctorId: 'doc-004', doctorName: 'Dr. Fatima Ali', specialty: MedicalSpecialty.pediatrics, dateTime: now.subtract(const Duration(days: 1, hours: 3)), status: AppointmentStatus.completed, reason: 'Child vaccination', fee: 250.0, paymentStatus: PaymentStatus.paid, createdAt: now.subtract(const Duration(days: 5)), updatedAt: now.subtract(const Duration(days: 1))),
      AppointmentModel(id: 'apt-004', patientId: 'pat-001', patientName: 'Mariam Saeed', doctorId: 'doc-002', doctorName: 'Dr. Sara Mohamed', specialty: MedicalSpecialty.dermatology, dateTime: now.add(const Duration(days: 3, hours: 1)), status: AppointmentStatus.confirmed, reason: 'Skin allergy treatment', fee: 300.0, paymentStatus: PaymentStatus.paid, createdAt: now.subtract(const Duration(days: 2)), updatedAt: now),
      AppointmentModel(id: 'apt-005', patientId: 'pat-004', patientName: 'Khaled Nasser', doctorId: 'doc-005', doctorName: 'Dr. Youssef Nabil', specialty: MedicalSpecialty.neurology, dateTime: now.subtract(const Duration(days: 3, hours: 5)), status: AppointmentStatus.completed, reason: 'Migraine assessment', fee: 450.0, paymentStatus: PaymentStatus.paid, createdAt: now.subtract(const Duration(days: 7)), updatedAt: now.subtract(const Duration(days: 3))),
      AppointmentModel(id: 'apt-006', patientId: 'pat-005', patientName: 'Dina Fathy', doctorId: 'doc-006', doctorName: 'Dr. Nora Ibrahim', specialty: MedicalSpecialty.gynecology, dateTime: now.add(const Duration(days: 5)), status: AppointmentStatus.pending, reason: 'Regular checkup', fee: 350.0, paymentStatus: PaymentStatus.unpaid, createdAt: now, updatedAt: now),
      AppointmentModel(id: 'apt-007', patientId: 'pat-002', patientName: 'Hassan Tarek', doctorId: 'doc-001', doctorName: 'Dr. Ahmed Hassan', specialty: MedicalSpecialty.cardiology, dateTime: now.subtract(const Duration(days: 10)), status: AppointmentStatus.completed, reason: 'ECG Follow-up', fee: 350.0, paymentStatus: PaymentStatus.paid, createdAt: now.subtract(const Duration(days: 14)), updatedAt: now.subtract(const Duration(days: 10))),
      AppointmentModel(id: 'apt-008', patientId: 'pat-003', patientName: 'Layla Mahmoud', doctorId: 'doc-002', doctorName: 'Dr. Sara Mohamed', specialty: MedicalSpecialty.dermatology, dateTime: now.add(const Duration(hours: 5)), status: AppointmentStatus.confirmed, reason: 'Acne treatment session', fee: 300.0, paymentStatus: PaymentStatus.paid, createdAt: now.subtract(const Duration(days: 4)), updatedAt: now),
    ];
  }

  static List<PrescriptionModel> generatePrescriptions() {
    final now = DateTime.now();
    return [
      PrescriptionModel(id: 'presc-001', appointmentId: 'apt-003', patientId: 'pat-003', patientName: 'Layla Mahmoud', doctorId: 'doc-004', doctorName: 'Dr. Fatima Ali', diagnosis: 'Upper respiratory tract infection', medications: [
        const MedicationItem(name: 'Amoxicillin', dosage: '500mg', frequency: '3 times daily', durationDays: 7, instructions: 'Take after meals'),
        const MedicationItem(name: 'Paracetamol', dosage: '250mg', frequency: 'Every 6 hours as needed', durationDays: 5, instructions: 'For fever above 38°C'),
      ], notes: 'Follow up in one week if symptoms persist.', prescribedDate: now.subtract(const Duration(days: 1)), createdAt: now.subtract(const Duration(days: 1))),
      PrescriptionModel(id: 'presc-002', appointmentId: 'apt-005', patientId: 'pat-004', patientName: 'Khaled Nasser', doctorId: 'doc-005', doctorName: 'Dr. Youssef Nabil', diagnosis: 'Chronic migraine with aura', medications: [
        const MedicationItem(name: 'Sumatriptan', dosage: '50mg', frequency: 'At onset of migraine', durationDays: 30, instructions: 'Do not exceed 2 doses in 24 hours'),
        const MedicationItem(name: 'Topiramate', dosage: '25mg', frequency: 'Once daily at bedtime', durationDays: 90, instructions: 'Preventive therapy, do not stop abruptly'),
      ], notes: 'MRI brain ordered. Avoid known triggers.', prescribedDate: now.subtract(const Duration(days: 3)), createdAt: now.subtract(const Duration(days: 3))),
    ];
  }

  static List<InvoiceModel> generateInvoices() {
    final now = DateTime.now();
    return [
      InvoiceModel(id: 'inv-001', patientId: 'pat-001', patientName: 'Mariam Saeed', appointmentId: 'apt-001', items: [const InvoiceItem(description: 'Cardiology Consultation', unitPrice: 350.0, total: 350.0), const InvoiceItem(description: 'ECG Test', unitPrice: 150.0, total: 150.0)], subtotal: 500.0, tax: 70.0, total: 570.0, paymentStatus: PaymentStatus.paid, paymentMethod: 'Credit Card', issuedDate: now.subtract(const Duration(days: 2)), paidDate: now.subtract(const Duration(days: 2)), createdAt: now.subtract(const Duration(days: 2))),
      InvoiceModel(id: 'inv-002', patientId: 'pat-002', patientName: 'Hassan Tarek', appointmentId: 'apt-002', items: [const InvoiceItem(description: 'Orthopedics Consultation', unitPrice: 400.0, total: 400.0), const InvoiceItem(description: 'X-Ray (Knee)', unitPrice: 200.0, total: 200.0)], subtotal: 600.0, tax: 84.0, total: 684.0, paymentStatus: PaymentStatus.unpaid, issuedDate: now.subtract(const Duration(days: 1)), createdAt: now.subtract(const Duration(days: 1))),
      InvoiceModel(id: 'inv-003', patientId: 'pat-004', patientName: 'Khaled Nasser', appointmentId: 'apt-005', items: [const InvoiceItem(description: 'Neurology Consultation', unitPrice: 450.0, total: 450.0)], subtotal: 450.0, tax: 63.0, total: 513.0, paymentStatus: PaymentStatus.paid, paymentMethod: 'Cash', issuedDate: now.subtract(const Duration(days: 3)), paidDate: now.subtract(const Duration(days: 3)), createdAt: now.subtract(const Duration(days: 3))),
    ];
  }

  static List<UserModel> generatePatients() {
    final now = DateTime.now();
    return [
      UserModel(id: 'pat-001', email: 'mariam@email.com', fullName: 'Mariam Saeed', phone: '+201551112233', role: UserRole.patient, gender: Gender.female, dateOfBirth: DateTime(1990, 5, 15), address: 'Cairo, Nasr City', createdAt: now.subtract(const Duration(days: 120)), updatedAt: now),
      UserModel(id: 'pat-002', email: 'hassan@email.com', fullName: 'Hassan Tarek', phone: '+201552223344', role: UserRole.patient, gender: Gender.male, dateOfBirth: DateTime(1985, 8, 22), address: 'Cairo, Heliopolis', createdAt: now.subtract(const Duration(days: 90)), updatedAt: now),
      UserModel(id: 'pat-003', email: 'layla@email.com', fullName: 'Layla Mahmoud', phone: '+201553334455', role: UserRole.patient, gender: Gender.female, dateOfBirth: DateTime(2018, 3, 10), address: 'Giza, Dokki', createdAt: now.subtract(const Duration(days: 60)), updatedAt: now),
      UserModel(id: 'pat-004', email: 'khaled@email.com', fullName: 'Khaled Nasser', phone: '+201554445566', role: UserRole.patient, gender: Gender.male, dateOfBirth: DateTime(1978, 11, 5), address: 'Alexandria', createdAt: now.subtract(const Duration(days: 45)), updatedAt: now),
      UserModel(id: 'pat-005', email: 'dina@email.com', fullName: 'Dina Fathy', phone: '+201555556677', role: UserRole.patient, gender: Gender.female, dateOfBirth: DateTime(1995, 7, 20), address: 'Cairo, Maadi', createdAt: now.subtract(const Duration(days: 30)), updatedAt: now),
    ];
  }
}
