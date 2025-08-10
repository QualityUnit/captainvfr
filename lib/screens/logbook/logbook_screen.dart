import 'package:flutter/material.dart';
import 'logbook_summary_tab.dart';
import 'logbook_entries_tab.dart';
import 'pilots_tab.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class LogBookScreen extends StatefulWidget {
  final int initialTab;
  
  const LogBookScreen({super.key, this.initialTab = 0});

  @override
  State<LogBookScreen> createState() => _LogBookScreenState();
}

class _LogBookScreenState extends State<LogBookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.logBook,
          style: const TextStyle(color: AppColors.primaryTextColor),
        ),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryAccent,
          labelColor: AppColors.primaryTextColor,
          unselectedLabelColor: AppColors.secondaryTextColor,
          tabs: [
            Tab(text: l10n.summary, icon: const Icon(Icons.dashboard)),
            Tab(text: l10n.logs, icon: const Icon(Icons.list_alt)),
            Tab(text: l10n.pilots, icon: const Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LogBookSummaryTab(),
          LogBookEntriesTab(),
          PilotsTab(),
        ],
      ),
    );
  }
}