// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

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
    // Request storage permission for older Android versions (may be needed)
    await Permission.storage.request();
    String? dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    selectedDir = dir;
    loadSections(dir);
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
      // Additional customization can go here
    );

    setState(() {
      currentSection = sIdx;
      currentIndex = fIdx;
    });

    // when video ends, autoplay next
    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration &&
          !_videoController!.value.isPlaying) {
        // video ended
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
            // Left: Sections list
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
            // Center: Player + Playlist
            Expanded(
              child: Column(
                children: [
                  // player area
                  Container(
                    color: Colors.black,
                    child: playerArea(),
                  ),
                  // playlist for current section
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
