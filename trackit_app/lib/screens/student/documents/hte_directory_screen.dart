import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/hte_company.dart';
import '../../../services/hte_directory_service.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/common/back_nav_header.dart';
import '../../../widgets/common/empty_state_view.dart';
import '../../../widgets/common/filter_chip_pill.dart';
import '../../../widgets/common/skeleton_list_tile.dart';
import '../../../widgets/student/documents/hte_company_card.dart';

class HteDirectoryScreen extends StatefulWidget {
  final HteDirectoryService service;

  const HteDirectoryScreen({super.key, required this.service});

  @override
  State<HteDirectoryScreen> createState() => _HteDirectoryScreenState();
}

class _HteDirectoryScreenState extends State<HteDirectoryScreen> {
  List<HteCompany> _companies = [];
  bool _loading = true;
  String _query = '';
  String? _industryFilter;
  String? _locationFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companies = await widget.service.getCompanies();
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _loading = false;
    });
  }

  List<HteCompany> get _filtered {
    return _companies.where((c) {
      final matchesQuery =
          _query.isEmpty ||
          c.name.toLowerCase().contains(_query.toLowerCase()) ||
          c.industry.toLowerCase().contains(_query.toLowerCase());
      final matchesIndustry =
          _industryFilter == null || c.industry == _industryFilter;
      final matchesLocation = _locationFilter == null || c.location == _locationFilter;
      return matchesQuery && matchesIndustry && matchesLocation;
    }).toList();
  }

  List<String> get _industries =>
      _companies.map((c) => c.industry).toSet().toList();

  List<String> get _locations =>
      _companies.map((c) => c.location).where((l) => l.isNotEmpty).toSet().toList();

  Future<void> _refresh() => _load();

  void _showCompanyDetail(HteCompany company) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompanyDetailSheet(company: company),
    );
  }

  void _openLocationFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Location',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _locationFilter,
                    decoration: const InputDecoration(labelText: 'Location'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      for (final location in _locations)
                        DropdownMenuItem(value: location, child: Text(location)),
                    ],
                    onChanged: (value) {
                      setSheetState(() => _locationFilter = value);
                      setState(() => _locationFilter = value);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          const BackNavHeader(subtitle: 'HTE Directory'),
          Expanded(
            child: _loading
                ? const SkeletonList()
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: TextField(
                                    onChanged: (v) => setState(() => _query = v),
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: InputDecoration(
                                      hintText: 'Search companies...',
                                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF7A7A7A)),
                                      prefixIcon: const Icon(Icons.search, size: 22, color: Colors.black),
                                      contentPadding: EdgeInsets.zero,
                                      filled: true,
                                      fillColor: const Color(0xFFEDEDED),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(color: Color(0xFF8A8A8A)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        borderSide: const BorderSide(color: AppColors.primaryMaroon),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _openLocationFilterSheet,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _locationFilter == null ? const Color(0xFFEDEDED) : AppColors.primaryMaroon,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF8A8A8A)),
                                  ),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    size: 20,
                                    color: _locationFilter == null ? const Color(0xFF555555) : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            FilterChipPill(
                              label: 'All',
                              selected: _industryFilter == null,
                              onTap: () => setState(() => _industryFilter = null),
                            ),
                            for (final industry in _industries)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: FilterChipPill(
                                  label: industry,
                                  selected: _industryFilter == industry,
                                  onTap: () =>
                                      setState(() => _industryFilter = industry),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.primaryMaroon,
                          onRefresh: _refresh,
                          child: _filtered.isEmpty
                              ? ListView(
                                  children: [
                                    EmptyStateView(
                                      icon: Icons.business_outlined,
                                      title: _companies.isEmpty
                                          ? 'No partner companies yet'
                                          : 'No companies found',
                                      message: _companies.isEmpty
                                          ? 'The HTE Directory will list '
                                              "partner companies once the "
                                              "department adds them."
                                          : 'Try a different search or filter.',
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                                  itemCount: _filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final company = _filtered[index];
                                    return HteCompanyCard(
                                      company: company,
                                      onTap: () => _showCompanyDetail(company),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompanyDetailSheet extends StatelessWidget {
  final HteCompany company;

  const _CompanyDetailSheet({required this.company});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.chipGrayBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                company.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                company.industry,
                style: const TextStyle(
                  color: AppColors.accentOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(icon: Icons.location_on_outlined, label: company.address),
              if (company.email.isNotEmpty)
                _DetailRow(icon: Icons.email_outlined, label: company.email),
              if (company.website != null)
                _DetailRow(icon: Icons.link, label: company.website!),
              if (company.dateAccredited != null)
                _DetailRow(
                  icon: Icons.verified_outlined,
                  label:
                      'HTE Accredited: ${DateFormat('MMMM d, y').format(company.dateAccredited!)}',
                ),
              // Contact persons are not shown to students (the companies'
              // privacy request); the server no longer sends them.
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryMaroon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
