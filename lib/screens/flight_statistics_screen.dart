import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flight_statistics_service.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Screen showing comprehensive flight statistics
class FlightStatisticsScreen extends StatelessWidget {
  const FlightStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = Provider.of<FlightStatisticsService>(context);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Flight Statistics'),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall Statistics
            _buildSectionTitle('Overall Statistics'),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'Total Flights',
              stats.totalFlights.toString(),
              Icons.flight,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Hours',
                    stats.totalHours.toStringAsFixed(1),
                    Icons.access_time,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Distance',
                    '${stats.totalDistance.toStringAsFixed(0)} nm',
                    Icons.straighten,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'Airports Visited',
              stats.airportsVisited.length.toString(),
              Icons.location_on,
              Colors.red,
            ),
            
            const SizedBox(height: 24),
            
            // This Year
            _buildSectionTitle('This Year'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Flights',
                    stats.flightsThisYear.length.toString(),
                    Icons.flight_takeoff,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Hours',
                    stats.hoursThisYear.toStringAsFixed(1),
                    Icons.timer,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // This Month
            _buildSectionTitle('This Month'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Flights',
                    stats.flightsThisMonth.length.toString(),
                    Icons.flight_land,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Hours',
                    stats.hoursThisMonth.toStringAsFixed(1),
                    Icons.schedule,
                    Colors.cyan,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Records
            _buildSectionTitle('Records'),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'Highest Altitude',
              '${stats.highestAltitude.toStringAsFixed(0)} ft',
              Icons.arrow_upward,
              Colors.deepPurple,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'Fastest Speed',
              '${stats.fastestSpeed.toStringAsFixed(0)} kts',
              Icons.speed,
              Colors.pink,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'Longest Flight',
              _formatDuration(stats.longestFlight?.duration ?? Duration.zero),
              Icons.timer_outlined,
              Colors.amber,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              context,
              'Average Flight',
              _formatDuration(stats.averageFlightDuration),
              Icons.av_timer,
              Colors.lime,
            ),
            
            const SizedBox(height: 24),
            
            // Monthly Breakdown
            _buildSectionTitle('Monthly Breakdown (This Year)'),
            const SizedBox(height: 12),
            _buildMonthlyChart(context, stats),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMonthlyChart(BuildContext context, FlightStatisticsService stats) {
    final hoursByMonth = stats.hoursByMonth;
    final maxHours = hoursByMonth.values.fold<double>(0.0, (max, hours) => hours > max ? hours : max);
    
    if (maxHours == 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.sectionBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No flights this year',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (index) {
              final month = index + 1;
              final hours = hoursByMonth[month] ?? 0.0;
              final heightPercent = maxHours > 0 ? hours / maxHours : 0.0;
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      if (hours > 0)
                        Text(
                          hours.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        height: 100 * heightPercent,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getMonthAbbr(month),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
  
  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
