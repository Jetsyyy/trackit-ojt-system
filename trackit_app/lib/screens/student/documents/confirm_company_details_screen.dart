import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/company_details.dart';
import '../../../services/api_client.dart';
import '../../../services/student_profile_service.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/info_reminder_card.dart';

/// The student's OJT company, shown once all Startup Requirements phases
/// are complete. It is the source of truth for the Home/Profile company
/// card and is reflected as entered -- no Admin approval (System
/// Revisions item 21).
///
/// - First visit: the full form. The company name suggests matching
///   companies already saved in the system (item 8). It is a one-time
///   entry (item 4), so submitting asks for confirmation.
/// - After that: company details are view-only, but the supervisor's name
///   and contact number can still be updated (item 5).
class ConfirmCompanyDetailsScreen extends StatefulWidget {
  final StudentProfileService service;
  final CompanyDetails? existingDetails;

  const ConfirmCompanyDetailsScreen({
    super.key,
    required this.service,
    this.existingDetails,
  });

  @override
  State<ConfirmCompanyDetailsScreen> createState() =>
      _ConfirmCompanyDetailsScreenState();
}

class _ConfirmCompanyDetailsScreenState
    extends State<ConfirmCompanyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _industryController;
  late final TextEditingController _supervisorController;
  late final TextEditingController _contactController;
  late final TextEditingController _departmentController;
  final FocusNode _nameFocus = FocusNode();
  bool _saving = false;
  late DateTime _ojtStartDate;

  bool get _locked => widget.existingDetails != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingDetails;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _industryController = TextEditingController(text: existing?.industry ?? '');
    _supervisorController = TextEditingController(
      text: existing?.supervisorName ?? '',
    );
    _contactController = TextEditingController(
      text: existing?.contactNumber ?? '',
    );
    _departmentController = TextEditingController(
      text: existing?.department ?? '',
    );
    _ojtStartDate = existing?.ojtStartDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _industryController.dispose();
    _supervisorController.dispose();
    _contactController.dispose();
    _departmentController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.statRedIcon),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ojtStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _ojtStartDate = picked);
  }

  /// Waits briefly so typing doesn't fire a request per keystroke, then
  /// skips the request if the text changed in the meantime.
  Future<Iterable<CompanySuggestion>> _suggest(TextEditingValue value) async {
    final query = value.text.trim();
    if (query.length < 2) return const [];
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_nameController.text.trim() != query) return const [];
    try {
      return await widget.service.suggestCompanies(query);
    } catch (_) {
      return const [];
    }
  }

  void _applySuggestion(CompanySuggestion suggestion) {
    _nameController.text = suggestion.name;
    if ((suggestion.address ?? '').isNotEmpty) {
      _addressController.text = suggestion.address!;
    }
    if ((suggestion.industry ?? '').isNotEmpty) {
      _industryController.text = suggestion.industry!;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fix the highlighted fields before continuing.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit company details?'),
        content: Text(
          'Company: ${_nameController.text.trim()}\n'
          'OJT start: ${DateFormat('MMM d, yyyy').format(_ojtStartDate)}\n\n'
          'Company information can only be entered once and can\'t be edited '
          'afterwards. You can still update your supervisor later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMaroon,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.service.submitCompanyDetails(
        CompanyDetails(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          industry: _industryController.text.trim(),
          supervisorName: _supervisorController.text.trim(),
          contactNumber: _contactController.text.trim(),
          department: _departmentController.text.trim(),
          ojtStartDate: _ojtStartDate,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop('Company details submitted.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(
        e is ApiException ? e.message : 'Could not save. Please try again.',
      );
    }
  }

  Future<void> _updateSupervisor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.updateSupervisor(
        supervisorName: _supervisorController.text.trim(),
        contactNumber: _contactController.text.trim(),
        department: _departmentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop('Supervisor and department updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(
        e is ApiException ? e.message : 'Could not save. Please try again.',
      );
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          BackNavHeader(
            subtitle: locked ? 'Company Details' : 'Confirm Company Details',
          ),
          Expanded(
            child: Form(
              key: _formKey,
              // Per-field (not form-wide) so typing in one field doesn't flag
              // every untouched field as missing.
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InfoReminderCard(
                    message: locked
                        ? 'Your company information is final and can no longer be '
                              'edited. If your supervisor changes, update them below.'
                        : 'Start typing your company name to pick it from companies '
                              'already in the system. Company information can only be '
                              'entered once.',
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Company'),
                  if (locked)
                    _ReadOnlyField(
                      label: 'Company Name',
                      value: _nameController.text,
                    )
                  else
                    _companyNameField(),
                  const SizedBox(height: 12),
                  if (locked)
                    _ReadOnlyField(
                      label: 'Company Address',
                      value: _addressController.text,
                    )
                  else
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Company Address',
                      ),
                      validator: (v) => _required(v, 'Address'),
                    ),
                  const SizedBox(height: 12),
                  if (locked)
                    _ReadOnlyField(
                      label: 'Industry',
                      value: _industryController.text,
                    )
                  else
                    TextFormField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      controller: _industryController,
                      decoration: const InputDecoration(labelText: 'Industry'),
                      validator: (v) => _required(v, 'Industry'),
                    ),
                  const SizedBox(height: 12),
                  if (locked)
                    _ReadOnlyField(
                      label: 'OJT Start Date',
                      value: DateFormat('MMM d, yyyy').format(_ojtStartDate),
                    )
                  else
                    InkWell(
                      onTap: _pickStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'OJT Start Date',
                          helperText:
                              'Your weekly DTR and AR submissions start from this date.',
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_ojtStartDate),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const _SectionLabel('Department & Supervisor'),
                  // The department can change after deployment, like the
                  // supervisor, so it stays editable.
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _departmentController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      hintText: 'e.g. Accounting, IT Department',
                    ),
                    validator: (v) => _required(v, 'Department'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _supervisorController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor Name',
                    ),
                    validator: (v) => _required(v, 'Supervisor name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor Contact Number',
                    ),
                    validator: (v) => _required(v, 'Contact number'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : (locked ? _updateSupervisor : _submit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              locked
                                  ? 'Update Supervisor'
                                  : 'Submit Company Details',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyNameField() {
    return RawAutocomplete<CompanySuggestion>(
      textEditingController: _nameController,
      focusNode: _nameFocus,
      displayStringForOption: (option) => option.name,
      optionsBuilder: _suggest,
      onSelected: _applySuggestion,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            helperText: 'Pick a suggestion if your company is listed.',
            suffixIcon: Icon(Icons.search),
          ),
          validator: (v) => _required(v, 'Company name'),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        // TextFieldTapRegion: tapping a suggestion must not count as a tap
        // outside the field, or (on web) the field unfocuses and the list
        // closes before the tap selects anything.
        return TextFieldTapRegion(
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 260,
                  maxWidth: 480,
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          option.source == 'directory'
                              ? Icons.verified_outlined
                              : Icons.apartment_outlined,
                          color: AppColors.primaryMaroon,
                          size: 20,
                        ),
                        title: Text(option.name),
                        subtitle: Text(
                          [
                            if ((option.address ?? '').isNotEmpty)
                              option.address!,
                            option.source == 'directory'
                                ? 'HTE Directory'
                                : 'Saved by other students',
                          ].join(' Â· '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onSelected(option),
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: false,
        suffixIcon: const Icon(Icons.lock_outline, size: 18),
      ),
      child: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
    );
  }
}
