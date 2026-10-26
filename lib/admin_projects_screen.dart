import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminProjectsScreen extends StatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  State<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends State<AdminProjectsScreen> {
  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showImageZoomDialog(BuildContext context, String imageBase64OrUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          height: 500,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: _buildSafeImageWidget(imageBase64OrUrl),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeImageWidget(String path) {
    if (path.isEmpty || path == 'hhh' || path.length < 15) {
      return const Center(
        child: Text('📄 هذا الملف نصي أو غير متوفر كصورة مباشرة.', textAlign: TextAlign.center),
      );
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Text('تعذر تحميل الصورة'));
    }
    try {
      final base64Str = path.contains(',') ? path.split(',').last : path;
      if (base64Str.length % 4 != 0) {
        return const Center(child: Text('📄 ملف مستند أو PDF جاهز للتدقيق.', textAlign: TextAlign.center));
      }
      final bytes = base64Decode(base64Str);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (e) {
      return const Center(child: Text('📄 ملف مستند أو PDF جاهز للتدقيق.', textAlign: TextAlign.center));
    }
  }

  void _showSecondaryImagesDialog(BuildContext context, List images) {
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد صور ثانوية مرفقة')));
      return;
    }

    PageController pageController = PageController();
    int currentIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الصور الثانوية للمشروع'),
              Text('${currentIndex + 1} / ${images.length}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
          content: SizedBox(
            width: 450,
            height: 400,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setStateDialog(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    String img = images[index]?.toString() ?? '';
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(child: _buildSafeImageWidget(img)),
                    );
                  },
                ),
                if (currentIndex < images.length - 1)
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 30, color: Colors.blue),
                      onPressed: () {
                        pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                    ),
                  ),
                if (currentIndex > 0)
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 30, color: Colors.blue),
                      onPressed: () {
                        pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveProjectWithCommission(BuildContext context, String projectId, String engineerId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الموافقة على المشروع'),
        content: const Text('هل أنت متأكد من رغبتك في الموافقة على هذا المشروع ونشره؟ سيتم خصم رسوم النشر من رصيد المكتب الهندسي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('موافقة', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      double commissionAmount = 10.0;
      var feeDoc = await FirebaseFirestore.instance.collection('settings').doc('project_fee').get();
      if (feeDoc.exists && feeDoc.data() != null) {
        commissionAmount = (feeDoc.data()?['fee'] ?? 10.0).toDouble();
      }

      if (engineerId.isNotEmpty) {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(engineerId).get();
        if (userDoc.exists) {
          double currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();
          await FirebaseFirestore.instance.collection('users').doc(engineerId).update({
            'balance': currentBalance >= commissionAmount ? currentBalance - commissionAmount : 0.0,
          });
        }
      }

      await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
        'isApproved': true,
        'isVisible': true,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الموافقة على المشروع ونشره بنجاح وتم خصم الرسوم'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الموافقة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteProject(BuildContext context, String projectId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المشروع'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا المشروع نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('projects').doc(projectId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المشروع بنجاح'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من المشاريع (إدارة)'),
        backgroundColor: Colors.blue,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('projects').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد مشاريع مضافة حالياً.'));
            }

            var projects = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                var project = projects[index];
                var data = project.data() as Map<String, dynamic>;
                
                bool isApproved = data['isApproved'] ?? false;
                bool isVisible = data['isVisible'] ?? true;
                String engineerId = data['engineerId']?.toString() ?? '';
                
                // جلب اسم المكتب والبريد الإلكتروني للناشر
                String engineerName = data['engineerName']?.toString() ?? 'مكتب غير معروف';
                String engineerEmail = data['engineerEmail']?.toString() ?? 'بدون بريد';
                bool engineerVerified = data['engineerVerified'] ?? false;

                String title = data['title']?.toString() ?? '';
                String cost = data['cost']?.toString() ?? '';
                String returnType = data['returnType'] == 'percentage' ? '%' : 'دولار';
                String returnValue = data['returnValue']?.toString() ?? '';
                String mainImageUrl = data['mainImageUrl']?.toString() ?? '';
                List secondaryImages = (data['secondaryImages'] is List) ? data['secondaryImages'] : [];
                
                String proofName = data['proofDocumentName']?.toString() ?? 'ثبوتية.jpg';
                String proofUrl = data['proofDocumentUrl']?.toString() ?? '';
                bool commissionPaid = data['commissionPaid'] ?? false;
                String mapsLink = data['googleMapsLink']?.toString() ?? '';
                String whatsapp = data['whatsappNumber']?.toString() ?? '';

                String createdAtStr = 'غير متوفر';
                if (data['createdAt'] != null) {
                  try {
                    if (data['createdAt'] is Timestamp) {
                      DateTime dt = (data['createdAt'] as Timestamp).toDate();
                      createdAtStr = '${dt.year}/${dt.month}/${dt.day}';
                    } else {
                      createdAtStr = data['createdAt'].toString();
                    }
                  } catch (e) {
                    createdAtStr = 'غير متوفر';
                  }
                }

                String approvedAtStr = 'بانتظار الموافقة';
                if (data['approvedAt'] != null) {
                  try {
                    if (data['approvedAt'] is Timestamp) {
                      DateTime dt = (data['approvedAt'] as Timestamp).toDate();
                      approvedAtStr = '${dt.year}/${dt.month}/${dt.day}';
                    } else {
                      approvedAtStr = data['approvedAt'].toString();
                    }
                  } catch (e) {
                    approvedAtStr = 'بانتظار الموافقة';
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('projects').doc(project.id).update({
                                      'isVisible': !isVisible,
                                    });
                                  },
                                  icon: Icon(
                                    isVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  label: Text(
                                    isVisible ? 'إخفاء' : 'إظهار',
                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isApproved)
                                  ElevatedButton.icon(
                                    onPressed: () => _approveProjectWithCommission(context, project.id, engineerId),
                                    icon: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                                    label: const Text('الموافقة', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        
                        // عرض اسم المكتب الناشر وحسابه بوضوح
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business_center, size: 16, color: Colors.blueAccent),
                              const SizedBox(width: 6),
                              const Text('المكتب الناشر: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                              if (engineerVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4.0),
                                  child: Icon(Icons.verified, size: 14, color: Colors.blue),
                                ),
                              Text(engineerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
                              const SizedBox(width: 10),
                              Text('($engineerEmail)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),

                        const Divider(),

                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 70,
                                height: 50,
                                child: mainImageUrl.isNotEmpty && mainImageUrl != 'hhh'
                                    ? Image.memory(
                                        base64Decode(mainImageUrl.contains(',') ? mainImageUrl.split(',').last : mainImageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(color: Colors.grey),
                                      )
                                    : Container(color: Colors.grey, child: const Icon(Icons.image, size: 20)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الصورة الرئيسية مرفقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('عدد الصور الثانوية: ${secondaryImages.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                OutlinedButton(
                                  onPressed: () => _showImageZoomDialog(context, mainImageUrl, 'الصورة الرئيسية'),
                                  child: const Text('عرض الصورة'),
                                ),
                                if (secondaryImages.isNotEmpty)
                                  TextButton(
                                    onPressed: () => _showSecondaryImagesDialog(context, secondaryImages),
                                    child: const Text('عرض الصور الثانوية', style: TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Text('💰 التكلفة: $cost \$'),
                        Text('📈 العائد للمستثمر: $returnValue $returnType بالسنة'),
                        
                        if (mapsLink.isNotEmpty)
                          InkWell(
                            onTap: () => _launchURL(mapsLink),
                            child: Text('🗺️ رابط الخرائط: $mapsLink', style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                          ),
                        if (whatsapp.isNotEmpty)
                          InkWell(
                            onTap: () => _launchURL('https://wa.me/$whatsapp'),
                            child: Text('📞 واتساب المكتب الهندسي: +$whatsapp', style: const TextStyle(color: Colors.green, decoration: TextDecoration.underline)),
                          ),
                        const SizedBox(height: 6),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Text('📎 الأوراق الثبوتية: $proofName', overflow: TextOverflow.ellipsis),
                            ),
                            if (proofUrl.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => _showImageZoomDialog(context, proofUrl, 'الأوراق الثبوتية'),
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text('معاينة الأوراق'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'حالة العمولة والرسوم: ${commissionPaid ? "✅ مدفوعة" : "❌ غير مدفوعة"}', 
                          style: TextStyle(color: commissionPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('📅 تاريخ النشر: $createdAtStr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              Text('✔️ تاريخ الموافقة: $approvedAtStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isApproved ? Colors.green[50] : Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'حالة النشر: ${isApproved ? "🟢 معتمد ومنشور" : "⏳ بانتظار الموافقة"} (${isVisible ? "مرئي" : "مخفي"})', 
                                style: TextStyle(
                                  color: isApproved ? Colors.green[800] : Colors.orange[800], 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _deleteProject(context, project.id),
                              icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                              label: const Text('حذف المشروع', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}