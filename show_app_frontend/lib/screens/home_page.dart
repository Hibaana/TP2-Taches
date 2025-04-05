import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'profile_page.dart';
import 'add_show_page.dart';
import 'update_show_page.dart';

class AppRefreshNotifier {
  static final ValueNotifier<bool> refreshHome = ValueNotifier(false);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<dynamic> movies = [];
  List<dynamic> anime = [];
  List<dynamic> series = [];
  bool isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _setupRefreshListener();
    _loadInitialData();
  }

  @override
  void dispose() {
    AppRefreshNotifier.refreshHome.removeListener(_handleRefresh);
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchShows(),
      Future.delayed(const Duration(milliseconds: 500)), // Minimum loading time
    ]);
  }

  void _setupRefreshListener() {
    AppRefreshNotifier.refreshHome.addListener(_handleRefresh);
  }

  void _handleRefresh() {
    if (AppRefreshNotifier.refreshHome.value) {
      _fetchShows();
      AppRefreshNotifier.refreshHome.value = false;
    }
  }

  Future<void> _fetchShows() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      _hasError = false;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/shows'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _processShowData(data);
      } else {
        throw http.ClientException(
          'Server responded with ${response.statusCode}',
          Uri.parse('${ApiConfig.baseUrl}/shows'),
        );
      }
    } on SocketException {
      _setError('No internet connection');
    } on TimeoutException {
      _setError('Request timed out');
    } on http.ClientException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred');
      if (kDebugMode) print(e);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  void _processShowData(List<dynamic> data) {
    if (!mounted) return;
    
    setState(() {
      movies = data.where((s) => s['category'] == 'movie').toList();
      anime = data.where((s) => s['category'] == 'anime').toList();
      series = data.where((s) => s['category'] == 'serie').toList();
      _hasError = false;
    });
  }

  Future<void> _deleteShow(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/shows/$id'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackbar('Show deleted successfully', Colors.green);
        _fetchShows();
      } else {
        throw Exception('Failed to delete show');
      }
    } on TimeoutException {
      _showSnackbar('Delete operation timed out', Colors.orange);
    } catch (e) {
      _showSnackbar('Failed to delete show', Colors.red);
      if (kDebugMode) print(e);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this show?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteShow(id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowItem(Map<String, dynamic> show) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailsDialog(show),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '${ApiConfig.baseUrl}${show['image']}',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show['title'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      show['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        show['category'].toString().toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showItemMenu(show),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemMenu(Map<String, dynamic> show) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _navigateToUpdate(show);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(show['id']);
            },
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> show) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                show['title'],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '${ApiConfig.baseUrl}${show['image']}',
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                show['description'],
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToUpdate(Map<String, dynamic> show) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateShowPage(
          showId: show['id'],
          initialTitle: show['title'],
          initialDescription: show['description'],
          initialCategory: show['category'],
          initialImageUrl: show['image'],
          onUpdate: () => AppRefreshNotifier.refreshHome.value = true,
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> shows) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _fetchShows,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (shows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.theaters, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No shows available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchShows,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: shows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildShowItem(shows[index]),
      ),
    );
  }

  Widget _getCurrentBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildContent(movies);
      case 1:
        return _buildContent(anime);
      case 2:
        return _buildContent(series);
      default:
        return const Center(child: Text('Invalid category'));
    }
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show App'),
        // Supprimé: bouton refresh dans l'AppBar
      ),
      drawer: _buildDrawer(),
      body: _getCurrentBody(),
      bottomNavigationBar: _buildBottomNavBar(),
      // Supprimé: FloatingActionButton
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Text(
              'Show App',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add Show'),
            onTap: () {
              Navigator.pop(context);
              _navigateToAddShow();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onTabTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.movie),
          label: 'Movies',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.animation),
          label: 'Anime',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.tv),
          label: 'Series',
        ),
      ],
    );
  }

  void _navigateToAddShow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddShowPage(
          onShowAdded: () => AppRefreshNotifier.refreshHome.value = true,
        ),
      ),
    );
  }
}