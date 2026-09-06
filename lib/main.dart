import 'dart:io';
import 'dart:math';
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
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  static const platform = MethodChannel('app.cosmodl/share');
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    _checkSharedIntent();
  }

  Future<void> _checkSharedIntent() async {
    try {
      final String? sharedText = await platform.invokeMethod('getSharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        RegExp regExp = RegExp(r'(https?://[^\s]+)');
        Match? match = regExp.firstMatch(sharedText);
        if (match != null) {
          setState(() => _currentIndex = 1); // Switch to Paste Link tab
          LinkDownloaderTab.urlController.text = match.group(0)!;
          LinkDownloaderTab.analyzeSharedVideo?.call();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ExploreFeedTab(yt: _yt),
          LinkDownloaderTab(yt: _yt),
          const DownloadsManagerTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF070D1E),
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
          BottomNavigationBarItem(icon: Icon(Icons.link), label: "Paste Link"),
          BottomNavigationBarItem(icon: Icon(Icons.download_done_rounded), label: "Downloads"),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 1: VidMate স্টাইল ইউটিউব এক্সপ্লোর ও সার্চ ট্যাব
// ----------------------------------------------------
class ExploreFeedTab extends StatefulWidget {
  final YoutubeExplode yt;
  const ExploreFeedTab({super.key, required this.yt});

  @override
  State<ExploreFeedTab> createState() => _ExploreFeedTabState();
}

class _ExploreFeedTabState extends State<ExploreFeedTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Video> _videos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialVideos('Bangla new music video');
  }

  Future<void> _loadInitialVideos(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.yt.search.search(query);
      setState(() {
        _videos = results.take(15).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openDownloadModal(Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1836),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DownloadBottomSheet(video: video, yt: widget.yt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosmoDL Explore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14.0),
            child: Center(child: Text('By Naim Islam', style: TextStyle(fontSize: 10, color: Colors.purpleAccent))),
          )
        ],
      ),
      body: Column(
        children: [
          // সার্চ বার
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _searchController,
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) _loadInitialVideos(val.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Search YouTube videos, songs, natok...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.cyanAccent),
                    onPressed: () {
                      if (_searchController.text.trim().isNotEmpty) {
                        _loadInitialVideos(_searchController.text.trim());
                      }
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : ListView.builder(
                    itemCount: _videos.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final v = _videos[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Image.network(v.thumbnails.highResUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
                                ),
                                if (v.duration != null)
                                  Positioned(
                                    bottom: 8, right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                                      child: Text(v.duration.toString().split('.').first, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(v.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(v.author, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // ডাউনলোড বাটন
                                  InkWell(
                                    onTap: () => _openDownloadModal(v),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.download, size: 20, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

// ----------------------------------------------------
// TAB 2: লিংক পেস্ট করে ডাউনলোড করার ট্যাব
// ----------------------------------------------------
class LinkDownloaderTab extends StatefulWidget {
  final YoutubeExplode yt;
  static final TextEditingController urlController = TextEditingController();
  static VoidCallback? analyzeSharedVideo;

  const LinkDownloaderTab({super.key, required this.yt});

  @override
  State<LinkDownloaderTab> createState() => _LinkDownloaderTabState();
}

class _LinkDownloaderTabState extends State<LinkDownloaderTab> {
  bool _isLoading = false;
  Video? _video;

  @override
  void initState() {
    super.initState();
    LinkDownloaderTab.analyzeSharedVideo = _analyze;
  }

  Future<void> _analyze() async {
    final url = LinkDownloaderTab.urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _video = null;
    });

    try {
      final video = await widget.yt.videos.get(url);
      setState(() {
        _video = video;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paste Link Downloader'), centerTitle: true, backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: LinkDownloaderTab.urlController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(hintText: 'Paste YouTube link here...', border: InputBorder.none),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.search, color: Colors.purpleAccent), onPressed: _analyze),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(color: Colors.purpleAccent),
            if (_video != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_video!.thumbnails.highResUrl, height: 180, width: double.infinity, fit: BoxFit.cover)),
              const SizedBox(height: 10),
              Text(_video!.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, minimumSize: const Size(double.infinity, 45)),
                icon: const Icon(Icons.download),
                label: const Text('Select Quality & Download'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF0D1836),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (context) => DownloadBottomSheet(video: _video!, yt: widget.yt),
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 3: ডাউনলোড হওয়া ফাইল দেখার ম্যানেজার
// ----------------------------------------------------
class DownloadsManagerTab extends StatefulWidget {
  const DownloadsManagerTab({super.key});

  @override
  State<DownloadsManagerTab> createState() => _DownloadsManagerTabState();
}

class _DownloadsManagerTabState extends State<DownloadsManagerTab> {
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    if (dir.existsSync()) {
      setState(() {
        _files = dir!.listSync().where((f) => f.path.endsWith('.mp4') || f.path.endsWith('.m4a') || f.path.endsWith('.webm')).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Downloads'), centerTitle: true, backgroundColor: Colors.transparent),
      body: _files.isEmpty
          ? const Center(child: Text('কোনো ডাউনলোড ফাইল পাওয়া যায়নি!', style: TextStyle(color: Colors.grey, fontSize: 13)))
          : ListView.builder(
              itemCount: _files.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final file = _files[index];
                final name = file.path.split('/').last;
                final isAudio = name.endsWith('.m4a') || name.endsWith('.webm');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(isAudio ? Icons.music_note : Icons.movie, color: isAudio ? Colors.greenAccent : Colors.cyanAccent),
                    title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1),
                    subtitle: Text(file.path, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1),
                  ),
                );
              },
            ),
    );
  }
}

// ----------------------------------------------------
// ডাউনলোড পপ-আপ মডাল (VIDEO এবং AUDIO সেকশন সহ)
// ----------------------------------------------------
class DownloadBottomSheet extends StatefulWidget {
  final Video video;
  final YoutubeExplode yt;
  const DownloadBottomSheet({super.key, required this.video, required this.yt});

  @override
  State<DownloadBottomSheet> createState() => _DownloadBottomSheetState();
}

class _DownloadBottomSheetState extends State<DownloadBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamManifest? _manifest;
  bool _loading = true;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String _status = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    try {
      final manifest = await widget.yt.videos.streamsClient.getManifest(widget.video.id);
      setState(() {
        _manifest = manifest;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ১০০% গ্যারান্টিড অডিও ও ভিডিও ডাউনলোড ইঞ্জিন (বড় নামের ক্র্যাশ ফিক্স)
  Future<void> _executeDownload(StreamInfo streamInfo, String ext) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _status = "শুরু হচ্ছে...";
    });

    try {
      final stream = widget.yt.videos.streamsClient.get(streamInfo);

      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();

      // ফাইলের নাম ছোট করা যাতে অ্যান্ড্রয়েড ক্র্যাশ না করে
      String cleanTitle = widget.video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (cleanTitle.length > 35) cleanTitle = cleanTitle.substring(0, 35);
      
      final file = File('${dir.path}/$cleanTitle.$ext');
      final output = file.openWrite();
      final total = streamInfo.size.totalBytes;
      int downloaded = 0;

      await for (final chunk in stream) {
        downloaded += chunk.length;
        output.add(chunk);
        setState(() {
          _downloadProgress = total > 0 ? (downloaded / total) : 0.0;
          _status = "${(_downloadProgress * 100).toStringAsFixed(0)}% (${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB)";
        });
      }

      await output.flush();
      await output.close();

      setState(() {
        _isDownloading = false;
        _status = "ডাউনলোড সম্পন্ন! ✓";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text('সফলভাবে সেভ হয়েছে:\n${file.path}')),
      );
      Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
    } catch (err) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('ডাউনলোড এরর: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 420,
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(widget.video.thumbnails.highResUrl, width: 60, height: 45, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.video.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2)),
            ],
          ),
          const SizedBox(height: 12),

          if (_isDownloading) ...[
            Text(_status, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: _downloadProgress, color: Colors.purpleAccent, backgroundColor: Colors.grey[800]),
            const SizedBox(height: 12),
          ],

          TabBar(
            controller: _tabController,
            indicatorColor: Colors.purpleAccent,
            labelColor: Colors.purpleAccent,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.video_collection, size: 18), text: "VIDEO"),
              Tab(icon: Icon(Icons.music_note, size: 18), text: "AUDIO"),
            ],
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // VIDEO তালিকা (সব রেজোলিউশন)
                      ListView(
                        children: [
                          ..._manifest!.video.map((s) {
                            double mb = s.size.totalBytes / (1024 * 1024);
                            bool hasAudio = s is MuxedStreamInfo;
                            return ListTile(
                              leading: Icon(Icons.play_circle_fill, color: hasAudio ? Colors.cyanAccent : Colors.amberAccent, size: 22),
                              title: Text('MP4 ${s.qualityLabel} ${hasAudio ? "✓ Audio" : "(HD Video)"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text('${mb.toStringAsFixed(1)} MB', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                onPressed: _isDownloading ? null : () => _executeDownload(s, 'mp4'),
                                child: const Text('Download', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            );
                          }),
                        ],
                      ),

                      // AUDIO তালিকা (MP3 / M4A / WebM)
                      ListView(
                        children: [
                          ..._manifest!.audioOnly.map((s) {
                            double mb = s.size.totalBytes / (1024 * 1024);
                            String ext = s.container.name == 'mp4' ? 'm4a' : s.container.name;
                            return ListTile(
                              leading: const Icon(Icons.audiotrack, color: Colors.greenAccent, size: 22),
                              title: Text('Audio (${s.bitrate.kiloBitsPerSecond.round()} kbps)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text('${mb.toStringAsFixed(1)} MB • $ext', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                onPressed: _isDownloading ? null : () => _executeDownload(s, ext),
                                child: const Text('Download', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
