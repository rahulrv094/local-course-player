// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

class Section {
  String name;
  List<FileSystemEntity> files;
  Section(this.name, this.files);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Section> sections = [];
  String? selectedDir;
  int? currentSection;
  int? currentIndex;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Future<void> pickDirectory() async {
    // Simple fallback: ask user to paste or type folder path.
    final controller = TextEditingController(text: selectedDir ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter course folder path'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '/sdcard/Download/course-folder'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final dir = Directory(result);
    if (!dir.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Directory not found')));
      return;
    }
    selectedDir = result;
    loadSections(result);
  }

  void loadSections(String folderPath) {
    final dir = Directory(folderPath);
    final subdirs = dir.listSync().whereType<Directory>().toList();
    List<Section> secs = [];
    if (subdirs.isNotEmpty) {
      for (var sd in subdirs) {
        final files = sd
            .listSync()
            .where((f) => f is File)
            .toList();
        if (files.isNotEmpty) {
          secs.add(Section(p.basename(sd.path), files));
        }
      }
    } else {
      final files = dir.listSync().where((f) => f is File).toList();
      if (files.isNotEmpty) {
        secs.add(Section("All Files", files));
      }
    }
    setState(() {
      sections = secs;
      currentSection = secs.isNotEmpty ? 0 : null;
      currentIndex = null;
      _disposePlayer();
    });
  }

  void _disposePlayer() {
    _chewieController?.pause();
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
  }

  Future<void> playFile(int sIdx, int fIdx) async {
    final file = sections[sIdx].files[fIdx] as File;
    final filePath = file.path;

    _disposePlayer();

    _videoController = VideoPlayerController.file(File(filePath));
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
    );

    setState(() {
      currentSection = sIdx;
      currentIndex = fIdx;
    });

    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration &&
          !_videoController!.value.isPlaying) {
        playNext();
      }
    });
  }

  void playNext() {
    if (currentSection == null || currentIndex == null) return;
    final files = sections[currentSection!].files;
    int next = currentIndex! + 1;
    if (next < files.length) {
      playFile(currentSection!, next);
    } else {
      int s = currentSection! + 1;
      while (s < sections.length) {
        final files2 = sections[s].files;
        if (files2.isNotEmpty) {
          playFile(s, 0);
          return;
        }
        s++;
      }
    }
  }

  Widget playerArea() {
    if (_chewieController != null && _videoController != null && _videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      );
    } else {
      return Container(
        color: Colors.black12,
        height: 220,
        child: const Center(child: Text('No video selected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Course Player',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Local Course Player'),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: pickDirectory,
            ),
          ],
        ),
        body: Row(
          children: [
            Container(
              width: 240,
              color: Colors.grey[100],
              child: ListView.builder(
                itemCount: sections.length,
                itemBuilder: (context, idx) {
                  final sec = sections[idx];
                  return ListTile(
                    title: Text(sec.name),
                    selected: currentSection == idx,
                    onTap: () {
                      setState(() {
                        currentSection = idx;
                        currentIndex = null;
                        _disposePlayer();
                      });
                    },
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: Colors.black,
                    child: playerArea(),
                  ),
                  Expanded(
                    child: currentSection == null
                        ? const Center(child: Text('Select a course folder to see sections'))
                        : ListView.builder(
                            itemCount: sections[currentSection!].files.length,
                            itemBuilder: (context, idx) {
                              final f = sections[currentSection!].files[idx];
                              final name = p.basename(f.path);
                              return ListTile(
                                title: Text(name),
                                selected: currentIndex == idx,
                                onTap: () {
                                  final ext = p.extension(f.path).toLowerCase();
                                  if (['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv'].contains(ext)) {
                                    playFile(currentSection!, idx);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Open outside: $name')));
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.skip_next),
          onPressed: playNext,
          tooltip: 'Play next lecture',
        ),
      ),
    );
  }
}
