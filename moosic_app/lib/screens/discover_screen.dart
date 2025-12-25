import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'now_playing_screen.dart';
import 'liked_songs_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  Map<String, List<dynamic>> _shelves = {
    "Quick Picks": [],
    "Latest Charts": [],
    "Trending Podcasts": [],
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final quickPicks = await api.search("Trending Hits");
      final chartsData = await api.getCharts();
      final podcasts = await api.getPodcasts();

      // Extract songs from charts (Top Songs section)
      List<dynamic> chartsSongs = [];
      if (chartsData['songs'] != null &&
          chartsData['songs']['contents'] != null) {
        chartsSongs = chartsData['songs']['contents'];
      }

      if (mounted) {
        setState(() {
          _shelves["Quick Picks"] = quickPicks.take(6).toList();
          _shelves["Latest Charts"] = chartsSongs.take(6).toList();
          _shelves["Trending Podcasts"] = podcasts.take(6).toList();
          _loading = false;
        });
      }
    } catch (e) {
      print("Error loading Discover data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Greeting
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo.jpg',
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          "Welcome",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Liked Songs Entry Card
                      _buildLikedSongsCard(context),

                      const SizedBox(height: 35),

                      // Shelves
                      ..._shelves.entries
                          .map((entry) => _buildShelf(entry.key, entry.value)),

                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          "creator - snjy",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white24,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 100), // Space for MiniPlayer
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLikedSongsCard(BuildContext context) {
    final audio = Provider.of<AudioProvider>(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LikedSongsScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3F51B5), Color(0xFF1E1E1E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3F51B5).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liked Songs',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${audio.likedSongs.length} songs',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShelf(String title, List<dynamic> songs) {
    if (songs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final thumbnail =
                  (song['thumbnails'] != null && song['thumbnails'].isNotEmpty)
                      ? song['thumbnails'].last['url']
                      : '';
              return GestureDetector(
                onTap: () {
                  final audio =
                      Provider.of<AudioProvider>(context, listen: false);
                  audio.setQueue(songs, initialIndex: index);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NowPlayingScreen()));
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          thumbnail,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                              width: 140, height: 140, color: Colors.grey[900]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        song['title'] ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        song['artists'] != null
                            ? song['artists'][0]['name']
                            : 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}
