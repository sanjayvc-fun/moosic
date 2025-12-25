import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'now_playing_screen.dart';

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AudioProvider>(context);
    final likedSongs = audio.likedSongs;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Liked Songs',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: likedSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border,
                            size: 80, color: Colors.grey[800]),
                        const SizedBox(height: 20),
                        Text(
                          "Your liked songs will appear here",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: likedSongs.length,
                    itemBuilder: (context, index) {
                      final song = likedSongs[index];
                      // Ensuring consistency with how we access song data
                      final title = song['title'] ?? 'Unknown';
                      final artist = song['artist'] ?? 'Unknown';
                      final thumbnail = song['thumbnail'] ?? '';

                      return Dismissible(
                        key: Key(song['videoId'].toString()),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          audio.toggleLike(song);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Removed "$title" from liked songs')),
                          );
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 5),
                          onTap: () {
                            audio.setQueue(likedSongs, initialIndex: index);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const NowPlayingScreen()));
                          },
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              thumbnail,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                  width: 55,
                                  height: 55,
                                  color: Colors.grey[900]),
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artist,
                                style: TextStyle(color: Colors.grey[400]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Row(
                                children: [
                                  Icon(Icons.play_arrow,
                                      size: 12, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text("Liked",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                ],
                              )
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.thumb_up,
                                    color: Color(0xFF3F51B5), size: 20),
                                onPressed: () => audio.toggleLike(song),
                              ),
                              PopupMenuButton(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.grey, size: 20),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: 'play_next',
                                      child: Text('Play Next')),
                                ],
                                onSelected: (val) {
                                  if (val == 'play_next') {
                                    audio.addToPlayNext(song);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
