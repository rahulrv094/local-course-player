import 'dart:io';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class Section {
  String name;
  List<FileSystemEntity> files;
  Section(this.name, this.files);
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Section> sections = [];
  String? selectedDir;
  int? currentSection;
  int? currentIndex;
  BetterPlayerController? _betterPlayerController;
  bool subtitlesEnabled = true;

  @override
  void dispose() {
    _betterPlayerController?.dispose();
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
      // No subfolders: treat top-level files as one section
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
    _betterPlayerController?.dispose();
    _betterPlayerController = null;
  }

  void playFile(int sIdx, int fIdx) {
    final file = sections[sIdx].files[fIdx] as File;
    final filePath = file.path;
    // find srt with same base name
    final srtPath = File(p.setExtension(filePath, ".srt"));
    List<BetterPlayerSubtitlesSource> subtitles = [];
    if (subtitlesEnabled && srtPath.existsSync()) {
      subtitles.add(BetterPlayerSubtitlesSource(
        type: BetterPlayerSubtitlesSourceType.file,
        urls: [srtPath.path],
        name: "Subtitles",
      ));
    }

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      filePath,
      subtitles: subtitles,
      notificationConfiguration: BetterPlayerNotificationConfiguration(showNotification: false),
    );

    _disposePlayer();
    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableSubtitles: true,
        ),
        subtitlesConfiguration: BetterPlayerSubtitlesConfiguration(fontSize: 16),
      ),
      betterPlayerDataSource: dataSource,
    );

    setState(() {
      currentSection = sIdx;
      currentIndex = fIdx;
    });
  }

  void playNext() {
    if (currentSection == null || currentIndex == null) return;
    final files = sections[currentSection!].files;
    int next = currentIndex! + 1;
    if (next < files.length) {
      playFile(currentSection!, next);
    } else {
      // try next section
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

  @override
  Widget build(BuildContext context) {
    Widget playerArea = Container(
      color: Colors.black12,
      child: Center(child: Text('No video selected')),
      height: 220,
    );

    if (_betterPlayerController != null) {
      playerArea = AspectRatio(
        aspectRatio: 16 / 9,
        child: BetterPlayer(controller: _betterPlayerController!),
      );
    }

    return MaterialApp(
      title: 'Local Course Player',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Local Course Player (Option 2)'),
          actions: [
            IconButton(
              icon: Icon(Icons.folder_open),
              onPressed: pickDirectory,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Text('Subtitles'),
                  Switch(
                    value: subtitlesEnabled,
                    onChanged: (v) {
                      setState(() {
                        subtitlesEnabled = v;
                        // reload current file to apply subtitle toggle
                        if (currentSection != null && currentIndex != null) {
                          playFile(currentSection!, currentIndex!);
                        }
                      });
                    },
                  )
                ],
              ),
            )
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
                      });
                    },
                  );
                },
              ),
            ),
            VerticalDivider(width: 1),
            // Center: Player + Playlist
            Expanded(
              child: Column(
                children: [
                  // player area
                  Container(
                    color: Colors.black,
                    child: playerArea,
                  ),
                  // playlist for current section
                  Expanded(
                    child: currentSection == null
                        ? Center(child: Text('Select a course folder to see sections'))
                        : ListView.builder(
                            itemCount: sections[currentSection!].files.length,
                            itemBuilder: (context, idx) {
                              final f = sections[currentSection!].files[idx];
                              final name = p.basename(f.path);
                              return ListTile(
                                title: Text(name),
                                selected: currentIndex == idx,
                                onTap: () {
                                  // if non-video, open externally
                                  final ext = p.extension(f.path).toLowerCase();
                                  if (['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv'].contains(ext)) {
                                    playFile(currentSection!, idx);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening outside: $name'))); 
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
          child: Icon(Icons.skip_next),
          onPressed: playNext,
          tooltip: 'Play next lecture',
        ),
      ),
    );
  }
}
