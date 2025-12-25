import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'now_playing_screen.dart';

class RecommendedScreen extends StatefulWidget {
  const RecommendedScreen({super.key});

  @override
  State<RecommendedScreen> createState() => _RecommendedScreenState();
}

class _RecommendedScreenState extends State<RecommendedScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _recommendations = [];
  List<dynamic> _searchResults = [];
  bool _searching = false;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  List<dynamic> _moodCategories = [];
  bool _loadingMoods = true;

  final List<Color> _categoryColors = [
    Colors.blueGrey,
    Colors.orangeAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.indigoAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadRecs();
    _loadMoods();
  }

  Future<void> _loadMoods() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final data = await api.getMoods();
    if (mounted && data.isNotEmpty) {
      List<dynamic> allCategories = [];
      data.forEach((section, items) {
        if (items is List) {
          allCategories.addAll(items);
        }
      });
      setState(() {
        _moodCategories = allCategories;
        _loadingMoods = false;
      });
    }
  }

  Future<void> _loadRecs() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final shelves = await api.getRecommendations();

    List<dynamic> allSongs = [];
    for (var shelf in shelves) {
      if (shelf['contents'] != null) {
        for (var item in shelf['contents']) {
          if (item['videoId'] != null) {
            allSongs.add(item);
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _recommendations = allSongs;
      });
    }
  }

  Future<void> _loadCategoryPlaylists(String params, String title) async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _searching = true);
    _searchController.text = title;

    final results = await api.getMoodPlaylists(params);
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  Future<void> _doSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _showSuggestions = false;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    final results = await api.search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  Future<void> _updateSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final api = Provider.of<ApiService>(context, listen: false);
    final suggestions = await api.getSuggestions(query);
    if (mounted) {
      setState(() => _suggestions = suggestions);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildSearchBar(),
              if (_showSuggestions && _suggestions.isNotEmpty)
                _buildSuggestionsList(),
              const SizedBox(height: 20),
              Expanded(
                child: _searching ? _buildSearchResults() : _buildExploreView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search songs, artists...',
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    _doSearch('');
                  },
                )
              : null,
        ),
        onChanged: (val) {
          _updateSuggestions(val);
          setState(() => _showSuggestions = val.isNotEmpty);
        },
        onSubmitted: _doSearch,
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: _suggestions
            .take(5)
            .map((s) => ListTile(
                  dense: true,
                  title: Text(s, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    _searchController.text = s;
                    _doSearch(s);
                  },
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF3F51B5)));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final title = item['title'] ?? 'Unknown';
        final artist =
            (item['artists'] != null) ? item['artists'][0]['name'] : 'Unknown';
        final thumbnail =
            (item['thumbnails'] != null) ? item['thumbnails'][0]['url'] : '';

        return ListTile(
          onTap: () {
            final audio = Provider.of<AudioProvider>(context, listen: false);
            audio.setQueue(_searchResults, initialIndex: index);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
          },
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(thumbnail,
                width: 50, height: 50, fit: BoxFit.cover),
          ),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(artist, style: TextStyle(color: Colors.grey[400])),
          trailing: IconButton(
            icon: Icon(
              Provider.of<AudioProvider>(context).isLiked(item['videoId'] ?? '')
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Provider.of<AudioProvider>(context)
                      .isLiked(item['videoId'] ?? '')
                  ? const Color(0xFF3F51B5)
                  : Colors.grey,
            ),
            onPressed: () => Provider.of<AudioProvider>(context, listen: false)
                .toggleLike(item),
          ),
        );
      },
    );
  }

  Widget _buildExploreView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text('Recommended for you',
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 15),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendations.length.clamp(0, 10),
              itemBuilder: (context, index) {
                final item = _recommendations[index];
                final thumbnail = (item['thumbnails'] != null)
                    ? item['thumbnails'].last['url']
                    : '';
                return GestureDetector(
                  onTap: () {
                    final audio =
                        Provider.of<AudioProvider>(context, listen: false);
                    audio.setQueue(_recommendations, initialIndex: index);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NowPlayingScreen()));
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(thumbnail,
                              width: 140, height: 120, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                        Text(item['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          Text('Browse Categories',
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 15),
          _loadingMoods
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: _moodCategories.length,
                  itemBuilder: (context, index) {
                    final category = _moodCategories[index];
                    return GestureDetector(
                      onTap: () => _loadCategoryPlaylists(
                          category['params'], category['title']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _categoryColors[index % _categoryColors.length]
                              .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.bottomLeft,
                        child: Text(category['title'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 18)),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
