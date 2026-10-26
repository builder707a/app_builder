import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EngineerVerificationScreen extends StatefulWidget {
  const EngineerVerificationScreen({super.key});

  @override
  State<EngineerVerificationScreen> createState() => _EngineerVerificationScreenState();
}

class _EngineerVerificationScreenState extends State<EngineerVerificationScreen> {
  String _selectedDuration = 'مدة شهر'; // 'مدة شهر', 'مدة 6 أشهر', 'مدة سنة'
  bool _isLoading = false;
  
  // أسعار افتراضية يتم جلبها من قاعدة البيانات
  double _price1M = 10.0;
  double _price6M = 50.0;
  double _price1Y = 90.0;

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('settings').doc('verification_fees').get();
      if (doc.exists && doc.data() != null) {
        var data = doc.data()!;
        setState(() {
          _price1M = (data['1m'] ?? 10.0).toDouble();
          _price6M = (data['6m'] ?? 50.0).toDouble();
          _price1Y = (data['1y'] ?? 90.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب الأسعار: $e');
    }
  }

  Future<void> _requestVerification() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. فحص هل الحساب موثق مسبقاً
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      bool isVerified = userDoc.exists ? (userDoc.data()?['isVerified'] ?? false) : false;

      if (isVerified) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ حسابك موثق بالفعل حالياً!'), backgroundColor: Colors.orange),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. فحص هل يوجد طلب معلق سابق قيد المراجعة
      var pendingQuery = await FirebaseFirestore.instance
          .collection('verification_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingQuery.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏳ لديك طلب توثيق قيد المراجعة بالفعل. يرجى انتظار رد الإدارة.'), backgroundColor: Colors.orange),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. إرسال طلب جديد
      String userName = userDoc.exists ? (userDoc.data()?['name'] ?? 'مكتب هندسي') : 'مكتب هندسي';
      
      await FirebaseFirestore.instance.collection('verification_requests').add({
        'userId': user.uid,
        'userName': userName,
        'email': user.email ?? '',
        'duration': _selectedDuration,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ تم تقديم طلب التوثيق بنجاح وهو قيد المراجعة من الإدارة.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء إرسال الطلب: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // حساب الأيام المتبقية للتوثيق
  Map<String, dynamic> _calculateRemainingTime(dynamic verifiedAtTimestamp, String duration) {
    if (verifiedAtTimestamp == null) return {'text': 'غير متوفر', 'progress': 0.0};
    
    DateTime verifiedDate;
    if (verifiedAtTimestamp is Timestamp) {
      verifiedDate = verifiedAtTimestamp.toDate();
    } else {
      return {'text': 'غير متوفر', 'progress': 0.0};
    }

    int totalDays = 30;
    if (duration.contains('6')) {
      totalDays = 180;
    } else if (duration.contains('سنة') || duration.contains('12')) {
      totalDays = 365;
    }

    DateTime expiryDate = verifiedDate.add(Duration(days: totalDays));
    int remainingDays = expiryDate.difference(DateTime.now()).inDays;

    if (remainingDays < 0) remainingDays = 0;
    double progress = 1.0 - (remainingDays / totalDays);
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    return {
      'text': remainingDays > 0 ? 'متبقي $remainingDays يوم على الانتهاء' : 'انتهت مدة التوثيق',
      'progress': progress,
      'expiryDate': '${expiryDate.year}/${expiryDate.month}/${expiryDate.day}'
    };
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('توثيق الحساب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: user == null
            ? const Center(child: Text('يرجى تسجيل الدخول أولاً'))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                  bool isVerified = userData['isVerified'] ?? false;
                  String duration = userData['verificationDuration'] ?? 'مدة شهر';
                  dynamic verifiedAt = userData['verifiedAt'];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // إذا كان الحساب موثقاً، اعرض العداد والمعلومات في المنتصف
                        if (isVerified) ...[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                              border: Border.all(color: Colors.green.shade200, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.verified_rounded, size: 60, color: Colors.blueAccent),
                                const SizedBox(height: 12),
                                const Text('حسابك موثق رسمياً ✓', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                const SizedBox(height: 6),
                                Text('المدة الحالية: $duration', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                                const SizedBox(height: 16),
                                Builder(
                                  builder: (context) {
                                    var timeInfo = _calculateRemainingTime(verifiedAt, duration);
                                    return Column(
                                      children: [
                                        LinearProgressIndicator(
                                          value: timeInfo['progress'],
                                          backgroundColor: Colors.grey.shade200,
                                          color: Colors.blueAccent,
                                          minHeight: 8,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(timeInfo['text'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                        const SizedBox(height: 4),
                                        Text('تاريخ انتهاء التوثيق: ${timeInfo['expiryDate'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // إذا لم يكن موثقاً، اعرض خيارات الباقات للاختيار
                          const Text('اختر باقة التوثيق المناسبة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(height: 16),

                          _buildDurationCard('مدة شهر', '$_price1M \$', Icons.calendar_today),
                          const SizedBox(height: 12),
                          _buildDurationCard('مدة 6 أشهر', '$_price6M \$', Icons.date_range),
                          const SizedBox(height: 12),
                          _buildDurationCard('مدة سنة', '$_price1Y \$', Icons.verified_user),
                          const SizedBox(height: 40),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _requestVerification,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 3,
                                  ),
                                  child: const Text('طلب توثيق الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDurationCard(String title, String price, IconData icon) {
    bool isSelected = _selectedDuration == title;

    return InkWell(
      onTap: () => setState(() => _selectedDuration = title),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: isSelected ? 0.08 : 0.03), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blueAccent : const Color(0xFF1E293B),
                ),
              ),
            ),
            Text(
              price,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(width: 16),
            Checkbox(
              value: isSelected,
              activeColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                if (val == true) setState(() => _selectedDuration = title);
              },
            ),
          ],
        ),
      ),
    );
  }
}