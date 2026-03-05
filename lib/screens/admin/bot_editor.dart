import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class BotEditorModal extends StatefulWidget {
  final Map<String, dynamic>? botData; // null means create new
  final Function() onSaved;

  const BotEditorModal({super.key, this.botData, required this.onSaved});

  @override
  State<BotEditorModal> createState() => _BotEditorModalState();
}

class _BotEditorModalState extends State<BotEditorModal> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();
  bool _isLoading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _botIdCtrl;
  late TextEditingController _sbrCtrl;
  late TextEditingController _colorCtrl;
  late TextEditingController _avatarCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _backgroundCtrl;
  late TextEditingController _personalityCtrl;
  late TextEditingController _chatExamplesCtrl;
  late TextEditingController _birthdayCtrl;

  @override
  void initState() {
    super.initState();
    final b = widget.botData ?? {};
    _nameCtrl = TextEditingController(text: b['name'] ?? '');
    _botIdCtrl = TextEditingController(text: b['bot_id'] ?? '');
    _sbrCtrl = TextEditingController(text: b['sbr'] ?? '');
    _colorCtrl = TextEditingController(text: b['color'] ?? '');
    _avatarCtrl = TextEditingController(text: b['avatar'] ?? '');
    _descCtrl = TextEditingController(text: b['description'] ?? '');
    _backgroundCtrl = TextEditingController(text: b['background'] ?? '');
    _personalityCtrl = TextEditingController(text: b['personality'] ?? '');
    _chatExamplesCtrl = TextEditingController(text: b['chat_examples'] ?? '');
    _birthdayCtrl = TextEditingController(text: b['birthday'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _botIdCtrl.dispose();
    _sbrCtrl.dispose();
    _colorCtrl.dispose();
    _avatarCtrl.dispose();
    _descCtrl.dispose();
    _backgroundCtrl.dispose();
    _personalityCtrl.dispose();
    _chatExamplesCtrl.dispose();
    _birthdayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'name': _nameCtrl.text,
      'bot_id': _botIdCtrl.text,
      'sbr': _sbrCtrl.text.isNotEmpty ? _sbrCtrl.text : null,
      'color': _colorCtrl.text.isNotEmpty ? _colorCtrl.text : null,
      'avatar': _avatarCtrl.text.isNotEmpty ? _avatarCtrl.text : null,
      'description': _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
      'background': _backgroundCtrl.text.isNotEmpty ? _backgroundCtrl.text : null,
      'personality': _personalityCtrl.text.isNotEmpty ? _personalityCtrl.text : null,
      'chat_examples': _chatExamplesCtrl.text.isNotEmpty ? _chatExamplesCtrl.text : null,
      'birthday': _birthdayCtrl.text.isNotEmpty ? _birthdayCtrl.text : null,
    };

    bool success;
    if (widget.botData == null) {
      success = await _adminService.createBot(data);
    } else {
      success = await _adminService.updateBot(widget.botData!['id'], data);
    }

    setState(() => _isLoading = false);

    if (success) {
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save bot. Check console for details.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.botData == null ? 'Registrasi Murid Baru' : 'Edit Data Murid',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildField(_nameCtrl, 'Nama Tampilan', true),
              _buildField(_botIdCtrl, 'Karakter/Bot ID (Unik)', true),
              _buildField(_sbrCtrl, 'Asal Sekolah', false),
              _buildField(_colorCtrl, 'Warna Tema (Hex, cth: #FFFFFF)', false),
              _buildField(_avatarCtrl, 'URL Avatar / Path', false),
              _buildField(_birthdayCtrl, 'Tanggal Lahir (YYYY-MM-DD)', false),
              _buildField(_descCtrl, 'Deskripsi Singkat', false, maxLines: 2),
              _buildField(_personalityCtrl, 'Personality', false, maxLines: 3),
              _buildField(_backgroundCtrl, 'Background Story', false, maxLines: 4),
              _buildField(_chatExamplesCtrl, 'Contoh Chat / Prompts', false, maxLines: 4),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF135ACF),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Data Murid', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, bool required, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.withOpacity(0.1),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
      ),
    );
  }
}
