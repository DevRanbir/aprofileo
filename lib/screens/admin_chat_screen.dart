import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../widgets/thread_list_item.dart';
import '../widgets/chat_conversation.dart';
import '../widgets/admin_stats_widget.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  ChatThread? _selectedThread;
  String _searchQuery = '';
  bool _showStats = false;
  bool _sidebarVisible = true;
  late AnimationController _sidebarAnimationController;

  @override
  void initState() {
    super.initState();

    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sidebarAnimationController.forward();

    // Note: Global notification manager now handles message notifications
    // No need to listen for messages here anymore

    // Auto-hide sidebar on mobile after 3 seconds (only on very small screens)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      if (size.width < 600) {
        // Only on very small mobile screens
        Future.delayed(const Duration(seconds: 5), () {
          // Increased delay
          if (mounted && _sidebarVisible) {
            _toggleSidebar();
          }
        });
      }
    });

    // Note: Global notification manager now handles all message notifications
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sidebarAnimationController.dispose();

    // Clear currently open chat when leaving the screen
    _chatService.setCurrentlyOpenChat(null);

    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarVisible = !_sidebarVisible;
    });

    if (_sidebarVisible) {
      _sidebarAnimationController.forward();
    } else {
      _sidebarAnimationController.reverse();
    }
  }

  void _selectThread(ChatThread thread) {
    setState(() {
      _selectedThread = thread;
    });
    // Mark as read when thread is selected
    _chatService.markThreadAsRead(thread.userId);

    // Notify ChatService about currently open chat to prevent notifications
    _chatService.setCurrentlyOpenChat(thread.userId);
  }

  // Test notification function
  Future<void> _testNotification() async {
    try {
      // Check notification permission first
      final hasPermission =
          await NotificationService().isNotificationPermissionGranted();
      if (!hasPermission) {
        final granted =
            await NotificationService().requestNotificationPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Show test notification
      await NotificationService().testNotification(
        title: 'AProfileo Admin',
        body: 'This is a test notification!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _showTestDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science, color: Color(0xFFbe00ff)),
            SizedBox(width: 8),
            Text('Test Chat System'),
          ],
        ),
        content: const Text(
          'This will create a test conversation with a sample user and support response.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFbe00ff),
              foregroundColor: Colors.white,
            ),
            child: const Text('Test'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final testResult = await _chatService.testChatFlow();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                testResult['success']
                    ? 'Test completed successfully! Check user: ${testResult['testUserName']}'
                    : 'Test failed: ${testResult['error']}',
              ),
              backgroundColor:
                  testResult['success'] ? Colors.green : Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCleanupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cleanup Expired Messages'),
          ],
        ),
        content: const Text(
          'This will delete all chat messages older than 2 hours. This action cannot be undone.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final cleanupResult = await _chatService.cleanupExpiredMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cleanup completed. Deleted ${cleanupResult['deletedCount']} expired messages.',
              ),
              backgroundColor: Colors.green,
            ),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Toggle button (always visible)
            IconButton(
              icon: AnimatedRotation(
                turns: _sidebarVisible ? 0.0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _sidebarVisible ? Icons.menu_open : Icons.menu,
                  color: const Color(0xFFbe00ff),
                ),
              ),
              onPressed: _toggleSidebar,
              tooltip: _sidebarVisible ? 'Hide Sidebar' : 'Show Sidebar',
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFbe00ff).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Color(0xFFbe00ff),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSmallScreen ? 'Admin' : 'Admin Chat Dashboard',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          // Stats toggle
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _showStats
                  ? const Color(0xFFbe00ff).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                _showStats ? Icons.chat_rounded : Icons.analytics_rounded,
                color: const Color(0xFFbe00ff),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _showStats = !_showStats;
                });
              },
              tooltip: _showStats ? 'Show Chats' : 'Show Statistics',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),

          // Desktop actions
          if (!isSmallScreen) ...[
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFFbe00ff),
                  size: 20,
                ),
                onPressed: _testNotification,
                tooltip: 'Test Notification',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(
                  Icons.science_rounded,
                  color: Color(0xFFbe00ff),
                  size: 20,
                ),
                onPressed: _showTestDialog,
                tooltip: 'Test Chat System',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                onPressed: _showCleanupDialog,
                tooltip: 'Cleanup Expired Messages',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ] else ...[
            // Mobile menu
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFFbe00ff),
                  size: 20,
                ),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onSelected: (value) {
                  switch (value) {
                    case 'notification':
                      _testNotification();
                      break;
                    case 'test':
                      _showTestDialog();
                      break;
                    case 'cleanup':
                      _showCleanupDialog();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'notification',
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFFbe00ff),
                        ),
                        SizedBox(width: 8),
                        Text('Test Notification'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'test',
                    child: Row(
                      children: [
                        Icon(Icons.science_rounded, color: Color(0xFFbe00ff)),
                        SizedBox(width: 8),
                        Text('Test Chat System'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cleanup',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Cleanup Messages'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      body: _showStats
          ? const AdminStatsWidget()
          : Stack(
              children: [
                // Main Chat Area
                AnimatedBuilder(
                  animation: _sidebarAnimationController,
                  builder: (context, child) {
                    final sidebarWidth = 320.0;
                    final animationValue = _sidebarAnimationController.value;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.only(
                        left: isSmallScreen ? 0 : sidebarWidth * animationValue,
                      ),
                      child: _selectedThread != null
                          ? ChatConversation(
                              userName: _selectedThread!.userName,
                              userId: _selectedThread!.userId,
                              chatService: _chatService,
                            )
                          : Container(
                              color: const Color(0xFF121212),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFbe00ff,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFbe00ff,
                                          ).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: isSmallScreen ? 48 : 64,
                                        color: const Color(0xFFbe00ff),
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 16 : 20),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        isSmallScreen
                                            ? 'Select a conversation'
                                            : 'Select a conversation to start chatting',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        isSmallScreen
                                            ? 'Tap the menu to see conversations'
                                            : 'Choose from the conversations in the sidebar',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          color: Colors.grey.shade400,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    );
                  },
                ),

                // Animated Sidebar
                AnimatedBuilder(
                  animation: _sidebarAnimationController,
                  builder: (context, child) {
                    final sidebarWidth = 320.0;
                    final animationValue = _sidebarAnimationController.value;

                    return Transform.translate(
                      offset: Offset(
                        isSmallScreen
                            ? (1.0 - animationValue) * -sidebarWidth
                            : 0,
                        0,
                      ),
                      child: Container(
                        width: isSmallScreen
                            ? sidebarWidth
                            : sidebarWidth * animationValue,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e1e1e),
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.shade800,
                              width: 1,
                            ),
                          ),
                          boxShadow: isSmallScreen && _sidebarVisible
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(2, 0),
                                  ),
                                ]
                              : null,
                        ),
                        // Only show content when sidebar is visible or animating
                        child: (_sidebarVisible ||
                                _sidebarAnimationController.isAnimating)
                            ? Opacity(
                                opacity: animationValue,
                                child: _buildSidebarContent(isSmallScreen),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),

                // Overlay for mobile when sidebar is open
                if (isSmallScreen && _sidebarVisible)
                  GestureDetector(
                    onTap: _toggleSidebar,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      margin: const EdgeInsets.only(left: 320),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSidebarContent(bool isSmallScreen) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade800, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Header with toggle and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFbe00ff).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: Color(0xFFbe00ff),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Toggle button in sidebar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _sidebarVisible
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        color: const Color(0xFFbe00ff),
                        size: 18,
                      ),
                      onPressed: _toggleSidebar,
                      tooltip:
                          _sidebarVisible ? 'Hide Sidebar' : 'Show Sidebar',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3a3a3a),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? const Color(0xFFbe00ff).withValues(alpha: 0.5)
                        : Colors.grey.shade700,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _searchQuery.isNotEmpty
                            ? const Color(0xFFbe00ff)
                            : Colors.grey.shade500,
                      ),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? Container(
                            margin: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: _clearSearch,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              // Search results count
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                StreamBuilder<List<ChatThread>>(
                  stream: _chatService.searchThreads(_searchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final count = snapshot.data!.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFbe00ff).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          count > 0
                              ? '$count conversation${count != 1 ? 's' : ''} found'
                              : 'No conversations found',
                          style: TextStyle(
                            fontSize: 11,
                            color: count > 0
                                ? const Color(0xFFbe00ff)
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          ),
        ),
        // Thread list
        Expanded(
          child: StreamBuilder<List<ChatThread>>(
            stream: _chatService.searchThreads(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 36,
                          color: Colors.red,
                        ),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFbe00ff)),
                );
              }

              final threads = snapshot.data!;

              if (threads.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.chat_bubble_outline,
                          size: 36,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No conversations found'
                              : 'No active conversations',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'for "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final isSelected = _selectedThread?.id == thread.id;

                  return ThreadListItem(
                    thread: thread,
                    isSelected: isSelected,
                    onTap: () {
                      _selectThread(thread);
                      // Auto-hide sidebar on mobile after selection
                      if (isSmallScreen && _sidebarVisible) {
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          () => _toggleSidebar(),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
