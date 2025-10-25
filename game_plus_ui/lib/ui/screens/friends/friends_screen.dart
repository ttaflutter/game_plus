import 'package:flutter/material.dart';
import 'package:game_plus/services/friend_service.dart';
import 'package:game_plus/models/friend_model.dart';
import 'package:game_plus/ui/screens/caro/widgets/custom_bottom_nav.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FriendUser> _friends = [];
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        FriendService.getFriends(),
        FriendService.getReceivedRequests(),
        FriendService.getSentRequests(),
      ]);

      setState(() {
        _friends = results[0] as List<FriendUser>;
        _receivedRequests = results[1] as List<FriendRequest>;
        _sentRequests = results[2] as List<FriendRequest>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFriend(int friendId) async {
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Đang xử lý...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      await FriendService.removeFriend(friendId);

      // Refresh data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã hủy kết bạn')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    }
  }

  Future<void> _respondToRequest(int requestId, String action) async {
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Đang xử lý...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      await FriendService.respondToRequest(requestId, action);

      // Refresh data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'accept' ? 'Đã chấp nhận' : 'Đã từ chối'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    }
  }

  Future<void> _cancelRequest(int requestId) async {
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Đang xử lý...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      await FriendService.cancelFriendRequest(requestId);

      // Refresh data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã hủy lời mời')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _SearchUserDialog(onRequestSent: _loadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showSearchDialog,
            tooltip: 'Tìm bạn bè',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Bạn bè',
              icon: Badge(
                label: Text('${_friends.length}'),
                child: const Icon(Icons.people),
              ),
            ),
            Tab(
              text: 'Lời mời',
              icon: Badge(
                label: Text('${_receivedRequests.length}'),
                isLabelVisible: _receivedRequests.isNotEmpty,
                child: const Icon(Icons.mail),
              ),
            ),
            Tab(
              text: 'Đã gửi',
              icon: Badge(
                label: Text('${_sentRequests.length}'),
                isLabelVisible: _sentRequests.isNotEmpty,
                child: const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lỗi: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(),
                _buildReceivedRequestsList(),
                _buildSentRequestsList(),
              ],
            ),
      bottomNavigationBar: CustomBottomNav(currentIndex: 1),
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return const Center(child: Text('Chưa có bạn bè nào'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(friend.username[0].toUpperCase()),
            ),
            title: Text(friend.username),
            subtitle: Row(
              children: [
                const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${friend.rating}'),
                if (friend.isOnline == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Online'),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Hủy kết bạn'),
                ),
              ],
              onSelected: (value) {
                if (value == 'remove') {
                  _showRemoveFriendDialog(friend);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceivedRequestsList() {
    if (_receivedRequests.isEmpty) {
      return const Center(child: Text('Không có lời mời nào'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(request.senderUsername[0].toUpperCase()),
            ),
            title: Text(request.senderUsername),
            subtitle: Text(
              _formatDate(request.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _respondToRequest(request.id, 'accept'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _respondToRequest(request.id, 'reject'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentRequestsList() {
    if (_sentRequests.isEmpty) {
      return const Center(child: Text('Chưa gửi lời mời nào'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(request.receiverUsername[0].toUpperCase()),
            ),
            title: Text(request.receiverUsername),
            subtitle: Text(
              _formatDate(request.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: TextButton(
              onPressed: () => _cancelRequest(request.id),
              child: const Text('Hủy'),
            ),
          );
        },
      ),
    );
  }

  void _showRemoveFriendDialog(FriendUser friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy kết bạn'),
        content: Text('Bạn có chắc muốn hủy kết bạn với ${friend.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend.id);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}

class _SearchUserDialog extends StatefulWidget {
  final VoidCallback onRequestSent;

  const _SearchUserDialog({required this.onRequestSent});

  @override
  State<_SearchUserDialog> createState() => _SearchUserDialogState();
}

class _SearchUserDialogState extends State<_SearchUserDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<FriendUser> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await FriendService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _sendRequest(String username) async {
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Đang gửi...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      await FriendService.sendFriendRequest(username);

      // Refresh parent data
      widget.onRequestSent();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã gửi lời mời kết bạn')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Tìm bạn bè',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Nhập username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text('Lỗi: $_error')))
            else if (_searchResults.isEmpty &&
                _searchController.text.isNotEmpty)
              const Expanded(
                child: Center(child: Text('Không tìm thấy người dùng')),
              )
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.username[0].toUpperCase()),
                      ),
                      title: Text(user.username),
                      subtitle: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text('${user.rating}'),
                        ],
                      ),
                      trailing: user.isFriend == true
                          ? const Chip(label: Text('Bạn bè'))
                          : user.hasPendingRequest == true
                          ? const Chip(label: Text('Đã gửi'))
                          : ElevatedButton(
                              onPressed: () => _sendRequest(user.username),
                              child: const Text('Kết bạn'),
                            ),
                    );
                  },
                ),
              )
            else
              const Expanded(
                child: Center(child: Text('Nhập username để tìm kiếm')),
              ),
          ],
        ),
      ),
    );
  }
}
