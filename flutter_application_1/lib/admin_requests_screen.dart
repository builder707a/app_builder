import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminVerificationRequestsScreen extends StatefulWidget {
  const AdminVerificationRequestsScreen({super.key});

  @override
  State<AdminVerificationRequestsScreen> createState() => _AdminVerificationRequestsScreenState();
}

class _AdminVerificationRequestsScreenState extends State<AdminVerificationRequestsScreen> {
  final TextEditingController _price1MController = TextEditingController(text: '10');
  final TextEditingController _price6MController = TextEditingController(text: '50');
  final TextEditingController _price1YController = TextEditingController(text: '90');

  bool _isLoadingPrices = false;

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
          _price1MController.text = (data['1m'] ?? 10).toString();
          _price6MController.text = (data['6m'] ?? 50).toString();
          _price1YController.text = (data['1y'] ?? 90).toString();
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب الأسعار: $e');
    }
  }

  Future<void> _savePrices() async {
    setState(() => _isLoadingPrices = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('verification_fees').set({
        '1m': double.tryParse(_price1MController.text) ?? 10.0,
        '6m': double.tryParse(_price6MController.text) ?? 50.0,
        '1y': double.tryParse(_price1YController.text) ?? 90.0,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ أسعار التوثيق بنجاح ✓'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  // الموافقة على الطلب مع رسالة تأكيد وخصم الرصيد بعد الموافقة فقط
  Future<void> _approveRequest(BuildContext context, String requestId, String userId, String duration) async {
    double price = 10.0;
    if (duration.contains('6')) {
      price = double.tryParse(_price6MController.text) ?? 50.0;
    } else if (duration.contains('سنة') || duration.contains('12')) {
      price = double.tryParse(_price1YController.text) ?? 90.0;
    } else {
      price = double.tryParse(_price1MController.text) ?? 10.0;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد توثيق الحساب'),
        content: Text('هل أنت متأكد من الموافقة على توثيق هذا الحساب لمدة ($duration)؟\n\nسيتم خصم مبلغ ($price \$) من رصيد المستخدم فور الموافقة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد الموافقة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) throw 'المستخدم غير موجود';

      double currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
      if (currentBalance < price) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('رصيد المستخدم الحالي ($currentBalance \$) غير كافٍ لدفع رسوم التوثيق ($price \$).'), backgroundColor: Colors.red),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isVerified': true,
        'verificationDuration': duration,
        'verifiedAt': FieldValue.serverTimestamp(),
        'balance': currentBalance - price,
      });

      await FirebaseFirestore.instance.collection('verification_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'costCharged': price,
      });

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم توثيق الحساب بنجاح وتم خصم $price \$ من رصيد المستخدم ✓'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء اعتماد التوثيق: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // إلغاء طلب التوثيق المعلق
  Future<void> _cancelRequest(BuildContext context, String requestId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء طلب التوثيق'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب وحذفه؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('verification_requests').doc(requestId).delete();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء طلب التوثيق بنجاح'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // إلغاء التوثيق لحساب موثق مسبقاً
  Future<void> _revokeVerification(BuildContext context, String userId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء توثيق الحساب'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء توثيق هذا الحساب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إلغاء التوثيق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isVerified': false,
        'verificationDuration': FieldValue.delete(),
        'verifiedAt': FieldValue.delete(),
      });

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء توثيق الحساب بنجاح'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // تعديل مدة التوثيق لكل مستخدم
  Future<void> _editDurationDialog(BuildContext context, String userId, String currentDuration) async {
    String selectedDuration = currentDuration.isNotEmpty ? currentDuration : 'مدة شهر';

    bool confirm = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل مدة التوثيق'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر المدة الجديدة للتوثيق:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedDuration,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: const [
                  DropdownMenuItem(value: 'مدة شهر', child: Text('مدة شهر')),
                  DropdownMenuItem(value: 'مدة 6 أشهر', child: Text('مدة 6 أشهر')),
                  DropdownMenuItem(value: 'مدة سنة', child: Text('مدة سنة')),
                ],
                onChanged: (val) {
                  if (val != null) setStateDialog(() => selectedDuration = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (!confirm) return;

    double newPrice = 10.0;
    if (selectedDuration.contains('6')) {
      newPrice = double.tryParse(_price6MController.text) ?? 50.0;
    } else if (selectedDuration.contains('سنة')) {
      newPrice = double.tryParse(_price1YController.text) ?? 90.0;
    } else {
      newPrice = double.tryParse(_price1MController.text) ?? 10.0;
    }

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      double currentBalance = userDoc.exists ? (userDoc.data()?['balance'] ?? 0.0).toDouble() : 0.0;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'verificationDuration': selectedDuration,
        'verifiedAt': FieldValue.serverTimestamp(), // تحديث وقت التوثيق عند تعديل المدة
        'balance': currentBalance >= newPrice ? currentBalance - newPrice : 0.0,
      });

      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تعديل المدة إلى ($selectedDuration) وخصم الرسوم ($newPrice \$) ✓'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعديل: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'غير متوفر';
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      return '${dt.year}/${dt.month}/${dt.day}';
    }
    return timestamp.toString();
  }

  // حساب الأيام المتبقية لانتهاء التوثيق
  String _getRemainingDaysText(dynamic verifiedAtTimestamp, String duration) {
    if (verifiedAtTimestamp == null) return 'المدة المتبقية: غير متوفرة';
    
    DateTime verifiedDate;
    if (verifiedAtTimestamp is Timestamp) {
      verifiedDate = verifiedAtTimestamp.toDate();
    } else {
      return 'المدة المتبقية: غير متوفرة';
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
    return remainingDays > 0 ? '⏳ متبقي $remainingDays يوم على الانتهاء' : '⚠️ انتهت مدة التوثيق';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('طلبات التوثيق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // قسم تعديل الأسعار
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تعديل أسعار التوثيق:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 14),
                    _buildPriceRow('مدة شهر (\$)', _price1MController),
                    const SizedBox(height: 10),
                    _buildPriceRow('مدة 6 أشهر (\$)', _price6MController),
                    const SizedBox(height: 10),
                    _buildPriceRow('مدة سنة (\$)', _price1YController),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _isLoadingPrices
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              onPressed: _savePrices,
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('حفظ الأسعار'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // قسم طلبات التوثيق بانتظار الموافقة
              const Text('طلبات التوثيق بانتظار الموافقة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('verification_requests').where('status', isEqualTo: 'pending').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('لا توجد طلبات توثيق معلقة حالياً.', style: TextStyle(color: Colors.grey))),
                    );
                  }

                  var requests = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      var reqDoc = requests[index];
                      var reqData = reqDoc.data() as Map<String, dynamic>;

                      String userId = reqData['userId'] ?? '';
                      String userName = reqData['userName'] ?? 'مستخدم';
                      String email = reqData['email'] ?? '';
                      String duration = reqData['duration'] ?? 'مدة شهر';
                      String requestDate = _formatTimestamp(reqData['createdAt']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                              child: const Icon(Icons.hourglass_top, color: Colors.orange),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                        child: Text(duration, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('تاريخ الطلب: $requestDate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _approveRequest(context, reqDoc.id, userId, duration),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black87,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('توثيق', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  onPressed: () => _cancelRequest(context, reqDoc.id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('إلغاء الطلب', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // قسم الحسابات الموثقة (مع عرض المدة المتبقية بوضوح)
              const Text('الحسابات الموثقة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').where('isVerified', isEqualTo: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('لا توجد حسابات موثقة حالياً.', style: TextStyle(color: Colors.grey))),
                    );
                  }

                  var verifiedUsers = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: verifiedUsers.length,
                    itemBuilder: (context, index) {
                      var userDoc = verifiedUsers[index];
                      var userData = userDoc.data() as Map<String, dynamic>;

                      String userName = userData['name'] ?? 'مستخدم';
                      String email = userData['email'] ?? '';
                      String duration = userData['verificationDuration'] ?? 'مدة شهر';
                      String verifiedDate = _formatTimestamp(userData['verifiedAt']);
                      String remainingText = _getRemainingDaysText(userData['verifiedAt'], duration);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified, color: Colors.blue, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Text(duration, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(height: 6),
                            // عرض المدة المتبقية بوضوح
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(remainingText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('تاريخ الموافقة: $verifiedDate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _editDurationDialog(context, userDoc.id, duration),
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('تعديل المدة', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blueAccent,
                                        side: const BorderSide(color: Colors.blueAccent),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _revokeVerification(context, userDoc.id),
                                      icon: const Icon(Icons.cancel_outlined, size: 14),
                                      label: const Text('إلغاء التوثيق', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
        ),
      ],
    );
  }
}