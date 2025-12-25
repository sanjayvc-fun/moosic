import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AudioProvider>(context);
    final song = audio.currentSong;

    if (song == null) {
      return const Scaffold(body: Center(child: Text("No song playing")));
    }

    final thumbnail =
        song['thumbnails'] != null ? song['thumbnails'].last['url'] : '';

    return Scaffold(
      body: Stack(
        children: [
          // Background vibrant gradient based on theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF000000),
                  Color(0xFF1A1A1A),
                ],
              ),
            ),
          ),

          // Subtle background glow based on thumbnail
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 32),
                      ),
                      Text(
                        'NOW PLAYING',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _downloadSong(context, song),
                        icon: const Icon(Icons.download_for_offline_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Main Album Art with "Floaty" Look
                  Container(
                    height: MediaQuery.of(context).size.width * 0.8,
                    width: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3F51B5).withOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Container(color: Colors.grey[900]),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Song metadata
                  Column(
                    children: [
                      Text(
                        song['title'] ?? 'Unknown Title',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            song['artist'] ?? 'Unknown Artist',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(
                              audio.isLiked(song['videoId'] ?? '')
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: audio.isLiked(song['videoId'] ?? '')
                                  ? const Color(0xFF3F51B5)
                                  : Colors.white60,
                              size: 20,
                            ),
                            onPressed: () => audio.toggleLike(song),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Waveform / Custom Progress Logic
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Background bar
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      // Progress bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = audio.duration.inSeconds > 0
                              ? audio.position.inSeconds /
                                  audio.duration.inSeconds
                              : 0.0;
                          return Container(
                            height: 4,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3F51B5),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0xFF3F51B5), blurRadius: 10),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(audio.position),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                      Text(_formatDuration(audio.duration),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.shuffle,
                              color: Colors.grey, size: 24)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => audio.playPrevious(),
                            icon: const Icon(Icons.skip_previous,
                                color: Colors.white, size: 40),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () => audio.togglePlay(),
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3F51B5),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Color(0xFF3F51B5),
                                      blurRadius: 20,
                                      spreadRadius: 2),
                                ],
                              ),
                              child: Icon(
                                audio.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            onPressed: () => audio.playNext(),
                            icon: const Icon(Icons.skip_next,
                                color: Colors.white, size: 40),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => audio.toggleLoop(),
                        icon: Icon(
                          audio.loopMode == LoopMode.off
                              ? Icons.repeat
                              : (audio.loopMode == LoopMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat),
                          color: audio.loopMode == LoopMode.off
                              ? Colors.grey
                              : const Color(0xFF3F51B5),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSong(
      BuildContext context, Map<String, dynamic> song) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
        return;
      }

      final directory = await getExternalStorageDirectory();
      final moosicPath = '${directory!.path}/moosic';
      final moosicDir = Directory(moosicPath);
      if (!await moosicDir.exists()) {
        await moosicDir.create(recursive: true);
      }

      final videoId = song['videoId'];
      final title = song['title'] ?? 'unknown_song';
      // Sanitize title for filename
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final filePath = '$moosicPath/$safeTitle.mp3';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting download: $title')),
      );

      final dio = Dio();
      await dio.download(
        '$baseUrl/stream/$videoId',
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print((received / total * 100).toStringAsFixed(0) + "%");
          }
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to $moosicPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
