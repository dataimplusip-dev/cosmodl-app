import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const CosmoDLApp());
}

// ----------------------------------------------------
// ডাউনলোড টাস্ক ও ম্যানেজার (১০০% কাজ করা অফিশিয়াল ইঞ্জিন)
// ----------------------------------------------------
class DownloadTask {
  final String id;
  final String title;
  final String quality;
  final String ext;
  final String thumbUrl;
  final int totalBytes;
  final StreamInfo streamInfo;
  final YoutubeExplode yt;

  int downloadedBytes = 0;
  double progress = 0.0;
  String status = "Downloading"; // Downloading, Paused, Completed, Failed
  String? filePath;

  bool isPaused = false;
  bool isCanceled = false;
  IOSink? _sink;

  DownloadTask({
    required this.id,
    required this.title,
    required this.quality,
    required this.ext,
    required this.thumbUrl,
    required this.totalBytes,
    required this.streamInfo,
    required this.yt,
  });

  void start(VoidCallback onUpdate) async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();

      // বাংলা নামের বিশেষ চিহ্ন ফিল্টার করা (যাতে ক্র্যাশ না করে)
      String cleanTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_').trim();
      if (cleanTitle.length > 25) cleanTitle = cleanTitle.substring(0, 25);

      filePath = '${dir.path}/${cleanTitle}_$id.$ext';
      final file = File(filePath!);
      _sink = file.openWrite(mode: FileMode.writeOnlyAppend);

      final stream = yt.videos.streamsClient.get(streamInfo);

      int lastUpdate = 0;
      await for (final chunk in stream) {
        if (isCanceled) break;

        while (isPaused) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (isCanceled) break;
        }

        _sink?.add(chunk);
        downloadedBytes += chunk.length;
        progress = totalBytes > 0 ? (downloadedBytes / totalBytes) : 0.0;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdate > 300) {
          lastUpdate = now;
          onUpdate();
        }
      }

      await _sink?.flush();
      await _sink?.close();

      if (!isCanceled) {
        status = "Completed";
        progress = 1.0;
        onUpdate();
      }
    } catch (e) {
      status = "Failed";
      onUpdate();
    }
  }

  void pause(VoidCallback onUpdate) {
    isPaused = true;
    status = "Paused";
    onUpdate();
  }

  void resume(VoidCallback onUpdate) {
    isPaused = false;
    status = "Downloading";
    onUpdate();
  }

  void cancelAndDelete(VoidCallback onUpdate) async {
    isCanceled = true;
    isPaused = false;
    status = "Deleted";
    try {
      await _sink?.close();
      if (filePath != null) {
        final f = File(filePath!);
        if (f.existsSync()) f.deleteSync();
      }
    } catch (_) {}
    onUpdate();
  }
}

class DownloadManager {
  static final ValueNotifier<List<DownloadTask>> tasks = ValueNotifier<List<DownloadTask>>([]);
  static final ValueNotifier<int> unreadBadge = ValueNotifier<int>(0);

  static void addTask(DownloadTask task) {
    tasks.value = [task, ...tasks.value];
    unreadBadge.value = unreadBadge.value + 1; // ১, ২, ৩ লাইভ ব্যাজ
    tasks.notifyListeners();
    task.start(() => tasks.notifyListeners());
  }

  static void removeTask(String id) {
    final list = tasks.value;
    final task = list.firstWhere((t) => t.id == id, orElse: () => list.first);
    task.cancelAndDelete(() {
      tasks.value = list.where((t) => t.id != id).toList();
      tasks.notifyListeners();
    });
  }

  static void markAsRead() {
    unreadBadge.value = 0; // Downloads ট্যাবে চাপ দিলে ব্যাজ ০ হবে
  }
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
        final match = RegExp(r'(https?://[^\s]+)').firstMatch(sharedText);
        if (match != null) {
          setState(() => _currentIndex = 1);
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
        onTap: (index) {
          if (index == 2) {
            DownloadManager.markAsRead();
          }
          setState(() => _currentIndex = index);
        },
        backgroundColor: const Color(0xFF070D1E),
        selectedItemColor: const Color(0xFF8B5CF6),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Explore"),
          const BottomNavigationBarItem(icon: Icon(Icons.link), label: "Paste Link"),
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: DownloadManager.unreadBadge,
              builder: (context, count, child) {
                return Badge(
                  label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.purpleAccent,
                  child: const Icon(Icons.download_done_rounded),
                );
              },
            ),
            label: "Downloads",
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 1: VidMate স্টাইল ইউটিউব এক্সপ্লোর ও সার্চ
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
    _loadVideos('trending bangla song');
  }

  Future<void> _loadVideos(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.yt.search.search(query);
      setState(() {
        _videos = results.take(20).toList();
        _isLoading = false;
      });
    } catch (_) {
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

  void _playVideoInApp(Video video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoPlayerScreen(video: video, yt: widget.yt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosmoDL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14.0),
            child: Center(child: Text('Creator by Naim Islam', style: TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _searchController,
                onSubmitted: (val) => val.trim().isNotEmpty ? _loadVideos(val.trim()) : null,
                decoration: InputDecoration(
                  hintText: 'Search YouTube videos, songs...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.cyanAccent),
                    onPressed: () => _searchController.text.trim().isNotEmpty ? _loadVideos(_searchController.text.trim()) : null,
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
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _playVideoInApp(v),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: Image.network(v.thumbnails.highResUrl, height: 185, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                    child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
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
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _playVideoInApp(v),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(v.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(v.author, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _openDownloadModal(v),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
// ভিডিও প্লেয়ার স্ক্রিন (Play, Pause, টেনে দেওয়ার স্লাইডার সহ)
// ----------------------------------------------------
class VideoPlayerScreen extends StatefulWidget {
  final Video video;
  final YoutubeExplode yt;
  const VideoPlayerScreen({super.key, required this.video, required this.yt});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _setupPlayer();
  }

  Future<void> _setupPlayer() async {
    try {
      final manifest = await widget.yt.videos.streamsClient.getManifest(widget.video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();
      _controller = VideoPlayerController.networkUrl(streamInfo.url)
        ..initialize().then((_) {
          setState(() => _isInit = true);
          _controller?.play();
          _startHideTimer();
        });
      _controller?.addListener(() => setState(() {}));
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing', style: TextStyle(fontSize: 16)), backgroundColor: Colors.transparent),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _isInit && _controller != null
                ? GestureDetector(
                    onTap: () {
                      setState(() => _showControls = !_showControls);
                      if (_showControls) _startHideTimer();
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller!),

                        if (_showControls) ...[
                          Container(color: Colors.black.withOpacity(0.4)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10_rounded, size: 36, color: Colors.white),
                                onPressed: () {
                                  final cur = _controller!.value.position;
                                  _controller!.seekTo(cur - const Duration(seconds: 10));
                                  _startHideTimer();
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: Icon(
                                  _controller!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                  size: 60,
                                  color: Colors.purpleAccent,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                                  });
                                  _startHideTimer();
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: const Icon(Icons.forward_10_rounded, size: 36, color: Colors.white),
                                onPressed: () {
                                  final cur = _controller!.value.position;
                                  _controller!.seekTo(cur + const Duration(seconds: 10));
                                  _startHideTimer();
                                },
                              ),
                            ],
                          ),

                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Row(
                                children: [
                                  Text(_formatDuration(_controller!.value.position), style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  Expanded(
                                    child: Slider(
                                      value: _controller!.value.position.inMilliseconds.toDouble().clamp(0.0, _controller!.value.duration.inMilliseconds.toDouble()),
                                      min: 0.0,
                                      max: _controller!.value.duration.inMilliseconds.toDouble(),
                                      activeColor: Colors.purpleAccent,
                                      inactiveColor: Colors.grey,
                                      onChanged: (val) {
                                        _controller!.seekTo(Duration(milliseconds: val.toInt()));
                                        _startHideTimer();
                                      },
                                    ),
                                  ),
                                  Text(_formatDuration(_controller!.value.duration), style: const TextStyle(fontSize: 10, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.video.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(widget.video.author, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Download Video / Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF0D1836),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => DownloadBottomSheet(video: widget.video, yt: widget.yt),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 2: লিংক পেস্ট ট্যাব
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
// TAB 3: Downloads ম্যানেজার
// ----------------------------------------------------
class DownloadsManagerTab extends StatelessWidget {
  const DownloadsManagerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads'), centerTitle: true, backgroundColor: Colors.transparent),
      body: ValueListenableBuilder<List<DownloadTask>>(
        valueListenable: DownloadManager.tasks,
        builder: (context, tasks, child) {
          if (tasks.isEmpty) {
            return const Center(child: Text('কোনো ডাউনলোড টাস্ক নেই!', style: TextStyle(color: Colors.grey, fontSize: 13)));
          }
          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isDone = task.status == "Completed";
              final isPaused = task.status == "Paused";
              final isFailed = task.status == "Failed";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDone ? Colors.green.withOpacity(0.3) : isPaused ? Colors.amber.withOpacity(0.3) : Colors.purple.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(task.thumbUrl, width: 60, height: 45, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.video_file, size: 40)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('${task.quality} • ${task.ext.toUpperCase()} • ${task.status}',
                                  style: TextStyle(fontSize: 10, color: isDone ? Colors.greenAccent : isPaused ? Colors.amberAccent : Colors.cyanAccent)),
                            ],
                          ),
                        ),
                        if (!isDone && !isFailed) ...[
                          IconButton(
                            icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.cyanAccent),
                            onPressed: () {
                              if (isPaused) {
                                task.resume(() => DownloadManager.tasks.notifyListeners());
                              } else {
                                task.pause(() => DownloadManager.tasks.notifyListeners());
                              }
                            },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                          onPressed: () => DownloadManager.removeTask(task.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!isDone && !isFailed) ...[
                      LinearProgressIndicator(
                        value: task.progress,
                        color: isPaused ? Colors.amberAccent : Colors.purpleAccent,
                        backgroundColor: Colors.grey[800],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(task.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(task.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text('${(task.progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaused ? Colors.amberAccent : Colors.purpleAccent)),
                        ],
                      ),
                    ],
                    if (isDone)
                      const Text('✓ ডাউনলোড সম্পন্ন!', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------
// কোয়ালিটি মডাল (১০০% ডাউনলোড হওয়া ফরম্যাট তালিকা)
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

  void _startDownload(StreamInfo streamInfo, String qualityName, String ext) {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: taskId,
      title: widget.video.title,
      quality: qualityName,
      ext: ext,
      thumbUrl: widget.video.thumbnails.highResUrl,
      totalBytes: streamInfo.size.totalBytes,
      streamInfo: streamInfo,
      yt: widget.yt,
    );

    DownloadManager.addTask(task);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF8B5CF6),
        content: Text('ডাউনলোড শুরু হয়েছে! Downloads ট্যাবে প্রগ্রেস দেখুন।'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
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
                      // VIDEO তালিকা (সাউন্ড সহ ১০০% ডাউনলোড হওয়া ফরম্যাট)
                      Builder(builder: (context) {
                        final muxedStreams = _manifest!.muxed.toList();
                        muxedStreams.sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));

                        if (muxedStreams.isEmpty) {
                          return const Center(child: Text('এই ভিডিওর সাউন্ড সহ ফরম্যাট পাওয়া যায়নি!', style: TextStyle(fontSize: 12, color: Colors.grey)));
                        }

                        return ListView.builder(
                          itemCount: muxedStreams.length,
                          itemBuilder: (context, i) {
                            final s = muxedStreams[i];
                            double mb = s.size.totalBytes / (1024 * 1024);
                            String qLabel = "MP4 (${s.qualityLabel}) • সাউন্ড সহ";

                            return ListTile(
                              leading: const Icon(Icons.play_circle_fill, color: Colors.cyanAccent, size: 22),
                              title: Text(qLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text('${mb.toStringAsFixed(1)} MB • ফুল স্পিড', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                onPressed: () => _startDownload(s, s.qualityLabel, 'mp4'),
                                child: const Text('Download', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            );
                          },
                        );
                      }),

                      // AUDIO তালিকা (সরাসরি ১০০% ডাউনলোড হওয়া M4A অডিও)
                      Builder(builder: (context) {
                        final audioStreams = _manifest!.audioOnly.toList();
                        audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));

                        return ListView.builder(
                          itemCount: audioStreams.length > 2 ? 2 : audioStreams.length,
                          itemBuilder: (context, i) {
                            final s = audioStreams[i];
                            double mb = s.size.totalBytes / (1024 * 1024);
                            bool isM4A = s.container.name.toLowerCase() == 'mp4';
                            String label = isM4A ? "High Quality Audio (M4A)" : "WebM Audio (HQ)";
                            String ext = isM4A ? "m4a" : "opus";

                            return ListTile(
                              leading: const Icon(Icons.audiotrack, color: Colors.greenAccent, size: 22),
                              title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text('${mb.toStringAsFixed(1)} MB • ${s.bitrate.kiloBitsPerSecond.round()} kbps', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                onPressed: () => _startDownload(s, label, ext),
                                child: const Text('Download', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
