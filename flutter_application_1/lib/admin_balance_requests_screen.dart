import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBalanceRequestsScreen extends StatefulWidget {
  const AdminBalanceRequestsScreen({super.key});

  @override
  State<AdminBalanceRequestsScreen> createState() => _AdminBalanceRequestsScreenState();
}

class _AdminBalanceRequestsScreenState extends State<AdminBalanceRequestsScreen> {
  final TextEditingController _directAmountController = TextEditingController();
  String? _selectedUserId;
  bool _isDirectLoading = false;

  @override
  void dispose() {
    _directAmountController.dispose();
    super.dispose();
  }

  // شحن رصيد مباشر لأي مستخدم مختار من القائمة
  Future<void> _directTopUp() async {
    if (_selectedUserId == null || _directAmountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المستخدم وإدخال المبلغ المراد شحنه'), backgroundColor: Colors.orange),
      );
      return;
    }

    double? amount = double.tryParse(_directAmountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isDirectLoading = true);

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(_selectedUserId).get();
      if (!userDoc.exists) throw 'المستخدم غير موجود';

      var userData = userDoc.data() as Map<String, dynamic>;
      double currentBalance = (userData['balance'] ?? 0.0).toDouble();
      String userName = userData['name'] ?? 'مستخدم';
      String email = userData['email'] ?? '';
      String role = userData['role'] ?? 'engineer';

      // تحديث الرصيد في جدول المستخدمين
      await FirebaseFirestore.instance.collection('users').doc(_selectedUserId).update({
        'balance': currentBalance + amount,
      });

      // تسجيل العملية في طلبات الشحن لتظهر في قسم المكتملة
      await FirebaseFirestore.instance.collection('balance_requests').add({
        'userId': _selectedUserId,
        'engineerName': userName,
        'email': email,
        'role': role,
        'amount': amount,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _directAmountController.clear();
      setState(() => _selectedUserId = null);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم شحن مبلغ ($amount \$) لحساب $userName بنجاح ✓'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الشحن: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isDirectLoading = false);
    }
  }

  // الموافقة على طلب معلق
  Future<void> _approveBalanceRequest(BuildContext context, String requestId, String userId, double amount) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد شحن الرصيد'),
        content: Text('هل أنت متأكد من الموافقة على شحن مبلغ ($amount \$) وإضافته إلى رصيد المستخدم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('موافقة وشحن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      double currentBalance = userDoc.exists ? (userDoc.data()?['balance'] ?? 0.0).toDouble() : 0.0;

      if (userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'balance': currentBalance + amount,
        });
      }

      await FirebaseFirestore.instance.collection('balance_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت الموافقة بنجاح وإضافة $amount \$ إلى الرصيد ✓'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // رفض أو حذف الطلب
  Future<void> _rejectRequest(BuildContext context, String requestId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: const Text('هل أنت متأكد من رغبتك في رفض وحذف طلب الشحن؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض الطلب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('balance_requests').doc(requestId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض وحذف الطلب بنجاح')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildRoleBadge(String role) {
    String label = 'مستخدم';
    Color color = Colors.grey;
    if (role == 'engineer') {
      label = 'مكتب هندسي';
      color = Colors.blueAccent;
    } else if (role == 'investor') {
      label = 'مستثمر';
      color = Colors.green;
    } else if (role == 'admin') {
      label = 'أدمن';
      color = Colors.amber.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'غير متوفر';
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      return '${dt.year}/${dt.month}/${dt.day}';
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة طلبات شحن الرصيد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              // بطاقة شحن رصيد مباشر لأي مستخدم من القائمة
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('شحن رصيد مباشر لأي مستخدم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        var users = userSnapshot.data!.docs;

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedUserId,
                          hint: const Text('اختر المستخدم (الاسم - البريد الإلكتروني)'),
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: users.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            String name = data['name'] ?? 'بدون اسم';
                            String email = data['email'] ?? 'بدون بريد';
                            String role = data['role'] ?? 'user';
                            String roleLabel = role == 'engineer' ? 'مكتب هندسي' : (role == 'investor' ? 'مستثمر' : 'مستخدم');

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text('$name ($email) [$roleLabel]', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedUserId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _directAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المبلغ المراد شحنه بالدولار (\$)',
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.blueAccent),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isDirectLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _directTopUp,
                            icon: const Icon(Icons.account_balance_wallet, size: 18),
                            label: const Text('شحن رصيد المستخدم فوراً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // قسم طلبات الشحن المعلقة (مع جلب البيانات الحقيقية من جدول users بالاعتماد على userId)
              const Text('طلبات شحن الرصيد المعلقة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('balance_requests').where('status', isEqualTo: 'pending').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('لا توجد طلبات شحن رصيد معلقة حالياً.', style: TextStyle(color: Colors.grey))),
                    );
                  }

                  var requests = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      var reqDoc = requests[index];
                      var data = reqDoc.data() as Map<String, dynamic>;

                      String userId = data['userId'] ?? data['engineerId'] ?? '';
                      double amount = (data['amount'] ?? 0.0).toDouble();
                      String requestDate = _formatTimestamp(data['createdAt']);

                      // جلب بيانات المستخدم الحقيقية بالاعتماد على userId لضمان ظهور الاسم والإيميل والتصنيف بدقة
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          var userData = userSnapshot.hasData && userSnapshot.data!.exists
                              ? (userSnapshot.data!.data() as Map<String, dynamic>)
                              : {};

                          String userName = userData['name'] ?? data['engineerName'] ?? 'مستخدم';
                          String email = userData['email'] ?? data['email'] ?? 'بدون بريد';
                          String role = userData['role'] ?? data['role'] ?? 'engineer';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                                  child: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                          const SizedBox(width: 8),
                                          _buildRoleBadge(role),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text('المبلغ: $amount \$', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                                          const SizedBox(width: 15),
                                          Text('التاريخ: $requestDate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _approveBalanceRequest(context, reqDoc.id, userId, amount),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('موافقة', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 6),
                                    OutlinedButton(
                                      onPressed: () => _rejectRequest(context, reqDoc.id),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('رفض', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // قسم الطلبات التي تم شحنها (المكتملة)
              const Text('الطلبات التي تم شحنها (المكتملة):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('balance_requests').where('status', isEqualTo: 'approved').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('لا توجد سجلات شحن مكتملة حتى الآن.', style: TextStyle(color: Colors.grey))),
                    );
                  }

                  var completedRequests = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completedRequests.length,
                    itemBuilder: (context, index) {
                      var reqDoc = completedRequests[index];
                      var data = reqDoc.data() as Map<String, dynamic>;

                      String userId = data['userId'] ?? data['engineerId'] ?? '';
                      double amount = (data['amount'] ?? 0.0).toDouble();
                      String approvedDate = _formatTimestamp(data['approvedAt'] ?? data['createdAt']);

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnapshot) {
                          var userData = userSnapshot.hasData && userSnapshot.data!.exists
                              ? (userSnapshot.data!.data() as Map<String, dynamic>)
                              : {};

                          String userName = userData['name'] ?? data['engineerName'] ?? 'مستخدم';
                          String email = userData['email'] ?? data['email'] ?? 'بدون بريد';
                          String role = userData['role'] ?? data['role'] ?? 'engineer';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_circle, color: Colors.green),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                          const SizedBox(width: 8),
                                          _buildRoleBadge(role),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text('المبلغ المشحون: $amount \$', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                                          const SizedBox(width: 15),
                                          Text('تاريخ الشحن: $approvedDate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('تم الشحن ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                ),
                              ],
                            ),
                          );
                        },
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
}