import 'package:flutter/material.dart';
import '../utils/weather_color_utils.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// Weather legend widget showing VFR/MVFR/IFR/LIFR color coding
/// Helps pilots quickly understand weather conditions at a glance
class WeatherLegendWidget extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;
  
  const WeatherLegendWidget({
    super.key,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dialogBackgroundColor.withOpacity(0.95),
          borderRadius: AppTheme.defaultRadius,
          border: Border.all(
            color: AppColors.primaryAccentDim,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isExpanded ? _buildExpandedView() : _buildCollapsedView(),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'Weather',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.expand_more,
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
      ],
    );
  }

  Widget _buildExpandedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.cloud,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Flight Categories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.expand_less,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // VFR
        _buildCategoryRow(
          WeatherCategory.vfr,
          'VFR',
          'Visual Flight Rules',
          '≥3000ft ceiling, ≥5mi vis',
        ),
        const SizedBox(height: 8),
        
        // MVFR
        _buildCategoryRow(
          WeatherCategory.mvfr,
          'MVFR',
          'Marginal VFR',
          '1000-3000ft, 3-5mi',
        ),
        const SizedBox(height: 8),
        
        // IFR
        _buildCategoryRow(
          WeatherCategory.ifr,
          'IFR',
          'Instrument Flight Rules',
          '500-1000ft, 1-3mi',
        ),
        const SizedBox(height: 8),
        
        // LIFR
        _buildCategoryRow(
          WeatherCategory.lifr,
          'LIFR',
          'Low IFR',
          '<500ft ceiling, <1mi vis',
        ),
        
        const SizedBox(height: 12),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 8),
        
        // Info text
        Text(
          'Airport markers show current weather conditions',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(
    WeatherCategory category,
    String code,
    String name,
    String conditions,
  ) {
    final color = WeatherColorUtils.getCategoryColor(category);
    
    return Row(
      children: [
        // Color indicator
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        
        // Category info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                conditions,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Terrain legend widget showing clearance color coding
class TerrainLegendWidget extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;
  
  const TerrainLegendWidget({
    super.key,
    this.isExpanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dialogBackgroundColor.withOpacity(0.95),
          borderRadius: AppTheme.defaultRadius,
          border: Border.all(
            color: AppColors.primaryAccentDim,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isExpanded ? _buildExpandedView() : _buildCollapsedView(),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.terrain,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'Terrain',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.expand_more,
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
      ],
    );
  }

  Widget _buildExpandedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.terrain,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Terrain Clearance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.expand_less,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Critical
        _buildTerrainRow(
          Colors.red.shade600,
          'Critical',
          '<500ft clearance',
          'PULL UP immediately',
        ),
        const SizedBox(height: 8),
        
        // Warning
        _buildTerrainRow(
          Colors.orange.shade600,
          'Warning',
          '500-1000ft clearance',
          'Increase altitude',
        ),
        const SizedBox(height: 8),
        
        // Caution
        _buildTerrainRow(
          Colors.yellow.shade700,
          'Caution',
          '1000-2000ft clearance',
          'Monitor closely',
        ),
        const SizedBox(height: 8),
        
        // Safe
        _buildTerrainRow(
          Colors.green.shade600,
          'Safe',
          '>2000ft clearance',
          'Good separation',
        ),
        
        const SizedBox(height: 12),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 8),
        
        // Info text
        Text(
          'Terrain markers show clearance above ground',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildTerrainRow(
    Color color,
    String level,
    String clearance,
    String action,
  ) {
    return Row(
      children: [
        // Color indicator
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        
        // Level info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    level,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    clearance,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                action,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Combined weather and terrain legend panel
class WeatherTerrainLegendPanel extends StatefulWidget {
  const WeatherTerrainLegendPanel({super.key});

  @override
  State<WeatherTerrainLegendPanel> createState() => _WeatherTerrainLegendPanelState();
}

class _WeatherTerrainLegendPanelState extends State<WeatherTerrainLegendPanel> {
  bool _weatherExpanded = false;
  bool _terrainExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeatherLegendWidget(
          isExpanded: _weatherExpanded,
          onToggle: () {
            setState(() {
              _weatherExpanded = !_weatherExpanded;
              if (_weatherExpanded) {
                _terrainExpanded = false; // Collapse terrain when expanding weather
              }
            });
          },
        ),
        const SizedBox(height: 8),
        TerrainLegendWidget(
          isExpanded: _terrainExpanded,
          onToggle: () {
            setState(() {
              _terrainExpanded = !_terrainExpanded;
              if (_terrainExpanded) {
                _weatherExpanded = false; // Collapse weather when expanding terrain
              }
            });
          },
        ),
      ],
    );
  }
}
