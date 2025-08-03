import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class AdminStatsWidget extends StatefulWidget {
  const AdminStatsWidget({super.key});

  @override
  State<AdminStatsWidget> createState() => _AdminStatsWidgetState();
}

class _AdminStatsWidgetState extends State<AdminStatsWidget> {
  final ChatService _chatService = ChatService();
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await _chatService.getChatStatistics();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performCleanup() async {
    try {
      final result = await _chatService.cleanupExpiredMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cleanup completed. Deleted ${result['deletedCount']} expired threads.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Reload stats after cleanup
        _loadStats();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleanup failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isSmallScreen = false,
  }) {
    return Card(
      color: const Color(0xFF1e1e1e),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: Colors.grey.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 32,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 12,
                  color: Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMobile = screenWidth < 768;

    // Responsive grid columns
    int crossAxisCount;
    if (isSmallScreen) {
      crossAxisCount = 1; // Single column on very small screens
    } else if (isMobile) {
      crossAxisCount = 2; // Two columns on mobile
    } else {
      crossAxisCount = 3; // Three columns on tablets and desktop
    }

    if (_isLoading) {
      return Container(
        color: const Color(0xFF121212),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFbe00ff)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF121212),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Responsive layout
            if (isSmallScreen)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics,
                        color: Color(0xFFbe00ff),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Statistics Dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadStats,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFbe00ff),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.analytics,
                    color: Color(0xFFbe00ff),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Chat Statistics Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _loadStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFbe00ff),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            SizedBox(height: isSmallScreen ? 24 : 32),

            // Stats grid - Responsive layout
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isSmallScreen ? 12 : 20,
              mainAxisSpacing: isSmallScreen ? 12 : 20,
              childAspectRatio: isSmallScreen ? 2.5 : (isMobile ? 1.8 : 1.5),
              children: [
                _buildStatCard(
                  title: 'Total Conversations',
                  value: (_stats['totalThreads'] ?? 0).toString(),
                  icon: Icons.chat_bubble,
                  color: const Color(0xFFbe00ff),
                  subtitle: 'All time conversations',
                  isSmallScreen: isSmallScreen,
                ),
                _buildStatCard(
                  title: 'Recent Activity',
                  value: (_stats['recentThreads'] ?? 0).toString(),
                  icon: Icons.schedule,
                  color: Colors.orange,
                  subtitle: 'Last 24 hours',
                  isSmallScreen: isSmallScreen,
                ),
                _buildStatCard(
                  title: 'Pending Response',
                  value: (_stats['threadsWithUnreadMessages'] ?? 0).toString(),
                  icon: Icons.mark_email_unread,
                  color: Colors.red,
                  subtitle: 'Awaiting admin reply',
                  isSmallScreen: isSmallScreen,
                ),
                _buildStatCard(
                  title: 'Total Messages',
                  value: (_stats['totalMessages'] ?? 0).toString(),
                  icon: Icons.message,
                  color: Colors.blue,
                  subtitle: 'All messages sent',
                  isSmallScreen: isSmallScreen,
                ),
                _buildStatCard(
                  title: 'User Messages',
                  value: (_stats['totalUserMessages'] ?? 0).toString(),
                  icon: Icons.person_outline,
                  color: Colors.green,
                  subtitle: 'From website visitors',
                  isSmallScreen: isSmallScreen,
                ),
                _buildStatCard(
                  title: 'Support Responses',
                  value: (_stats['totalSupportMessages'] ?? 0).toString(),
                  icon: Icons.support_agent,
                  color: Colors.purple,
                  subtitle: 'Admin replies sent',
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),

            SizedBox(height: isSmallScreen ? 24 : 32),

            // Action buttons - Responsive layout
            if (isSmallScreen)
              Column(
                children: [
                  // Maintenance Actions Card
                  Card(
                    color: const Color(0xFF1e1e1e),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.delete_sweep,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Maintenance Actions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Clean up expired conversations (older than 2 hours) to keep the database optimized.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _performCleanup,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Run Cleanup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // System Information Card
                  Card(
                    color: const Color(0xFF1e1e1e),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFbe00ff),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'System Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Chat messages automatically expire after 2 hours. This admin panel helps you manage active conversations efficiently.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: const Color(0xFF1e1e1e),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.delete_sweep,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Maintenance Actions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Clean up expired conversations (older than 2 hours) to keep the database optimized.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _performCleanup,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Run Cleanup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Card(
                      color: const Color(0xFF1e1e1e),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFbe00ff),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'System Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chat messages automatically expire after 2 hours. This admin panel helps you manage active conversations efficiently.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
