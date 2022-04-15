import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_scatter/flutter_scatter.dart';

const emotextServer = '192.168.43.214:8081';

Uri emotextUri(String text) {
  return Uri.http(emotextServer, '/text', {'text': text});
}

Uri emopicUri() {
  return Uri.http(emotextServer, '/pic');
}

class SimpleFile {
  String filename;
  Uint8List bytes;

  SimpleFile(this.filename, this.bytes);
}

class Track {
  late String id;
  late String name;
  late List<String> artists;

  Track(this.id, this.name, this.artists);

  Track.fromJson(Map<String, dynamic> m) {
    id = m['track_id'];
    name = m['track_name'];
    artists = m['artists'].cast<String>();
  }

  @override
  String toString() {
    return 'Track($id: $name - $artists)';
  }
}

class RecommendResult {
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

  late List<double> seedEmotion;
  late List<double> distances;
  late List<Track> tracks;

  RecommendResult(this.seedEmotion, this.distances, this.tracks);

  RecommendResult.fromJson(Map<String, dynamic> m) {
    seedEmotion = m['seed_emotion'].cast<double>();
    distances = m['distances'][0].cast<double>();
    tracks = m['recommended_tracks']
        .map((e) => Track.fromJson(e))
        .toList()
        .cast<Track>();
  }

  @override
  String toString() {
    return 'RecommendResult(seedEmotion=$seedEmotion, distances=$distances, tracks=$tracks)';
  }

  Map<String, double> getCrudeEmotionValues() {
    return crudeEmotionsRanges.map((key, indices) => MapEntry(
        key,
        seedEmotion
            .sublist(indices[0], indices[1] + 1)
            .reduce((value, element) => value + element)));
  }

  List<PieChartSectionData> getEmotionPieDatas() {
    return getCrudeEmotionValues()
        .entries
        .map(
          (e) => PieChartSectionData(
            title: e.key,
            value: e.value,
            color: crudeEmotionsColors[e.key],
            titleStyle: const TextStyle(color: Colors.white),
          ),
        )
        .toList();
  }
}

class RecommendPage extends StatefulWidget {
  RecommendPage({
    Key? key,
    // required this.seedType,
    this.text,
    this.pic, // TODO: 等后端改好再写 emopic
  }) : super(key: key);

  // final RecommendSeedType seedType;
  final String? text;
  final SimpleFile? pic;

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  late Future<RecommendResult> data;

  RecommendResult parseRecommendResponse(http.Response response) {
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      var result = RecommendResult.fromJson(json);

      if (kDebugMode) {
        print(result);
      }

      return result;
    } else {
      throw Exception(response.body.toString());
    }
  }

  Future<RecommendResult> requestEmopicRecommend() async {
    var request = http.MultipartRequest('POST', emopicUri());
    request.files.add(
      http.MultipartFile.fromBytes('img', widget.pic!.bytes,
          filename: widget.pic!.filename),
    );
    final streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    return parseRecommendResponse(response);
  }

  Future<RecommendResult> requestEmotextRecommend() async {
    final uri = emotextUri(widget.text ?? '');
    if (kDebugMode) {
      print('request ${uri.toString()}');
    }

    final response = await http.get(uri);

    return parseRecommendResponse(response);
  }

  @override
  void initState() {
    super.initState();

    if (widget.text != null) {
      data = requestEmotextRecommend();
    } else if (widget.pic != null) {
      data = requestEmopicRecommend();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('recommend'),
      // ),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            RecommendAppBar(
              context: context,
              innerBoxIsScrolled: innerBoxIsScrolled,
              title: "推荐音乐",
              text: widget.text,
              pic: widget.pic,
            ),
          ];
        },
        body: SafeArea(
          top: false,
          bottom: false,
          child: Builder(
            builder: (BuildContext context) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    FutureBuilder(
                        future: data,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return RecommendList(
                              data: snapshot.data as RecommendResult,
                            );
                          } else if (snapshot.hasError) {
                            return const Text('Error');
                          } else {
                            return Column(
                              children: const [
                                SizedBox(
                                  child: CircularProgressIndicator(),
                                  width: 60,
                                  height: 60,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text('等待请求完成'),
                                )
                              ],
                            );
                          }
                        }),
                    DataPreviewWidget(widget: widget, data: data),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class RecommendAppBar extends StatelessWidget {
  final BuildContext? context;
  final bool? innerBoxIsScrolled;
  final String? title;

  final String? text;
  final SimpleFile? pic;

  const RecommendAppBar({
    Key? key,
    this.context,
    this.innerBoxIsScrolled,
    this.title,
    this.text,
    this.pic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      stretch: true,
      forceElevated: innerBoxIsScrolled ?? true,
      iconTheme: IconThemeData(color: Theme.of(context).bottomAppBarColor),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        centerTitle: true,
        title: Text(
          title ?? 'Recommend',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        background: Builder(
          builder: (context) {
            if (pic != null) {
              return Image.memory(
                pic!.bytes,
                fit: BoxFit.cover,
              );
            }
            if (text != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      text!,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: Theme.of(context).cardColor,
                        fontFamily: "serif",
                        fontSize: 30.0,
                      ),
                    ),
                  ),
                ),
              );
            }
            // Impossible
            return Image.network(
              "https://images.pexels.com/photos/396547/pexels-photo-396547.jpeg?auto=compress&cs=tinysrgb&h=350",
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }
}

class RecommendList extends StatefulWidget {
  RecommendList({Key? key, required this.data}) : super(key: key);

  final RecommendResult data;

  @override
  State<RecommendList> createState() => _RecommendListState();
}

class _RecommendListState extends State<RecommendList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(
                  PieChartData(
                    sections: widget.data.getEmotionPieDatas(),
                    borderData: FlBorderData(
                      show: false,
                    ),
                  ),
                ),
              ),
              const Divider(),
            ],
          ),
          const Divider(),
          SizedBox(
            height: 300,
            child: Container(
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

/// for debug
class DataPreviewWidget extends StatelessWidget {
  const DataPreviewWidget({
    Key? key,
    required this.widget,
    required this.data,
  }) : super(key: key);

  final RecommendPage widget;
  final Future<RecommendResult> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      color: Colors.grey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Debug",
            style: TextStyle(fontSize: 28),
          ),
          widget.text != null ? Text(widget.text!) : const Text("no text"),
          widget.pic != null
              ? Image.memory(widget.pic!.bytes)
              : const Text("no img"),
          FutureBuilder(
            future: data,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              List<Widget> children;

              if (snapshot.hasData) {
                children = [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'resp: ${snapshot.data}',
                    ),
                  )
                ];
              } else if (snapshot.hasError) {
                children = [Text('Error: ${snapshot.error}')];
              } else {
                children = [
                  const SizedBox(
                    child: CircularProgressIndicator(),
                    width: 60,
                    height: 60,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('等待请求完成'),
                  )
                ];
              }

              return Column(children: children);
            },
          )
        ],
      ),
    );
  }
}
