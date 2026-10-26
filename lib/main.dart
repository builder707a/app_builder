import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/admin_balance_requests_screen.dart';
import 'package:flutter_application_1/admin_requests_screen.dart';
import 'package:flutter_application_1/engineer_balance_support_screens.dart';
import 'package:flutter_application_1/engineer_verification_screen.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'add_project_screen.dart';
import 'project_detail_screen.dart';
import 'admin_projects_screen.dart';
import 'admin_users_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('خطأ في الاتصال بالخادم: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'البناء | Builder',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoadingUser = true;
  
  // متغيرات البحث
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => isLoadingUser = true);
    currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          userData = userDoc.data() as Map<String, dynamic>;
        } else {
          await FirebaseAuth.instance.signOut();
          currentUser = null;
          userData = null;
        }
      } catch (e) {
        debugPrint('خطأ: $e');
      }
    } else {
      userData = null;
    }
    
    if (mounted) {
      setState(() => isLoadingUser = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await _fetchUserData();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الخروج بنجاح'), backgroundColor: Colors.orange),
    );
  }

  Future<void> _resetPassword() async {
    if (currentUser?.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: currentUser!.email!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رابط إعادة تعيين كلمة السر إلى بريدك'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text('هل أنت متأكد من رغبتك في حذف حسابك نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        String uid = currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        await currentUser!.delete();
        await _fetchUserData();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحساب بنجاح'), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: يرجى إعادة تسجيل الدخول قبل الحذف. (${e.toString()})'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String role = userData?['role'] ?? 'visitor';
    String name = userData?['name'] ?? 'زائر';
    String email = currentUser?.email ?? 'يرجى تسجيل الدخول للوصول للميزات';

    String roleArabic = 'زائر';
    if (role == 'engineer') roleArabic = 'مكتب هندسي';
    if (role == 'investor') roleArabic = 'مستثمر';
    if (role == 'admin') roleArabic = 'مشرف النظام (أدمن)';

    bool isAdminOrEngineer = (role == 'admin' || role == 'engineer');

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // رأس القائمة الجانبية المحدث تماماً كالصورة
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 50, color: Colors.blue),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Icon(Icons.settings, color: Colors.white),
                            const SizedBox(height: 4),
                            Text(
                              'الرصيد : ${(userData?['balance'] ?? 0.0)} \$',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (userData?['isVerified'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.verified, color: Colors.white, size: 18),
                          ),
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('نوع الحساب : $roleArabic', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // الانتقال للملف الشخصي أو إظهاره
                      },
                      icon: const Icon(Icons.visibility, size: 16, color: Colors.blue),
                      label: const Text('عرض الملف الشخصي', style: TextStyle(color: Colors.blue, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(130, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (currentUser == null) ...[
              ListTile(
                leading: const Icon(Icons.business, color: Colors.blue),
                title: const Text('تسجيل الدخول كـ مكتب هندسي'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen(initialRole: 'engineer')));
                  _fetchUserData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.green),
                title: const Text('تسجيل الدخول كـ مستثمر'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen(initialRole: 'investor')));
                  _fetchUserData();
                },
              ),
            ] else if (role == 'engineer') ...[
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text('اضافة مشروع'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProjectScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.blue),
                title: const Text('توثيق الحساب'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EngineerVerificationScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.black),
                title: const Text('طلب شحن رصيد'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EngineerBalanceScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent, color: Colors.black),
                title: const Text('الدعم'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: _signOut,
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('حذف الحساب'),
                onTap: _deleteAccount,
              ),
            ] else if (role == 'investor') ...[
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.blueGrey),
                title: const Text('إعادة تعيين كلمة السر'),
                onTap: () {
                  Navigator.pop(context);
                  _resetPassword();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: _signOut,
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('حذف الحساب'),
                onTap: _deleteAccount,
              ),
            ] else if (role == 'admin') ...[
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.amber),
                title: const Text('التحقق من المشاريع'),
                trailing: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Text('3', style: TextStyle(color: Colors.white, fontSize: 12))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminProjectsScreen())); // تم التصحيح هنا
                },
              ),
              ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text('المستخدمين'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.blue),
                title: const Text('طلبات التوثيق'),
                trailing: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Text('2', style: TextStyle(color: Colors.white, fontSize: 12))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminVerificationRequestsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.black),
                title: const Text('شحن رصيد'),
                trailing: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Text('3', style: TextStyle(color: Colors.white, fontSize: 12))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminBalanceRequestsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text('البلاغات'),
                trailing: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Text('2', style: TextStyle(color: Colors.white, fontSize: 12))),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: _signOut,
              ),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('عن التطبيق'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
            onPressed: () {
              _fetchUserData();
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن مشروع...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              )
            : const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'البناء | Builder',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          if (role == 'engineer')
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddProjectScreen()),
                );
              },
            ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('isApproved', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('لا توجد مشاريع معتمدة أو متاحة حالياً.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              );
            }

            var projects = snapshot.data!.docs;

            projects = projects.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              bool isVisible = data['isVisible'] ?? true;
              return isVisible == true;
            }).toList();

            if (projects.isEmpty) {
              return const Center(
                child: Text('لا توجد مشاريع مرئية للعامة حالياً.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              );
            }

            if (_searchQuery.isNotEmpty) {
              projects = projects.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String title = (data['title'] ?? '').toLowerCase();
                return title.contains(_searchQuery);
              }).toList();
            }

            if (projects.isEmpty) {
              return const Center(child: Text('لا توجد نتائج تطابق بحثك.'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                var project = projects[index];
                var data = project.data() as Map<String, dynamic>;

                String formattedDate = '2026/10/20';
                if (data['createdAt'] != null) {
                  Timestamp t = data['createdAt'];
                  DateTime dt = t.toDate();
                  formattedDate = '${dt.year}/${dt.month}/${dt.day}';
                }

                return ProjectCard(
                  title: data['title'] ?? '',
                  cost: data['cost'] ?? '',
                  isAvailable: data['isAvailable'] ?? true,
                  imagePath: data['mainImageUrl'] ?? '',
                  engineerName: data['engineerName'] ?? 'UserName',
                  isVerified: data['engineerVerified'] ?? false,
                  date: formattedDate,
                  onTap: () {
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ يرجى تسجيل الدخول أو إنشاء حساب أولاً لعرض تفاصيل المشروع'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen(initialRole: 'investor')),
                      ).then((_) => _fetchUserData());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetailScreen(
                            projectId: project.id,
                            projectData: data,
                            isAdminOrEngineer: isAdminOrEngineer,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String title;
  final String cost;
  final bool isAvailable;
  final String imagePath;
  final String engineerName;
  final bool isVerified;
  final String date;
  final VoidCallback onTap;

  const ProjectCard({
    super.key,
    required this.title,
    required this.cost,
    required this.isAvailable,
    required this.imagePath,
    required this.engineerName,
    required this.isVerified,
    required this.date,
    required this.onTap,
  });

  Widget _buildCardImage(String path) {
    if (path.startsWith('data:image')) {
      try {
        final base64String = path.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, height: 130, width: double.infinity, fit: BoxFit.cover);
      } catch (e) {
        return Container(height: 130, color: Colors.grey[300], child: const Icon(Icons.broken_image));
      }
    } else if (path.startsWith('http')) {
      return Image.network(
        path,
        height: 130,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(height: 130, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
      );
    } else {
      return Container(height: 130, color: Colors.grey[300], child: const Icon(Icons.image));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildCardImage(imagePath),
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    height: 35,
                    width: 35,
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.red,
                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'يحتاج اعادة اعمار',
                          style: TextStyle(fontSize: 12, color: Colors.redAccent),
                        ),
                      ],
                    ),
                    Text(
                      'التكلفة : $cost',
                      style: const TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 4, thickness: 0.8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 2.0),
                                  child: Icon(Icons.verified, size: 15, color: Colors.blue),
                                ),
                              Flexible(
                                child: Text(
                                  '@$engineerName',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          date,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        isAvailable ? 'متاح للاستثمار' : 'مستثمر حالياً',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}