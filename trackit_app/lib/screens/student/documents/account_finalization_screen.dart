import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/company_details.dart';
import '../../../models/student_profile.dart';
import '../../../services/api_client.dart';
import '../../../services/student_profile_service.dart';
import '../../../utils/ph_locations.dart';
import '../../../utils/ph_time.dart';
import '../../../widgets/student/student_ui.dart';

/// Account Details Finalization (TrackIT student mockup "OJT Final
/// Information"): the student reviews their name and enters their company,
/// address, OJT start date and supervisor -- once. After this only the
/// supervisor can be changed (System Revisions item 4).
class AccountFinalizationScreen extends StatefulWidget {
  final StudentProfileService service;
  final StudentProfile profile;

  const AccountFinalizationScreen({super.key, required this.service, required this.profile});

  @override
  State<AccountFinalizationScreen> createState() => _AccountFinalizationScreenState();
}

class _AccountFinalizationScreenState extends State<AccountFinalizationScreen> {
  static const _extensions = ['JR', 'JR.', 'SR', 'SR.', 'II', 'III', 'IV', 'V'];

  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _extension = TextEditingController();
  final _company = TextEditingController();
  final _otherProvince = TextEditingController();
  final _otherCity = TextEditingController();
  final _barangay = TextEditingController();
  final _street = TextEditingController();
  final _supervisor = TextEditingController();
  final _contact = TextEditingController();
  String? _industry;
  String? _province;
  String? _city;
  DateTime? _startDate;
  bool _submitting = false;
  String? _error;

  bool get _nameLocked {
    final at = widget.profile.nameChangeAvailableAt;
    return at != null && at.isAfter(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    // Best guess at splitting the stored full name; the student corrects it.
    final parts = widget.profile.fullName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && _extensions.contains(parts.last.toUpperCase())) {
      _extension.text = parts.removeLast();
    }
    if (parts.length > 1) {
      _last.text = parts.removeLast();
    }
    _first.text = parts.join(' ');
  }

  @override
  void dispose() {
    for (final c in [
      _first, _middle, _last, _extension, _company, _otherProvince, _otherCity,
      _barangay, _street, _supervisor, _contact,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _fullName => [_first.text, _middle.text, _last.text, _extension.text]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(' ');

  String get _provinceValue => _province == otherLocation ? _otherProvince.text.trim() : (_province ?? '');

  String get _cityValue =>
      (_province == otherLocation || _city == otherLocation) ? _otherCity.text.trim() : (_city ?? '');

  String get _address => [_street.text.trim(), _barangay.text.trim(), _cityValue, _provinceValue]
      .where((s) => s.isNotEmpty)
      .join(', ');

  Future<void> _pickStartDate() async {
    final now = nowInPh();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'OJT start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      setState(() => _error = 'Choose your OJT start date.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit your final information?'),
        content: const Text(
          'Your company details can only be entered once. After submitting, '
          'only your supervisor can be changed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Review again')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StudentColors.maroon),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final name = _fullName;
      if (!_nameLocked && name != widget.profile.fullName.trim()) {
        await widget.service.updateProfile(fullName: name);
      }
      await widget.service.submitCompanyDetails(
        CompanyDetails(
          name: _company.text.trim(),
          address: _address,
          industry: _industry!,
          supervisorName: _supervisor.text.trim(),
          contactNumber: _contact.text.trim(),
          ojtStartDate: _startDate,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop('Your final information was submitted. Good luck on your OJT!');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? v, String label) => (v == null || v.trim().isEmpty) ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    final cities = _province == null || _province == otherLocation
        ? const <String>[]
        : [...phCitiesByProvince[_province]!, otherLocation];
    final typeCity = _province == otherLocation || _city == otherLocation;
    return Scaffold(
      backgroundColor: StudentColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              color: StudentColors.maroon,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Account Details Finalization',
                      textAlign: TextAlign.center,
                      style: studentSerif(size: 22, color: Colors.white, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    const Text(
                      'OJT Final Information',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: StudentColors.heading),
                    ),
                    const Text('Review & Confirm your Final Details.', style: TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 10),
                    _Section(
                      title: 'Student Information',
                      children: [
                        if (_nameLocked)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'You changed your name recently, so it can\'t be changed again yet.',
                              style: TextStyle(fontSize: 11, color: StudentColors.muted),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _Field(
                                label: 'First Name',
                                controller: _first,
                                enabled: !_nameLocked,
                                validator: (v) => _required(v, 'First name'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: _Field(label: 'Extension (Optional)', controller: _extension, enabled: !_nameLocked),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _Field(label: 'Middle Name', controller: _middle, enabled: !_nameLocked)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _Field(
                                label: 'Last Name',
                                controller: _last,
                                enabled: !_nameLocked,
                                validator: (v) => _required(v, 'Last name'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Company Details',
                      children: [
                        _Field(
                          label: 'Company Name / Organization Name',
                          hint: 'Enter Registered / Official Company Name',
                          controller: _company,
                          validator: (v) => _required(v, 'Company name'),
                        ),
                        _Dropdown(
                          hint: 'Industry...',
                          value: _industry,
                          items: companyIndustries,
                          onChanged: (v) => setState(() => _industry = v),
                          validator: (v) => v == null ? 'Choose the industry' : null,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 6),
                          child: Text('Company Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Dropdown(
                                hint: 'Province...',
                                value: _province,
                                items: [...phCitiesByProvince.keys, otherLocation],
                                onChanged: (v) => setState(() {
                                  _province = v;
                                  _city = null;
                                }),
                                validator: (v) => v == null ? 'Choose a province' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _province == otherLocation
                                  ? _Field(
                                      label: 'Province',
                                      controller: _otherProvince,
                                      validator: (v) => _required(v, 'Province'),
                                    )
                                  : _Dropdown(
                                      // Reset when the province changes.
                                      key: ValueKey('city-$_province'),
                                      hint: 'City...',
                                      value: _city,
                                      items: cities,
                                      onChanged: (v) => setState(() => _city = v),
                                      validator: (v) => v == null ? 'Choose a city' : null,
                                    ),
                            ),
                          ],
                        ),
                        if (typeCity)
                          _Field(
                            label: 'City / Municipality',
                            controller: _otherCity,
                            validator: (v) => _required(v, 'City'),
                          ),
                        _Field(
                          label: 'Barangay',
                          hint: 'Barangay...',
                          controller: _barangay,
                          validator: (v) => _required(v, 'Barangay'),
                        ),
                        _Field(
                          label: 'House Number / Street Name',
                          hint: '123 Sample Street',
                          controller: _street,
                          validator: (v) => _required(v, 'Street'),
                        ),
                        _DateField(
                          label: 'OJT Start Date',
                          value: _startDate == null ? null : DateFormat('MMMM d, yyyy').format(_startDate!),
                          onTap: _pickStartDate,
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Supervisor Information',
                      children: [
                        _Field(
                          label: 'Name',
                          hint: 'Enter supervisor name',
                          controller: _supervisor,
                          validator: (v) => _required(v, 'Supervisor name'),
                        ),
                        _Field(
                          label: 'Contact Number',
                          hint: '0917 123 4567',
                          controller: _contact,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Contact number is required';
                            if (!RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(t)) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12.5)),
                      ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StudentColors.maroon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You confirm that all information provided is true, accurate, and complete to the best of your knowledge.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF555555)),
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: StudentCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

const _fieldFill = Color(0xFFE6E2E1);

InputDecoration _boxDecoration({String? label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B6B6B)),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
      isDense: true,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFCFCFCF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: StudentColors.maroon),
      ),
    );

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.enabled = true,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        keyboardType: keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(fontSize: 13.5),
        decoration: _boxDecoration(label: label, hint: hint),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _Dropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        validator: validator,
        hint: Text(hint, style: const TextStyle(fontSize: 13)),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1F1F1F)),
        style: const TextStyle(fontSize: 13, color: Color(0xFF1F1F1F)),
        decoration: _boxDecoration().copyWith(fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _boxDecoration(label: label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? 'Choose the date you started (or will start) your OJT',
                  style: TextStyle(fontSize: 13, color: value == null ? const Color(0xFF555555) : const Color(0xFF1F1F1F)),
                ),
              ),
              const Icon(Icons.calendar_month, size: 18, color: StudentColors.maroon),
            ],
          ),
        ),
      ),
    );
  }
}
