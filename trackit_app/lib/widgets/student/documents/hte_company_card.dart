import 'package:flutter/material.dart';
import '../../../models/hte_company.dart';
import '../../common/desk_ui.dart';
import '../student_ui.dart';

/// HTE Directory company card (TrackIT student mockup): industry icon box,
/// serif company name, underlined industry, a rule, then the address.
class HteCompanyCard extends StatelessWidget {
  final HteCompany company;
  final VoidCallback onTap;

  const HteCompanyCard({super.key, required this.company, required this.onTap});

  static IconData iconFor(String industry) {
    final i = industry.toLowerCase();
    if (i.contains('educ') || i.contains('school') || i.contains('univ')) return Icons.school;
    if (i.contains('gov')) return Icons.account_balance;
    if (i.contains('health') || i.contains('hospital') || i.contains('medic')) return Icons.local_hospital;
    if (i.contains('bank') || i.contains('financ')) return Icons.savings;
    if (i.contains('grocer') || i.contains('retail') || i.contains('store')) return Icons.storefront;
    if (i.contains('it') || i.contains('tech') || i.contains('software')) return Icons.computer;
    if (i.contains('media') || i.contains('broadcast')) return Icons.videocam;
    if (i.contains('hotel') || i.contains('hospitality') || i.contains('food')) return Icons.restaurant;
    if (i.contains('manufact') || i.contains('industrial')) return Icons.factory;
    return Icons.apartment;
  }

  @override
  Widget build(BuildContext context) {
    final address = company.address.isNotEmpty ? company.address : company.location;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFD9D9D9)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DeskColors.iconBox,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD9C3C3)),
                    ),
                    child: Icon(iconFor(company.industry), color: StudentColors.maroon, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: studentSerif(size: 21),
                        ),
                        Text(
                          company.industry,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: StudentColors.maroon,
                            decoration: TextDecoration.underline,
                            decorationColor: StudentColors.maroon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 54, top: 6, bottom: 6),
                child: Container(height: 1, color: const Color(0xFF3A3A3A)),
              ),
              Row(
                children: [
                  const SizedBox(width: 6),
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
