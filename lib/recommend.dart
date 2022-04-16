import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:collection';

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

  /// {'乐': 0.87}
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

  /// {'快乐(PA)': 0.66}, 排了序所有返回个 List<MapEntry>  Map.fromEntries(getTopFineEmotions()) 即可得到 Map 对象
  List<MapEntry<String, double>> getTopFineEmotions() {
    // zip -> filter(>0) -> sort
    var lst = [
      for (int i = 0; i < fineEmotions.length; i++)
        MapEntry(fineEmotions[i], seedEmotion[i])
    ].skipWhile((e) => e.value < 1e-2).toList()
      ..sort((e1, e2) => -e1.value.compareTo(e2.value));

    // top
    if (lst.length > 3) {
      lst = lst.sublist(0, 3);
    }

    if (kDebugMode) {
      print('top emotions: $lst');
    }

    // to map
    return lst;
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
        body: SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder(
                  future: data,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      var data = snapshot.data as RecommendResult;

                      return Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            child: Column(
                              children: [
                                EmotionCard(data: data),
                                const Divider(),
                                RecommendList(data: data),
                              ],
                            ),
                          ),
                          // 相似推荐：更多类似...的作品
                          // Material(
                          //   color: Colors.grey[100],
                          //   elevation: 8,
                          //   child: Center(
                          //     child: Text('jksdfkjkafhasd'),
                          //   ),
                          // )
                        ],
                      );
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      // waiting
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: const [
                            SizedBox(
                              child: CircularProgressIndicator(),
                              width: 50,
                              height: 50,
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text('正在为你推荐...'),
                            )
                          ],
                        ),
                      );
                    }
                  }),
              // DataPreviewWidget(widget: widget, data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class RecommendList extends StatelessWidget {
  final RecommendResult data;

  const RecommendList({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.tracks.length,
      itemBuilder: (context, index) {
        var track = data.tracks[index];
        return ListTile(
          // TODO: track cover
          leading: Image.network(
              "https://images.pexels.com/photos/396547/pexels-photo-396547.jpeg?auto=compress&cs=tinysrgb&h=350",
              width: 50,
              height: 50,
              fit: BoxFit.contain),
          title: Text(data.tracks[index].name),
          subtitle: Text(track.artists.join(" & ")),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text("暂不支持"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

class EmotionCard extends StatefulWidget {
  EmotionCard({Key? key, required this.data}) : super(key: key);

  final RecommendResult data;

  @override
  State<EmotionCard> createState() => _EmotionCardState();
}

class _EmotionCardState extends State<EmotionCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmotionPieChart(data: widget.data),
          const VerticalDivider(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emotion
                Text(
                  '你的心情:',
                  style: Theme.of(context).textTheme.subtitle1,
                ),
                Text(
                  widget.data
                      .getTopFineEmotions()
                      .map((e) => '${e.key}')
                      // '${e.key}: ${(e.value * 100).roundToDouble() / 100}'
                      .join("、"),
                  style: TextStyle(
                      fontSize: Theme.of(context).textTheme.subtitle2?.fontSize,
                      color: Colors.grey[600]),
                ),
                const Spacer(),
                // describe text
                const DescriptText(
                    text:
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque scelerisque efficitur posuere. Curabitur tincidunt placerat diam ac efficitur. Cras rutrum egestas nisl vitae pulvinar. Donec id mollis diam, id hendrerit neque. Donec accumsan efficitur libero, vitae feugiat odio fringilla ac. Aliquam a turpis bibendum, varius erat dictum, feugiat libero. Nam et dignissim nibh. Morbi elementum varius elit, at dignissim ex accumsan a'),
                const Spacer(),
                // Buttons
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ElevatedButton(
                      onPressed:
                          null, // onPressed: null => button is disabled (both logically & for UI)
                      child: Row(
                        children: const [Icon(Icons.play_arrow), Text(" 播放")],
                      ),
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.disabled)) {
                              return Colors.grey[300];
                            }
                            return Colors.grey[100];
                          },
                        ),
                        foregroundColor: MaterialStateProperty.all(
                            Theme.of(context).primaryColor),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share),
                      color: Theme.of(context).primaryColor,
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DescriptText extends StatelessWidget {
  final String text;

  const DescriptText({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 50),
      child: TextButton(
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () {
          if (kDebugMode) {
            print("expand describe text");
          }
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SingleChildScrollView(
                    child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Text(text),
                )),
              ),
            ),
            barrierDismissible: true,
          );
        },
      ),
    );
  }
}

class EmotionPieChart extends StatelessWidget {
  const EmotionPieChart({
    Key? key,
    required this.data,
  }) : super(key: key);

  final RecommendResult data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: 150,
      child: PieChart(
        PieChartData(
          sections: data.getEmotionPieDatas(),
          borderData: FlBorderData(
            show: false,
          ),
        ),
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
