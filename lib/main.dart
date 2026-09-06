import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();

  bool _isLoading = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "";

  Video? _video;
  StreamManifest? _manifest;

  // ভিডিওর ফরম্যাট ও কোয়ালিটি অ্যানালাইজ করা (ইউজারের নিজস্ব আইপি দিয়ে)
  Future<void> _analyzeVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('দয়া করে একটি ইউটিউব লিংক দিন!')),
      );
      return;
    }

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
        SnackBar(content: Text('ভিডিওর তথ্য পাওয়া যায়নি: $e')),
      );
    }
  }

  // সরাসরি ডিভাইসে ফাইল ডাউনলোড করা
  Future<void> _downloadStream(StreamInfo streamInfo, String ext) async {
    await Permission.storage.request();

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = "ডাউনলোড শুরু হচ্ছে...";
    });

    try {
      final stream = _yt.videos.streamsClient.get(streamInfo);
      
      // ফোনের স্টোরেজ ডিরেক্টরি
      Directory? dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      String cleanTitle = _video!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      File file = File('${dir.path}/$cleanTitle.$ext');

      final output = file.openWrite();
      final totalBytes = streamInfo.size.totalBytes;
      int downloadedBytes = 0;

      await for (final data in stream) {
        downloadedBytes += data.length;
        output.add(data);
        setState(() {
          _progress = downloadedBytes / totalBytes;
          _statusText = "${(_progress * 100).toStringAsFixed(1)}% সম্পন্ন হয়েছে";
        });
      }

      await output.flush();
      await output.close();

      setState(() {
        _isDownloading = false;
        _statusText = "ডাউনলোড সফল হয়েছে! ✓";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green, 
          content: Text('ডাউনলোড সম্পন্ন! ফাইল সেভ হয়েছে:\n${file.path}')
        ),
      );
    } catch (e) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('ডাউনলোডে ত্রুটি: $e')),
      );
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosmoDL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Creator by Naim Islam',
                style: TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
              ),
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
                        hintText: 'Paste YouTube link here...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
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

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),

            // প্রগ্রেস বার
            if (_isDownloading)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
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

            // ভিডিওর রেজোলিউশন ও অডিও কার্ড
            if (_video != null && _manifest != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(_video!.thumbnails.highResUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text(_video!.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2),
              const SizedBox(height: 16),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text('AVAILABLE QUALITIES (VIDEO):', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),

              // ভিডিও ফরম্যাট (শুধু যেগুলো বাস্তবে আছে)
              ..._manifest!.muxed.map((stream) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.video_collection, color: Colors.cyanAccent),
                  title: Text('MP4 Video (${stream.qualityLabel})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('${stream.size.totalMegaBytes.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                    onPressed: _isDownloading ? null : () => _downloadStream(stream, 'mp4'),
                    child: const Text('Download', style: TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
              )),

              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('AUDIO FORMATS:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),

              // অডিও ফরম্যাট (M4A)
              if (_manifest!.audioOnly.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.music_note, color: Colors.greenAccent),
                    title: const Text('High Quality Audio (M4A)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('${_manifest!.audioOnly.withHighestBitrate().size.totalMegaBytes.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: _isDownloading ? null : () => _downloadStream(_manifest!.audioOnly.withHighestBitrate(), 'm4a'),
                      child: const Text('Download', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
