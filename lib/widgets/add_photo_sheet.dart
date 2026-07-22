// Bottom sheet for adding a photo — pick image, pin location, fill metadata.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../config/constants.dart';
import '../models/photo.dart';
import '../services/photo_store.dart';
import '../services/wfs_service.dart';

class AddPhotoSheet extends StatefulWidget {
  final LatLng initialLocation;
  final String? linkedPoiId;
  final String? linkedPoiName;

  const AddPhotoSheet({
    super.key,
    required this.initialLocation,
    this.linkedPoiId,
    this.linkedPoiName,
  });

  static Future<HistoricalPhoto?> show(
    BuildContext context, {
    required LatLng initialLocation,
    String? linkedPoiId,
    String? linkedPoiName,
  }) {
    return showModalBottomSheet<HistoricalPhoto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddPhotoSheet(
        initialLocation: initialLocation,
        linkedPoiId: linkedPoiId,
        linkedPoiName: linkedPoiName,
      ),
    );
  }

  @override
  State<AddPhotoSheet> createState() => _AddPhotoSheetState();
}

class _AddPhotoSheetState extends State<AddPhotoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController(text: 'User upload');
  final _photographerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  late LatLng _location;
  String? _linkedPoiId;
  String? _linkedPoiName;

  final _picker = ImagePicker();
  File? _pickedFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _location = widget.initialLocation;
    _linkedPoiId = widget.linkedPoiId;
    _linkedPoiName = widget.linkedPoiName;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _sourceCtrl.dispose();
    _photographerCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (file != null) setState(() => _pickedFile = File(file.path));
  }

  Future<void> _takePhoto() async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, maxWidth: 2048);
    if (file != null) setState(() => _pickedFile = File(file.path));
  }

  Future<String> _uploadToCloudinary(File file) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response =
        await request.send().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Upload failed: HTTP ${response.statusCode}');
    }
    final body = await response.stream.bytesToString();
    final url = RegExp(r'"secure_url":"([^"]+)"').firstMatch(body);
    if (url == null) throw Exception('Failed to parse upload response');
    return url.group(1)!;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick or take a photo')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final title = _titleCtrl.text.trim().isEmpty
          ? 'Untitled photo'
          : _titleCtrl.text.trim();

      final imageUrl = await _uploadToCloudinary(_pickedFile!);

      final fid = await WfsService.insertPhoto(
        title: title,
        imageUrl: imageUrl,
        location: _location,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dateTaken:
            _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
        source: _sourceCtrl.text.trim().isEmpty
            ? 'User upload'
            : _sourceCtrl.text.trim(),
        photographer: _photographerCtrl.text.trim().isEmpty
            ? null
            : _photographerCtrl.text.trim(),
        streetAddress: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        linkedPoiId: _linkedPoiId,
      );

      final photo = HistoricalPhoto(
        id: fid,
        title: title,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dateTaken: WfsService.parseDate(_dateCtrl.text.trim()),
        source: _sourceCtrl.text.trim().isEmpty
            ? 'User upload'
            : _sourceCtrl.text.trim(),
        location: _location,
        imageUrl: _pickedFile!.path,
        photographer: _photographerCtrl.text.trim().isEmpty
            ? null
            : _photographerCtrl.text.trim(),
        streetAddress: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        linkedPoiId: _linkedPoiId,
      );
      PhotoStore.add(photo);

      if (mounted) Navigator.of(context).pop(photo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to server: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Form(
        key: _formKey,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            Text('Add Historical Photo',
                style: Theme.of(context).textTheme.titleLarge),
            if (_linkedPoiName != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.link, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                    child: Text('Linked to: $_linkedPoiName',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.green))),
              ]),
            ],
            const SizedBox(height: 4),
            Text('Tap the map to set location, then fill in the details.',
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),

            Text('Location', style: _labelStyle),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                  height: 150,
                  child: FlutterMap(
                      options: MapOptions(
                          initialCenter: _location,
                          initialZoom: 15.0,
                          onTap: (_, pos) =>
                              setState(() => _location = pos)),
                      children: [
                        TileLayer(
                            urlTemplate: osmTileUrl,
                            userAgentPackageName: appPackageName),
                        MarkerLayer(markers: [
                          Marker(
                              point: _location,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.push_pin,
                                  color: Colors.red, size: 28))
                        ]),
                      ])),
            ),
            Text(
                '${_location.latitude.toStringAsFixed(5)}, ${_location.longitude.toStringAsFixed(5)}',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),

            const SizedBox(height: 14),
            Text('Photo *', style: _labelStyle),
            const SizedBox(height: 6),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Gallery'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Camera'),
              ),
            ]),
            if (_pickedFile != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_pickedFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                        height: 80,
                        color: Colors.grey.shade100,
                        child: const Center(
                            child: Text('Preview unavailable',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12))))),
              ),
            ],

            const SizedBox(height: 14),

            _field('Title', _titleCtrl, hint: 'e.g. Kaiserstrasse 1945'),
            _field('Date (YYYY-MM-DD)', _dateCtrl,
                hint: 'Unknown date is fine'),
            _field('Description', _descCtrl,
                maxLines: 3,
                hint: 'What does this photo show? Historical context?'),
            Row(children: [
              Expanded(
                  child: _field('Source', _sourceCtrl,
                      hint: 'LEO-BW / DDB / ...')),
              const SizedBox(width: 10),
              Expanded(
                  child: _field('Photographer', _photographerCtrl,
                      hint: 'e.g. Horst Schlesiger')),
            ]),
            _field('Street Address', _addressCtrl,
                hint: 'e.g. Kaiserstrasse 36, Karlsruhe'),

            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Photo'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44))),
          ],
        ),
      ),
    );
  }

  TextStyle get _labelStyle =>
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1, Widget? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            prefixIcon: prefix,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ]),
    );
  }
}
