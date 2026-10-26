import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// 1. شاشة طلب شحن رصيد للمكتب
class EngineerBalanceScreen extends StatefulWidget {
  const EngineerBalanceScreen({super.key});

  @override
  State<EngineerBalanceScreen> createState() => _EngineerBalanceScreenState();
}

class _EngineerBalanceScreenState extends State<EngineerBalanceScreen> {
  final _amountController = TextEditingController();

  Future<void> _submitBalanceRequest() async {
    if (_amountController.text.trim().isEmpty) return;
    double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    String userName = userDoc.exists ? (userDoc.data()?['name'] ?? 'مستخدم') : 'مستخدم';

    await FirebaseFirestore.instance.collection('balance_requests').add({
      'userId': user.uid,
      'userName': userName,
      'userEmail': user.email ?? '',
      'amount': amount,
      'status': 'pending', // pending أو completed
      'createdAt': FieldValue.serverTimestamp(),
    });

    _amountController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم ارسال الطلب وعليك التواصل مع المشرف لتأكيد الدفع'), backgroundColor: Colors.orange),
    );
    setState(() {});
  }

  Future<void> _launch(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('طلب شحن رصيد'), backgroundColor: Colors.blue),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ادخل المبلغ :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'مثال : 100 \$', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _submitBalanceRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF32CD32),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('طلب شحن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(height: 30),
              const Text('الطلبات :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('balance_requests')
                      .where('userId', isEqualTo: user?.uid ?? '')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد طلبات شحن سابقة.'));
                    }
                    var docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        bool isCompleted = data['status'] == 'completed';
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFF98FB98) : const Color(0xFFFFE4B5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('تم طلب مبلغ ${data['amount']} \$', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  isCompleted ? 'تم الشحن' : 'قيد الانتظار',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                child: const Center(
                  child: Text(
                    'تم ارسال الطلب وعليك التواصل مع المشرف لتأكيد الدفع',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _contactButton('تواصل عبر واتساب', Colors.green, Icons.chat, () => _launch('https://wa.me/963900000000')),
              const SizedBox(height: 8),
              _contactButton('تواصل عبر تيليجرام', Colors.lightBlue, Icons.send, () => _launch('https://t.me/username')),
              const SizedBox(height: 8),
              _contactButton('تواصل عبر البريد', Colors.grey.shade300, Icons.email, () => _launch('mailto:admin@builder.com'), textColor: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactButton(String text, Color bgColor, IconData icon, VoidCallback onTap, {Color textColor = Colors.white}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 10),
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }
}

// 2. شاشة الدعم للمكتب الهندسي
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launch(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدعم'), backgroundColor: Colors.blue),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تواصل :', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 20),
              _contactButton('تواصل عبر واتساب', Colors.green, Icons.chat, () => _launch('https://wa.me/963900000000')),
              const SizedBox(height: 12),
              _contactButton('تواصل عبر تيليجرام', Colors.lightBlue, Icons.send, () => _launch('https://t.me/username')),
              const SizedBox(height: 12),
              _contactButton('تواصل عبر البريد', Colors.grey.shade300, Icons.email, () => _launch('mailto:admin@builder.com'), textColor: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactButton(String text, Color bgColor, IconData icon, VoidCallback onTap, {Color textColor = Colors.white}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(25)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 10),
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }
}