import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AddShowPage extends StatefulWidget {
  final Function() onShowAdded;
  
  const AddShowPage({super.key, required this.onShowAdded});

  @override
  _AddShowPageState createState() => _AddShowPageState();
}

class _AddShowPageState extends State<AddShowPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'movie';
  XFile? _pickedFile; // Changé de File? à XFile?
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  Uint8List? _webImage; // Pour stocker l'image sur le web

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImage = bytes;
          _pickedFile = image;
        });
      } else {
        setState(() {
          _pickedFile = image;
        });
      }
    }
  }

  Future<void> _addShow() async {
    if (_titleController.text.isEmpty || 
        _descriptionController.text.isEmpty || 
        _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tous les champs sont obligatoires!")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${ApiConfig.baseUrl}/shows')
      );
      
      request.fields['title'] = _titleController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['category'] = _selectedCategory;

      // Gestion multiplateforme de l'image
      if (kIsWeb && _webImage != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          _webImage!,
          filename: _pickedFile!.name,
        ));
      } else if (!kIsWeb && _pickedFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _pickedFile!.path,
        ));
      }

      var response = await request.send();
      
      if (response.statusCode == 201) {
        widget.onShowAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Show ajouté avec succès!")),
        );
      } else {
        throw Exception('Échec de l\'ajout');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajouter un Show"),
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
                labelText: "Titre",
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
                DropdownMenuItem(value: "movie", child: Text("Film")),
                DropdownMenuItem(value: "anime", child: Text("Anime")),
                DropdownMenuItem(value: "serie", child: Text("Série")),
              ],
              onChanged: (value) => setState(() => _selectedCategory = value!),
              decoration: const InputDecoration(
                labelText: "Catégorie",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            // Affichage de l'image sélectionnée
            _pickedFile == null
                ? const Center(child: Text("Aucune image sélectionnée"))
                : kIsWeb
                    ? Image.memory(_webImage!, height: 200, fit: BoxFit.cover)
                    : Image.file(File(_pickedFile!.path), height: 200, fit: BoxFit.cover),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.image),
                  label: const Text("Galerie"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Appareil photo"),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addShow,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: const Text(
                        "Ajouter le Show",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}