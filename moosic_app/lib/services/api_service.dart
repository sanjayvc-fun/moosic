import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Change this to your machine's IP if running on real device
// Android Emulator uses 10.0.2.2. iOS uses 127.0.0.1.
const String baseUrl = 'http://10.0.2.2:8000';

class ApiService {
  Future<List<dynamic>> search(String query) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/search?q=$query'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("Search Error: $e");
      return [];
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/suggestions?q=$query'));
      if (response.statusCode == 200) {
        return List<String>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print("Suggestions Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> getRecommendations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/recommendations'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("Recs Error: $e");
      return [];
    }
  }

  String getStreamUrl(String videoId) {
    return '$baseUrl/stream/$videoId';
  }

  Future<Map<String, dynamic>> getMoods() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/moods'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print("Moods Error: $e");
      return {};
    }
  }

  Future<List<dynamic>> getMoodPlaylists(String params) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/mood_playlists?params=$params'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("Mood Playlists Error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getCharts({String? country}) async {
    try {
      final url = country != null
          ? '$baseUrl/charts?country=$country'
          : '$baseUrl/charts';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print("Charts Error: $e");
      return {};
    }
  }

  Future<List<dynamic>> getPodcasts({String q = "Podcasts"}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/podcasts?q=$q'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("Podcasts Error: $e");
      return [];
    }
  }
}

enum LoopMode { off, one, all }

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ApiService _api = ApiService();

  List<dynamic> _queue = [];
  List<dynamic> _playNextQueue = [];
  List<dynamic> _likedSongs = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  LoopMode _loopMode = LoopMode.off;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  Map<String, dynamic>? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;
  bool get isPlaying => _isPlaying;
  LoopMode get loopMode => _loopMode;
  Duration get duration => _duration;
  Duration get position => _position;
  List<dynamic> get queue => _queue;
  List<dynamic> get likedSongs => _likedSongs;

  AudioProvider() {
    _init();
    _loadLikedSongs();
  }

  Future<void> _init() async {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _player.onPlayerComplete.listen((event) {
      if (_loopMode == LoopMode.one) {
        if (currentSong != null) play(currentSong!);
      } else {
        playNext();
      }
    });

    _player.onLog.listen((msg) {
      print("AudioPlayer Log: $msg");
    });
  }

  Future<void> _loadLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final likedJson = prefs.getString('liked_songs');
    if (likedJson != null) {
      _likedSongs = json.decode(likedJson);
      notifyListeners();
    }
  }

  Future<void> _saveLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('liked_songs', json.encode(_likedSongs));
  }

  bool isLiked(String videoId) {
    return _likedSongs.any((s) => s['videoId'] == videoId);
  }

  void toggleLike(Map<String, dynamic> song) {
    final videoId = song['videoId'];
    if (isLiked(videoId)) {
      _likedSongs.removeWhere((s) => s['videoId'] == videoId);
    } else {
      _likedSongs.add(song);
    }
    _saveLikedSongs();
    notifyListeners();
  }

  void addToPlayNext(Map<String, dynamic> song) {
    _playNextQueue.add(song);
    notifyListeners();
  }

  void setQueue(List<dynamic> songs, {int initialIndex = 0}) {
    _queue = songs;
    _currentIndex = initialIndex;
    if (_queue.isNotEmpty) {
      play(currentSong!);
    }
  }

  Future<void> play(Map<String, dynamic> song) async {
    try {
      // Normalize song data for UI consistency
      if (song['thumbnails'] != null && song['thumbnails'] is List) {
        song['thumbnail'] = song['thumbnails'].last['url'];
      }
      if (song['artist'] == null && song['artists'] != null) {
        song['artist'] = song['artists'][0]['name'];
      }

      // Update index if song is in queue, otherwise add it
      final index =
          _queue.indexWhere((element) => element['videoId'] == song['videoId']);
      if (index != -1) {
        _currentIndex = index;
      } else {
        _queue.insert(_currentIndex + 1, song);
        _currentIndex++;
      }

      final videoId = song['videoId'];
      final url = _api.getStreamUrl(videoId);

      print("Starting playback for $videoId: $url");

      await _player.stop();
      await _player.play(UrlSource(url));
      notifyListeners();
    } catch (e) {
      print("Playback Error: $e");
    }
  }

  Future<void> playNext() async {
    if (_playNextQueue.isNotEmpty) {
      final nextSong = _playNextQueue.removeAt(0);
      await play(nextSong);
      return;
    }

    if (_queue.isNotEmpty) {
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        await play(currentSong!);
      } else if (_loopMode == LoopMode.all) {
        _currentIndex = 0;
        await play(currentSong!);
      }
    }
  }

  Future<void> playPrevious() async {
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      await play(currentSong!);
    }
  }

  void toggleLoop() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }
}
