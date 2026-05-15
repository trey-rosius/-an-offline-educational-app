import 'dart:ui';
import 'package:flutter/material.dart' hide Badge;
import 'package:intl/intl.dart';
import '../widgets/glass_theme.dart';
import '../models/entities.dart';
import '../objectbox.g.dart';
import '../main.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<AppUsage> _usageHistory = [];
  List<Badge> _badges = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final usageBox = objectBox.store.box<AppUsage>();
    final badgeBox = objectBox.store.box<Badge>();
    
    // Get last 14 days
    final usageQuery = usageBox.query().order(AppUsage_.dateString, flags: Order.descending).build();
    
    setState(() {
      _usageHistory = usageQuery.find().take(14).toList();
      _badges = badgeBox.getAll();
    });
    usageQuery.close();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/bg.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AppBar(
              title: const Text(
                'Study Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white.withOpacity(0.06),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _loadData,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.refresh,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + kToolbarHeight + 12,
          16,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          _buildHeader(),
          if (_badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildBadgesSection(),
          ],
          const SizedBox(height: 16),
          if (_usageHistory.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No usage data yet. Keep studying!',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
            )
          else
            _buildUsageGlassCard(),
        ],
      ),
    );
  }

  Widget _buildUsageGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          decoration: GlassTheme.panel(radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ..._usageHistory.map((u) => _buildUsageItem(u)),
            ],
          ),
        ),
      ),
    );
  }

  // Palette of distinct gradient pairs for achievement cards.
  static const List<List<Color>> _badgePalette = [
    [Color(0xFFFFD27A), Color(0xFFE89436)], // amber / gold
    [Color(0xFF7AA8FF), Color(0xFF4A6FD4)], // blue
    [Color(0xFF7CE2C9), Color(0xFF29A98B)], // mint / teal
    [Color(0xFFB199FF), Color(0xFF7B55D4)], // lavender / purple
    [Color(0xFFFF8A65), Color(0xFFD84315)], // coral / orange-red
    [Color(0xFFF06292), Color(0xFFC2185B)], // rose / pink
    [Color(0xFF80DEEA), Color(0xFF0097A7)], // cyan
    [Color(0xFFAED581), Color(0xFF558B2F)], // lime / green
  ];

  Widget _buildBadgesSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: GlassTheme.panel(radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Achievements',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _badges.length,
                  itemBuilder: (context, index) {
                    final badge = _badges[index];
                    final colors = _badgePalette[index % _badgePalette.length];
                    return Container(
                      width: 170,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.30)),
                        boxShadow: [
                          BoxShadow(
                            color: colors[1].withOpacity(0.40),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium,
                              size: 28, color: Colors.white),
                          const SizedBox(height: 4),
                          Text(
                            badge.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          Text(
                            badge.description,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    int totalSeconds =
        _usageHistory.fold(0, (sum, item) => sum + item.secondsSpent);
    String totalStr = _formatDuration(totalSeconds);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // Light frosted glass — lets the warm pink gradient show through.
            gradient: const LinearGradient(
              colors: [
                Color(0x28FFFFFF),
                Color(0x18FFFFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x40FFFFFF)),
            boxShadow: [
              BoxShadow(
                color: GlassTheme.accentBlue.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Total Study Time',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last ${_usageHistory.length} active days',
                style: const TextStyle(
                  color: Color(0xFF82B1FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageItem(AppUsage usage) {
    final DateTime date = DateTime.parse(usage.dateString);
    final String dayName = DateFormat('EEEE').format(date);
    final String dateStr = DateFormat('MMM d').format(date);
    final double minutes = usage.secondsSpent / 60;

    // Cap at 60 mins for full width
    final double progress = (minutes / 60).clamp(0.0, 1.0);
    final Color barColor =
        progress > 0.8 ? const Color(0xFF80E27E) : const Color(0xFF82B1FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              Text(
                _formatDuration(usage.secondsSpent),
                style: TextStyle(
                    color: barColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            dateStr,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55), fontSize: 12),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
