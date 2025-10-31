import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/recording_provider.dart';

class SaveAsTemplateScreen extends StatefulWidget {
  const SaveAsTemplateScreen({super.key});

  @override
  State<SaveAsTemplateScreen> createState() => _SaveAsTemplateScreenState();
}

class _SaveAsTemplateScreenState extends State<SaveAsTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _templateNameController = TextEditingController();
  final _categoryNameController = TextEditingController();
  String? _selectedCategory;
  bool _isCreatingNewCategory = false;

  @override
  void dispose() {
    _templateNameController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    final categoryToUse = _isCreatingNewCategory
        ? _categoryNameController.text.trim()
        : _selectedCategory;

    if (categoryToUse == null || categoryToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a category')),
      );
      return;
    }

    final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
    
    if (recordingProvider.transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript to save as template')),
      );
      return;
    }

    final success = await recordingProvider.saveTemplate(
      templateName: _templateNameController.text.trim(),
      categoryName: categoryToUse,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save template')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        final categories = recordingProvider.getCategories();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF16213E),
            elevation: 0,
            title: const Text('Save as Template'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF4A90E2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Save your transcript as a reusable template for future use',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Template Name
                    TextFormField(
                      controller: _templateNameController,
                      decoration: const InputDecoration(
                        labelText: 'Template Name',
                        hintText: 'Enter template name',
                        prefixIcon: Icon(Icons.bookmark_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter template name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Category Selection Toggle
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Existing Category'),
                            selected: !_isCreatingNewCategory,
                            onSelected: (selected) {
                              setState(() {
                                _isCreatingNewCategory = false;
                              });
                            },
                            selectedColor: const Color(0xFF4A90E2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('New Category'),
                            selected: _isCreatingNewCategory,
                            onSelected: (selected) {
                              setState(() {
                                _isCreatingNewCategory = true;
                              });
                            },
                            selectedColor: const Color(0xFF4A90E2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Category Selection/Creation
                    if (!_isCreatingNewCategory && categories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Select Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                        validator: (value) {
                          if (!_isCreatingNewCategory && (value == null || value.isEmpty)) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      )
                    else if (!_isCreatingNewCategory)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No existing categories. Create a new category below.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      TextFormField(
                        controller: _categoryNameController,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'Enter new category name',
                          prefixIcon: Icon(Icons.create_new_folder),
                        ),
                        validator: (value) {
                          if (_isCreatingNewCategory && (value == null || value.isEmpty)) {
                            return 'Please enter category name';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 30),
                    // Preview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.preview,
                                color: Color(0xFF4A90E2),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Template Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            recordingProvider.transcript.isEmpty
                                ? 'No content to preview'
                                : recordingProvider.transcript.length > 200
                                    ? '${recordingProvider.transcript.substring(0, 200)}...'
                                    : recordingProvider.transcript,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Save Button
                    ElevatedButton(
                      onPressed: _handleSaveTemplate,
                      child: const Text(
                        'Save Template',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
