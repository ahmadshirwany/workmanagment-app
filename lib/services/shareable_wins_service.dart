import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

enum ShareWinCardType {
  streakWin,
  levelUp,
  disciplineScore,
  weeklyReport,
}

extension ShareWinCardTypeX on ShareWinCardType {
  String get title {
    switch (this) {
      case ShareWinCardType.streakWin:
        return 'Streak Win';
      case ShareWinCardType.levelUp:
        return 'Level Up';
      case ShareWinCardType.disciplineScore:
        return 'Discipline Score';
      case ShareWinCardType.weeklyReport:
        return 'Weekly Report';
    }
  }

  String get fileTag {
    switch (this) {
      case ShareWinCardType.streakWin:
        return 'streak';
      case ShareWinCardType.levelUp:
        return 'level_up';
      case ShareWinCardType.disciplineScore:
        return 'score';
      case ShareWinCardType.weeklyReport:
        return 'weekly';
    }
  }

  IconData get icon {
    switch (this) {
      case ShareWinCardType.streakWin:
        return Icons.local_fire_department;
      case ShareWinCardType.levelUp:
        return Icons.rocket_launch;
      case ShareWinCardType.disciplineScore:
        return Icons.speed;
      case ShareWinCardType.weeklyReport:
        return Icons.bar_chart;
    }
  }
}

class ShareWinCardData {
  final int streakDays;
  final int level;
  final int xp;
  final double disciplineScore;
  final int weeklyCompletedTasks;
  final int weeklyTotalTasks;
  final double weeklyTaskCompletionRate;
  final double weeklyWorkHours;
  final int weeklyMaintenanceDays;

  const ShareWinCardData({
    required this.streakDays,
    required this.level,
    required this.xp,
    required this.disciplineScore,
    required this.weeklyCompletedTasks,
    required this.weeklyTotalTasks,
    required this.weeklyTaskCompletionRate,
    required this.weeklyWorkHours,
    required this.weeklyMaintenanceDays,
  });
}

class ShareableWinsService {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<String> generateWinCard({
    required ShareWinCardType type,
    required ShareWinCardData data,
  }) async {
    final bytes = await _screenshotController.captureFromWidget(
      _buildCard(type, data),
      pixelRatio: 3,
      delay: const Duration(milliseconds: 30),
    );

    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw Exception('Failed to encode share card image.');
    }

    img.drawRect(
      decodedImage,
      x1: 0,
      y1: 0,
      x2: decodedImage.width - 1,
      y2: decodedImage.height - 1,
      color: img.ColorRgb8(255, 255, 255),
      thickness: 8,
    );

    final outputBytes = Uint8List.fromList(img.encodePng(decodedImage));
    final saveDirectory = await _resolveSaveDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(
      '${saveDirectory.path}${Platform.pathSeparator}discipline_win_${type.fileTag}_$timestamp.png',
    );
    await file.writeAsBytes(outputBytes, flush: true);
    return file.path;
  }

  Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (await downloads.exists()) {
          return downloads;
        }
      }
    }

    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        return downloads;
      }
    }

    return getApplicationDocumentsDirectory();
  }

  Widget _buildCard(ShareWinCardType type, ShareWinCardData data) {
    final nowLabel = DateFormat('MMM d, yyyy').format(DateTime.now());
    final headline = _headlineFor(type, data);
    final subHeadline = _subHeadlineFor(type, data);
    final detailRows = _detailRowsFor(type, data);

    return MediaQuery(
      data: const MediaQueryData(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: const Color(0xFF0E1A2B),
          child: SizedBox(
            width: 1080,
            height: 1350,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradientFor(type),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 70,
                  right: -50,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -20,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(68, 70, 68, 62),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(type.icon, color: Colors.white, size: 40),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Text(
                              type.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 46,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 66),
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 92,
                          height: 0.95,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        subHeadline,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 34,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 50),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.26),
                          ),
                        ),
                        child: Column(
                          children: detailRows.map((row) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    row.$1,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    row.$2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discipline Tracker',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            nowLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _gradientFor(ShareWinCardType type) {
    switch (type) {
      case ShareWinCardType.streakWin:
        return const [Color(0xFFBF360C), Color(0xFFF57C00), Color(0xFFFFB300)];
      case ShareWinCardType.levelUp:
        return const [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF42A5F5)];
      case ShareWinCardType.disciplineScore:
        return const [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF26A69A)];
      case ShareWinCardType.weeklyReport:
        return const [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF283593)];
    }
  }

  String _headlineFor(ShareWinCardType type, ShareWinCardData data) {
    switch (type) {
      case ShareWinCardType.streakWin:
        return '${data.streakDays} Days';
      case ShareWinCardType.levelUp:
        return 'Level ${data.level}';
      case ShareWinCardType.disciplineScore:
        return '${data.disciplineScore.toStringAsFixed(1)}%';
      case ShareWinCardType.weeklyReport:
        return '${data.weeklyCompletedTasks}/${data.weeklyTotalTasks}';
    }
  }

  String _subHeadlineFor(ShareWinCardType type, ShareWinCardData data) {
    switch (type) {
      case ShareWinCardType.streakWin:
        return 'Consistency compounds. Keep the chain alive.';
      case ShareWinCardType.levelUp:
        return '${data.xp} total XP and climbing fast.';
      case ShareWinCardType.disciplineScore:
        return 'Discipline momentum built from daily execution.';
      case ShareWinCardType.weeklyReport:
        return 'Tasks closed this week.';
    }
  }

  List<(String, String)> _detailRowsFor(ShareWinCardType type, ShareWinCardData data) {
    switch (type) {
      case ShareWinCardType.streakWin:
        return [
          ('Current streak', '${data.streakDays} days'),
          ('Level', '${data.level}'),
          ('Discipline score', '${data.disciplineScore.toStringAsFixed(1)}%'),
        ];
      case ShareWinCardType.levelUp:
        return [
          ('Level', '${data.level}'),
          ('Total XP', '${data.xp}'),
          ('7-day maintenance', '${data.weeklyMaintenanceDays}/7 days'),
        ];
      case ShareWinCardType.disciplineScore:
        return [
          ('Discipline score', '${data.disciplineScore.toStringAsFixed(1)}%'),
          ('Current streak', '${data.streakDays} days'),
          ('Total XP', '${data.xp}'),
        ];
      case ShareWinCardType.weeklyReport:
        return [
          ('Task completion', '${(data.weeklyTaskCompletionRate * 100).toStringAsFixed(1)}%'),
          ('Focused work', '${data.weeklyWorkHours.toStringAsFixed(1)} h'),
          ('Maintenance days', '${data.weeklyMaintenanceDays}/7'),
        ];
    }
  }
}
