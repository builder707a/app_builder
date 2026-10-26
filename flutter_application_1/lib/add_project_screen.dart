import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _mainImageUrlController = TextEditingController();
  final _secondaryImagesUrlController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _returnValueController = TextEditingController();

  bool _useMainImageLink = true;
  PlatformFile? _mainImageFile;

  bool _useSecondaryImagesLink = true;
  List<PlatformFile> _secondaryImageFiles = [];

  PlatformFile? _proofDocumentFile; 
  String _returnType = 'percentage'; 
  bool _isLoading = false;
  double _projectFee = 10.0;

  @override
  void initState() {
    super.initState();
    _fetchProjectFee();
  }

  Future<void> _fetchProjectFee() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('settings').doc('project_fee').get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _projectFee = (doc.data()?['fee'] ?? 10.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب رسوم النشر: $e');
    }
  }

  Future<PlatformFile?> _pickFile({List<String>? allowedExtensions, FileType type = FileType.any}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: type, allowedExtensions: allowedExtensions, withData: true);
    if (result != null && result.files.isNotEmpty) return result.files.first;
    return null;
  }

  Future<List<PlatformFile>> _pickMultipleImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (result != null) return result.files;
    return [];
  }

  Future<void> _submitProject() async {
    if (_titleController.text.trim().isEmpty || _costController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة اسم المشروع والتكلفة التقديرية'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      double currentBalance = userDoc.exists ? (userDoc.data()?['balance'] ?? 0.0).toDouble() : 0.0;

      if (currentBalance < _projectFee) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('رصيدك الحالي ($currentBalance \$) غير كافٍ لدفع رسوم النشر ($_projectFee \$). يرجى شحن رصيدك.'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      String engineerName = userDoc.exists ? (userDoc.data()?['name'] ?? 'مكتب هندسي') : 'مكتب هندسي';
      bool isVerified = userDoc.exists ? (userDoc.data()?['isVerified'] ?? false) : false;

      String mainImageString = '';
      List<String> secondaryImageStrings = [];
      String proofDocString = '';

      if (_useMainImageLink) {
        mainImageString = _mainImageUrlController.text.trim();
      } else if (_mainImageFile != null && _mainImageFile!.bytes != null) {
        mainImageString = 'data:image/png;base64,${base64Encode(_mainImageFile!.bytes!)}';
      }

      if (_useSecondaryImagesLink) {
        secondaryImageStrings = _secondaryImagesUrlController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (_secondaryImageFiles.isNotEmpty) {
        for (var file in _secondaryImageFiles) {
          if (file.bytes != null) secondaryImageStrings.add('data:image/png;base64,${base64Encode(file.bytes!)}');
        }
      }

      if (_proofDocumentFile != null && _proofDocumentFile!.bytes != null) {
        proofDocString = 'data:application/octet-stream;base64,${base64Encode(_proofDocumentFile!.bytes!)}';
      }

      await FirebaseFirestore.instance.collection('projects').add({
        'title': _titleController.text.trim(),
        'cost': _costController.text.trim(),
        'mainImageUrl': mainImageString,
        'secondaryImages': secondaryImageStrings,
        'proofDocumentUrl': proofDocString,
        'proofDocumentName': _proofDocumentFile?.name ?? '',
        'googleMapsLink': _mapsLinkController.text.trim(),
        'whatsappNumber': _whatsappController.text.trim(),
        'returnType': _returnType,
        'returnValue': _returnValueController.text.trim(),
        'commissionPaid': true, 
        'isApproved': false,
        'isVisible': true,
        'engineerId': user.uid,
        'engineerEmail': user.email ?? '',
        'engineerName': engineerName,
        'engineerVerified': isVerified,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال المشروع بنجاح إلى الإدارة للمراجعة'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الإرسال: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مشروع جديد'), backgroundColor: Colors.blue),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('معلومات المشروع الأساسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 12),
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'اسم المشروع أو المكان', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _costController, decoration: const InputDecoration(labelText: 'التكلفة التقديرية بالدولار', border: OutlineInputBorder())),
              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الصورة الرئيسية:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(label: const Text('عن طريق رابط'), selected: _useMainImageLink, onSelected: (val) => setState(() => _useMainImageLink = true)),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('رفع من الجهاز'), selected: !_useMainImageLink, onSelected: (val) => setState(() => _useMainImageLink = false)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_useMainImageLink)
                        TextField(controller: _mainImageUrlController, decoration: const InputDecoration(labelText: 'رابط الصورة الرئيسية', border: OutlineInputBorder()))
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            var file = await _pickFile(type: FileType.image);
                            if (file != null) setState(() => _mainImageFile = file);
                          },
                          icon: const Icon(Icons.image),
                          label: Text(_mainImageFile != null ? 'تم اختيار: ${_mainImageFile!.name}' : 'اختر صورة رئيسية'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الصور الثانوية:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(label: const Text('عن طريق روابط'), selected: _useSecondaryImagesLink, onSelected: (val) => setState(() => _useSecondaryImagesLink = true)),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text('رفع من الجهاز'), selected: !_useSecondaryImagesLink, onSelected: (val) => setState(() => _useSecondaryImagesLink = false)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_useSecondaryImagesLink)
                        TextField(controller: _secondaryImagesUrlController, decoration: const InputDecoration(labelText: 'روابط الصور مفصولة بفاصلة', border: OutlineInputBorder()))
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            var files = await _pickMultipleImages();
                            if (files.isNotEmpty) setState(() => _secondaryImageFiles = files);
                          },
                          icon: const Icon(Icons.collections),
                          label: Text(_secondaryImageFiles.isNotEmpty ? 'تم اختيار ${_secondaryImageFiles.length} صور' : 'اختر عدة صور'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('تفاصيل العائد للمستثمر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 12),
              Row(
                children: [
                  // ignore: deprecated_member_use
                  Expanded(child: RadioListTile<String>(title: const Text('نسبة مئوية (%)'), value: 'percentage', groupValue: _returnType, onChanged: (val) => setState(() => _returnType = val!))),
                  // ignore: deprecated_member_use
                  Expanded(child: RadioListTile<String>(title: const Text('مبلغ مالي (\$)'), value: 'fixed', groupValue: _returnType, onChanged: (val) => setState(() => _returnType = val!))),
                ],
              ),
              TextField(controller: _returnValueController, decoration: const InputDecoration(labelText: 'قيمة العائد', border: OutlineInputBorder())),
              const SizedBox(height: 24),

              const Text('الأوراق الثبوتية (للإدارة فقط)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  var file = await _pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg']);
                  if (file != null) setState(() => _proofDocumentFile = file);
                },
                icon: const Icon(Icons.file_present, color: Colors.orange),
                label: Text(_proofDocumentFile != null ? 'الملف المحدد: ${_proofDocumentFile!.name}' : 'إرفاق أوراق ثبوتية (صورة أو PDF)'),
              ),
              const SizedBox(height: 16),

              TextField(controller: _mapsLinkController, decoration: const InputDecoration(labelText: 'رابط موقع المكان من Google Maps', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _whatsappController, decoration: const InputDecoration(labelText: 'رقم واتساب للتواصل مع المكتب', border: OutlineInputBorder())),
              const SizedBox(height: 24),

              Card(
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📌 رسوم نشر المشروع المطلوبة: $_projectFee \$', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 6),
                      const Text('سيتم خصم هذه الرسوم تلقائياً من رصيدك المتاح في المنصة عند إرسال المشروع للإدارة للموافقة.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitProject,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue),
                      child: const Text('إرسال المشروع للإدارة للموافقة', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}