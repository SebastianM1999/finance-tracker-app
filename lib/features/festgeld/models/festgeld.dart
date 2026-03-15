import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/number_utils.dart';

class Festgeld {
  const Festgeld({
    required this.id,
    required this.bankName,
    required this.amount,
    required this.interestRate,
    required this.startDate,
    required this.durationMonths,
    required this.endDate,
    required this.projectedPayout,
    this.notes,
    this.notificationsEnabled = true,
    this.notifiedDays = const [],
    this.scheduledNotificationIds = const [],
    required this.createdAt,
  });

  final String id;
  final String bankName;
  final double amount;
  final double interestRate;
  final DateTime startDate;
  final int durationMonths;
  final DateTime endDate;
  final double projectedPayout;
  final String? notes;
  final bool notificationsEnabled;
  final List<int> notifiedDays;
  final List<int> scheduledNotificationIds;
  final DateTime createdAt;

  double get progress => NumberUtils.calcFestgeldProgress(startDate, endDate);

  int get daysRemaining => endDate.difference(DateTime.now()).inDays;

  factory Festgeld.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Festgeld(
      id: doc.id,
      bankName: d['bankName'] as String,
      amount: (d['amount'] as num).toDouble(),
      interestRate: (d['interestRate'] as num).toDouble(),
      startDate: (d['startDate'] as Timestamp).toDate(),
      durationMonths: d['durationMonths'] as int,
      endDate: (d['endDate'] as Timestamp).toDate(),
      projectedPayout: (d['projectedPayout'] as num).toDouble(),
      notes: d['notes'] as String?,
      notificationsEnabled: d['notificationsEnabled'] as bool? ?? true,
      notifiedDays: List<int>.from(d['notifiedDays'] as List? ?? []),
      scheduledNotificationIds:
          List<int>.from(d['scheduledNotificationIds'] as List? ?? []),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'bankName': bankName,
        'amount': amount,
        'interestRate': interestRate,
        'startDate': Timestamp.fromDate(startDate),
        'durationMonths': durationMonths,
        'endDate': Timestamp.fromDate(endDate),
        'projectedPayout': projectedPayout,
        'notes': notes,
        'notificationsEnabled': notificationsEnabled,
        'notifiedDays': notifiedDays,
        'scheduledNotificationIds': scheduledNotificationIds,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
