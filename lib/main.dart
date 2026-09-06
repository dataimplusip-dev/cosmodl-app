import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CosmoDLApp());
}

class CosmoDLApp extends StatelessWidget {
  const CosmoDLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmoDL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF06B6D4),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  static const platform = MethodChannel('app.cosmodl/share');

  bool _isLoading = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "";

  Video? _video;
  StreamManifest? _manifest;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkSharedIntent();
  }

  // ইউটিউব থেকে Share করে আসলে অটোমেটিক লিংক ক্যাচ করা
  Future<void> _checkSharedIntent() async {
    try {
      final String? sharedText = await platform.invokeMethod('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        RegExp regExp = RegExp(r'(https?://[^\s]+)');
        Match? match = regExp.firstMatch(sharedText);
        if (match != null) {
          _urlController.text = match.group(0)!;
          _analyzeVideo();
        }
      }
    } catch (_) {}
  }

  Future<void> _analyzeVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _video = null;
      _manifest = null;
    });

    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      setState(() {
        _video = video;
        _manifest = manifest;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ভিডিওর তথ্য আনা যায়নি: $e')),
      );
    }
  }

  // ফাইল সরাসরি ফোনের Downloads ফোল্ডারে সেভ করা
  Future<void> _downloadStream(StreamInfo streamInfo, String ext) async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = "ডাউনলোড শুরু হচ্ছে...";
    });

    try {
      final stream = _yt.videos.streamsClient.get(streamInfo);
      
      // ফোনের আসল Downloads ফোল্ডারে সেভ করার চেষ্টা
      Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!dir.existsSync()) {
          dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      String cleanTitle = _video!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      File file = File('${dir.path}/$cleanTitle.$ext');

      final output = file.openWrite();
      final totalBytes = streamInfo.size.totalBytes;
      int downloadedBytes = 0;

      await for (final data in stream) {
        downloadedBytes += data.length;
        output.add(data);
        setState(() {
          _progress = totalBytes > 0 ? (downloadedBytes / totalBytes) : 0.0;
          _statusText = "${(_progress * 100).toStringAsFixed(1)}% ডাউনলোড হয়েছে";
        });
      }

      await output.flush();
      await output.close();

      setState(() {
        _isDownloading = false;
        _statusText = "ডাউনলোড সম্পন্ন! ✓";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('ফাইল সেভ হয়েছে Downloads ফোল্ডারে:\n$cleanTitle.$ext'),
        ),
      );
    } catch (e) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('ডাউনলোডে সমস্যা: $e')),
      );
    }
  }

  @override
  void dispose() {
    _yt.close();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosmoDL', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text('By Naim Islam', style: TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ইনপুট বক্স
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Paste YouTube URL or Share from YouTube...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.purpleAccent),
                    onPressed: _analyzeVideo,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),

            // প্রগ্রেস বার
            if (_isDownloading)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text(_statusText, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _progress, color: Colors.purpleAccent, backgroundColor: Colors.grey[800]),
                  ],
                ),
              ),

            // ভিডিও রেজাল্ট এবং VIDEO / AUDIO সেকশন
            if (_video != null && _manifest != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(_video!.thumbnails.highResUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
              Text(_video!.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2),
              const SizedBox(height: 16),

              // VIDEO ও AUDIO দুটি আলাদা ট্যাব
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.purpleAccent,
                  labelColor: Colors.purpleAccent,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.video_collection), text: "VIDEO"),
                    Tab(icon: Icon(Icons.music_note), text: "AUDIO"),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // VIDEO লিস্ট
                    ListView(
                      children: [
                        ..._manifest!.video.map((stream) {
                          double mb = stream.size.totalBytes / (1024 * 1024);
                          bool hasAudio = stream is MuxedStreamInfo;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Icon(Icons.play_circle_fill, color: hasAudio ? Colors.cyanAccent : Colors.amberAccent),
                              title: Text('MP4 (${stream.qualityLabel}) ${hasAudio ? "✓ Audio সহ" : "(HD Video)"}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('${mb.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                                onPressed: _isDownloading ? null : () => _downloadStream(stream, 'mp4'),
                                child: const Text('Download', style: TextStyle(fontSize: 11, color: Colors.white)),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    // AUDIO লিস্ট
                    ListView(
                      children: [
                        ..._manifest!.audioOnly.map((stream) {
                          double mb = stream.size.totalBytes / (1024 * 1024);
                          String ext = stream.container.name == 'mp4' ? 'm4a' : stream.container.name;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.audiotrack, color: Colors.greenAccent),
                              title: Text('Audio (${stream.bitrate.kiloBitsPerSecond.round()} kbps)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('${mb.toStringAsFixed(1)} MB • $ext', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: _isDownloading ? null : () => _downloadStream(stream, ext),
                                child: const Text('Download', style: TextStyle(fontSize: 11, color: Colors.white)),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
