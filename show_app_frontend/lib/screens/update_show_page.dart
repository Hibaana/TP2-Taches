import 'dart:io';
import 'dart:html' as html; // Pour le web seulement
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../config/api_config.dart';

class UpdateShowPage extends StatefulWidget {
  final int showId;
  final String initialTitle;
  final String initialDescription;
  final String initialCategory;
  final String initialImageUrl;
  final VoidCallback onUpdate;

  const UpdateShowPage({
    super.key,
    required this.showId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialCategory,
    required this.initialImageUrl,
    required this.onUpdate,
  });

  @override
  _UpdateShowPageState createState() => _UpdateShowPageState();
}

class _UpdateShowPageState extends State<UpdateShowPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  dynamic _imageFile; // Peut être File (mobile) ou XFile (web)
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _selectedCategory = widget.initialCategory;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await ImagePicker().pickImage(source: source);
      if (image != null && mounted) {
        setState(() {
          _imageFile = kIsWeb ? image : File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _updateShow() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Title and description are required!")),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isUpdating = true);

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/shows/${widget.showId}');
      final request = http.MultipartRequest('PUT', uri)
        ..fields['title'] = _titleController.text
        ..fields['description'] = _descriptionController.text
        ..fields['category'] = _selectedCategory;

      if (_imageFile != null) {
        if (kIsWeb) {
          // Solution pour le web
          final xfile = _imageFile as XFile;
          final bytes = await xfile.readAsBytes();
          final filename = path.basename(xfile.path);
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: filename,
          ));
        } else {
          // Solution pour mobile/desktop
          final file = _imageFile as File;
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            file.path,
          ));
        }
      }

      final response = await request.send();
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Show updated successfully!")),
          );
          widget.onUpdate();
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to update show: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating show: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Show"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: const [
                DropdownMenuItem(value: "movie", child: Text("Movie")),
                DropdownMenuItem(value: "anime", child: Text("Anime")),
                DropdownMenuItem(value: "serie", child: Text("Series")),
              ],
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() => _selectedCategory = value);
                }
              },
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildImagePreview(),
            const SizedBox(height: 16),
            _buildImagePickerButtons(),
            const SizedBox(height: 24),
            _buildUpdateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      if (kIsWeb) {
        final xfile = _imageFile as XFile;
        return FutureBuilder<String>(
          future: xfile.readAsBytes().then((bytes) => 
            html.Url.createObjectUrl(html.Blob([bytes]))),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.network(snapshot.data!, height: 200);
            }
            return const CircularProgressIndicator();
          },
        );
      } else {
        return Image.file(_imageFile as File, height: 200);
      }
    } else if (widget.initialImageUrl.isNotEmpty) {
      return Image.network(
        '${ApiConfig.baseUrl}${widget.initialImageUrl}',
        height: 200,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
      );
    }
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image, size: 50)),
    );
  }

  Widget _buildImagePickerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.image),
              label: const Text("Gallery"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        if (!kIsWeb) // Cache le bouton camera sur le web
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Camera"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _updateShow,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isUpdating
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Update Show",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}