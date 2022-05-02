import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// nextSongCount 是续曲推荐的曲目数
const nextSongCount = 10;

/// SimpleFile 是表示文件的类。包含文件名 [filename] 以及文件内容 [bytes]。
/// 用来给 [HomePage] 往 [RecommendPage] 传递要提交的图片文件。
class SimpleFile {
  String filename;
  Uint8List bytes;

  SimpleFile(this.filename, this.bytes);
}

/// Track 是响应结果中的曲目。
class Track {
  late String id;
  late String name;
  late List<String> artists;
  late String? albumCover;

  Track(this.id, this.name, this.artists, this.albumCover);

  Track.fromJson(Map<String, dynamic> m) {
    id = m['track_id'];
    name = m['track_name'];
    artists = m['artists'].cast<String>();
    albumCover = m['album_cover'];
  }

  @override
  String toString() {
    return 'Track($id: $name - $artists)';
  }
}

/// Emotion 是响应结果中的心情。
class Emotion {
  late List<double> values;

  Emotion(this.values);

  Emotion.empty() {
    values = [for (int i = 0; i < fineEmotions.length; i++) 0];
  }

  // region consts

  /// '情感大类': [起, 始] 下标（闭区间）
  final crudeEmotionsRanges = {
    '乐': [0, 1],
    '好': [2, 6],
    '怒': [7, 7],
    '哀': [8, 11],
    '惧': [12, 14],
    '恶': [15, 19],
    '惊': [20, 20]
  };

  final crudeEmotionsColors = {
    '乐': const Color(0xffFA9DFA),
    '好': const Color(0xffC978F5),
    '怒': const Color(0xffFA534D),
    '哀': const Color(0xff78AFF5),
    '惧': const Color(0xff6836F5),
    '恶': const Color(0xffF5E169), // F5E169
    '惊': const Color(0xff6CF55F)
  };

  final fineEmotions = [
    '快乐(PA)',
    '安心(PE)',
    '尊敬(PD)',
    '赞扬(PH)',
    '相信(PG)',
    '喜爱(PB)',
    '祝愿(PK)',
    '愤怒(NA)',
    '悲伤(NB)',
    '失望(NJ)',
    '疚(NH)',
    '思(PF)',
    '慌(NI)',
    '恐惧(NC)',
    '羞(NG)',
    '烦闷(NE)',
    '憎恶(ND)',
    '贬责(NN)',
    '妒忌(NK)',
    '怀疑(NL)',
    '惊奇(PC)'
  ];

  // endregion consts

  @override
  String toString() {
    return 'Emotion$values';
  }

  /// {'乐': 0.87}
  Map<String, double> getCrudeEmotionValues() {
    return crudeEmotionsRanges.map((key, indices) => MapEntry(
        key,
        values
            .sublist(indices[0], indices[1] + 1)
            .reduce((value, element) => value + element)));
  }

  List<PieSection> getEmotionPieSections() {
    return getCrudeEmotionValues()
        .entries
        .map(
          (e) => PieSection(
            title: e.key,
            value: e.value,
            color: crudeEmotionsColors[e.key],
          ),
        )
        .toList();
  }

  /// {'快乐(PA)': 0.66}, 排了序所有返回个 List<MapEntry>  Map.fromEntries(getTopFineEmotions()) 即可得到 Map 对象
  List<MapEntry<String, double>> getTopFineEmotions() {
    if (_topFineEmotionsCache != null) {
      return _topFineEmotionsCache!;
    }

    // zip -> filter(>0) -> sort
    var lst = [
      for (int i = 0; i < fineEmotions.length; i++)
        MapEntry(fineEmotions[i], values[i])
    ].skipWhile((e) => e.value < 1e-2).toList()
      ..sort((e1, e2) => -e1.value.compareTo(e2.value));

    // top
    if (lst.length > 3) {
      lst = lst.sublist(0, 3);
    }

    if (kDebugMode) {
      print('top emotions: $lst');
    }

    _topFineEmotionsCache = lst;
    return lst;
  }

  /// 用来存放 getTopFineEmotions 的结果缓存
  List<MapEntry<String, double>>? _topFineEmotionsCache;
}

/// RecommendResult 是请求 emotional_recommender.py server 返回的响应。
class RecommendResult {
  late Emotion seedEmotion;
  late List<double> distances;
  late List<Track> tracks;

  RecommendResult(this.seedEmotion, this.distances, this.tracks);

  RecommendResult.fromJson(Map<String, dynamic> m) {
    seedEmotion = Emotion(m['seed_emotion'].cast<double>());
    distances = m['distances'][0].cast<double>();
    // 如果心情为空，推荐的歌没有意义。
    tracks = [];
    if (seedEmotion.getTopFineEmotions().isNotEmpty) {
      tracks = m['recommended_tracks']
          .map((e) => Track.fromJson(e))
          .toList()
          .cast<Track>();
    }
  }

  RecommendResult.empty() {
    seedEmotion = Emotion.empty();
    distances = [];
    tracks = [];
  }

  @override
  String toString() {
    return 'RecommendResult(seedEmotion=$seedEmotion, distances=$distances, tracks=$tracks)';
  }
}

/// PieSection 用来表示饼图中的一个块。
class PieSection {
  String title;
  double value;
  Color? color;

  PieSection({required this.title, required this.value, this.color});
}

/// 构造 HighCharts 的饼图数据
String highChartJsData(List<PieSection> sections) {
  sections.sort((a, b) => a.value.compareTo(b.value));
  var series = sections.map((e) {
    var value = (e.value * 100).roundToDouble() / 100;
    var dataLabels =
        (value > 0.1) ? '{enabled: true, distance: -5}' : '{enabled: false}';

    return '''{
    name: '${e.title}', 
    y: $value, 
    z: $value, 
    dataLabels: $dataLabels
  }''';
  }).join(", ");

  return '''
    {
        chart: {
            type: 'variablepie'
        },
        title: {
            text: ''
        },
        tooltip: {
            headerFormat: '',
            pointFormat: '<span style="color:{point.color}">\u25CF</span> <b> {point.name}: {point.y}</b><br/>'
        },
        legend: {
          enabled: false
        },
        exporting: {
          enabled: false
        },
        credits: {
          enabled: false
        },
        series: [{
            minPointSize: 1,
            innerSize: '10%',
            zMin: 0,
            name: 'countries',
            data: [$series]
        }]
    }
    ''';
}
