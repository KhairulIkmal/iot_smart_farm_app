import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        title: const Text('Data Sources & Licenses'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Crop threshold recommendations in AgroEzuran are derived from the following peer-reviewed and institutional agricultural references.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: ThemeColors.textSecondary(context).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),

          _buildSourceCard(
            context,
            index: '01',
            shortName: 'FAO-56',
            fullName: 'Crop Evapotranspiration — Guidelines for Computing Crop Water Requirements',
            publisher: 'Food and Agriculture Organization of the United Nations (FAO)',
            year: '1998',
            authors: 'Allen, R.G., Pereira, L.S., Raes, D., Smith, M.',
            usage: 'Soil moisture thresholds, irrigation frequency, and crop water stress benchmarks for all supported crops.',
            color: const Color(0xFF3B82F6),
            icon: Icons.water_drop_outlined,
          ),

          _buildSourceCard(
            context,
            index: '02',
            shortName: 'UF/IFAS HS1207',
            fullName: 'Vegetable Production Handbook of Florida',
            publisher: 'University of Florida Institute of Food and Agricultural Sciences (UF/IFAS)',
            year: '2022–2023',
            authors: 'Vegetable Horticulture, UF/IFAS Extension',
            usage: 'pH ranges, temperature optima, and humidity guidelines for tomato, pepper, cucumber, and leafy vegetables.',
            color: const Color(0xFFF97316),
            icon: Icons.menu_book_outlined,
          ),

          _buildSourceCard(
            context,
            index: '03',
            shortName: 'UC IPM',
            fullName: 'Pest Management Guidelines & Crop Production Resources',
            publisher: 'University of California Statewide Integrated Pest Management Program (UC IPM)',
            year: '2023',
            authors: 'UC Agriculture and Natural Resources',
            usage: 'Optimal growing conditions, temperature ranges, and soil pH recommendations for chili, carrot, onion, and potato.',
            color: const Color(0xFF13EC37),
            icon: Icons.science_outlined,
          ),

          _buildSourceCard(
            context,
            index: '04',
            shortName: 'NHB India',
            fullName: 'Package of Practices for Vegetable Crops',
            publisher: 'National Horticulture Board, Ministry of Agriculture & Farmers Welfare, Government of India',
            year: '2021',
            authors: 'NHB Technical Division',
            usage: 'Soil moisture and humidity thresholds adapted for tropical growing conditions, particularly relevant for Malaysian climate contexts.',
            color: const Color(0xFFA855F7),
            icon: Icons.eco_outlined,
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Text(
                      'Disclaimer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ThemeColors.textSecondary(context).withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Threshold values are general recommendations adapted from the above sources. Actual crop requirements may vary based on local soil conditions, variety, and climate. Always consult a qualified agronomist for site-specific guidance.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(
    BuildContext context, {
    required String index,
    required String shortName,
    required String fullName,
    required String publisher,
    required String year,
    required String authors,
    required String usage,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: ThemeColors.border(context))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        Text(
                          year,
                          style: TextStyle(
                            fontSize: 11,
                            color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.textPrimary(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _row(context, 'Publisher', publisher),
                  const SizedBox(height: 4),
                  _row(context, 'Authors', authors),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded, size: 14, color: color.withOpacity(0.6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            usage,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: ThemeColors.textSecondary(context).withOpacity(0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: ThemeColors.textSecondary(context).withOpacity(0.4),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(context).withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
