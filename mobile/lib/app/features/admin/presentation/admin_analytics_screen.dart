import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/widgets/app_drawer.dart';
import '../../common/widgets/shared_widgets.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  List _weekly = [];
  List _topics = [];
  List _tests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        dioClient.get(ApiEndpoints.adminAnalyticsWeekly),
        dioClient.get(ApiEndpoints.adminAnalyticsTopics),
        dioClient.get(ApiEndpoints.adminAnalyticsTests),
      ]);
      if (mounted) {
        setState(() {
          _weekly = res[0].data['items'] ?? [];
          _topics = res[1].data['items'] ?? [];
          _tests = res[2].data['items'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, formatApiError(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Platform Analytics',
      showBack: true,
      parentRoute: '/admin',
      body: _loading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INSIGHTS',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.violet)),
                  const SizedBox(height: 4),
                  Text('Platform Analytics',
                      style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.navy)),
                  const SizedBox(height: 20),

                  // Weekly Activity Chart (Attempts & Registrations)
                  if (_weekly.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('14-DAY ACTIVITY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.blue)),
                          const SizedBox(height: 4),
                          Text('Test attempts per day', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true, drawVerticalLine: false),
                                titlesData: const FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _weekly.asMap().entries.map((e) {
                                      final double y = (e.value['attempts'] as num?)?.toDouble() ?? 0.0;
                                      return FlSpot(e.key.toDouble(), y);
                                    }).toList(),
                                    isCurved: true,
                                    color: AppColors.blue,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Topic Performance List
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOPIC PERFORMANCE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.violet)),
                        const SizedBox(height: 12),
                        if (_topics.isEmpty)
                          Text('No attempt data by topic yet.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500))
                        else
                          ..._topics.map((t) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('${t['topic']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy))),
                                    Text('${t['attempts']} attempts', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
                                    const SizedBox(width: 12),
                                    Text('${t['pass_rate']}% correct', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Test Summaries List
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TEST SUMMARIES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.navy)),
                        const SizedBox(height: 12),
                        if (_tests.isEmpty)
                          Text('No published tests yet.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500))
                        else
                          ..._tests.map((t) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${t['title']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                                          Text('${t['attempts']} total attempts', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500)),
                                        ],
                                      ),
                                    ),
                                    Text('Avg ${t['avg_percent']}%', style: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.violet, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
