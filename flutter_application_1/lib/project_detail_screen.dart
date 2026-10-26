import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> projectData;
  final bool isAdminOrEngineer;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectData,
    required this.isAdminOrEngineer,
  });

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // دالة ذكية لعرض الصورة سواء كانت رابط أو Base64
  Widget _buildImage(String imagePath, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
    if (imagePath.startsWith('data:image')) {
      try {
        final base64String = imagePath.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            height: height,
            width: width,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        );
      } catch (e) {
        return Container(
          height: height,
          width: width,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      }
    } else if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          width: width,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    } else {
      return Container(
        height: height,
        width: width,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = projectData['title'] ?? '';
    String cost = projectData['cost'] ?? '';
    String mainImage = projectData['mainImageUrl'] ?? '';
    List secondaryImages = projectData['secondaryImages'] ?? [];
    String mapsLink = projectData['googleMapsLink'] ?? '';
    String whatsapp = projectData['whatsappNumber'] ?? '';
    bool isAvailable = projectData['isAvailable'] ?? true;
    bool commissionPaid = projectData['commissionPaid'] ?? false;
    String proofDocsName = projectData['proofDocumentName'] ?? 'مرفق';
    String returnType = projectData['returnType'] == 'percentage' ? '%' : '\$';
    String returnValue = projectData['returnValue'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصورة الرئيسية
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(mainImage, height: 220, width: double.infinity),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'التكلفة التقديرية: $cost',
                style: const TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'عائد الاستثمار: $returnValue ${returnType == '%' ? '%' : 'دولار'}',
                style: const TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAvailable ? '🟢 متاح للاستثمار' : '🔴 مستثمر حالياً',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              
              // قسم خاص للأدمن أو المكتب الهندسي المالك
              if (isAdminOrEngineer) ...[
                const Divider(height: 30),
                const Text('🔒 قسم خاص للإدارة والمكتب (الأوراق الثبوتية):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.grey[100],
                  width: double.infinity,
                  child: Text('اسم الملف المرفق: $proofDocsName'),
                ),
                const SizedBox(height: 6),
                Text('حالة العمولة عبر شام كاش: ${commissionPaid ? "✅ مدفوعة" : "❌ غير مدفوعة"}', style: const TextStyle(color: Colors.green)),
              ],

              const Divider(height: 30),
              const Text('الصور الثانوية للمشروع:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              secondaryImages.isEmpty
                  ? const Text('لا توجد صور ثانوية مرفقة.')
                  : SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: secondaryImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImage(secondaryImages[index], width: 120, height: 120),
                            ),
                          );
                        },
                      ),
                    ),

              const Divider(height: 30),
              
              // أزرار التواصل والخرائط
              Row(
                children: [
                  if (mapsLink.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchURL(mapsLink),
                        icon: const Icon(Icons.map, color: Colors.white),
                        label: const Text('موقع الخرائط', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  if (mapsLink.isNotEmpty && whatsapp.isNotEmpty) const SizedBox(width: 12),
                  if (whatsapp.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchURL('https://wa.me/$whatsapp'),
                        icon: const Icon(Icons.chat, color: Colors.white),
                        label: const Text('تواصل واتساب', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                ],
              ),
              
              if (isAdminOrEngineer) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    bool newStatus = !isAvailable;
                    await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
                      'isAvailable': newStatus,
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تحديث حالة المشروع إلى: ${newStatus ? "متاح للاستثمار" : "مستثمر"}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: Text(isAvailable ? 'تغيير الحالة إلى: (مستثمر حالياً)' : 'تغيير الحالة إلى: (متاح للاستثمار)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}