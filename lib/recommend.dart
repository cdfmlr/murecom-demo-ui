import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:high_chart/high_chart.dart';
import 'package:http/http.dart' as http;

/// 提供 emotext 服务的 emotional_recommender.py 服务器
const emotextServer = '192.168.43.214:8081';

/// 提供 emotext 服务的 emotional_recommender.py 服务器
const emopicServer = '192.168.43.214:8081';

/// emotextUri 构造 emotext 请求的 URL。传入 [text] 参数构造 GET 请求的 query.
Uri emotextUri(String text) {
  return Uri.http(emotextServer, '/text', {'text': text});
}

/// emopicUri 获取 emopic 服务的 URL。
/// 因为要上传图片，所以这个用 POST 请求传数据，所以这里不构造 query 了。
Uri emopicUri() {
  return Uri.http(emopicServer, '/pic');
}

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

/// RecommendResult 是请求 emotional_recommender.py server 返回的响应。
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

  RecommendResult.empty() {
    seedEmotion = [for (int i = 0; i < fineEmotions.length; i++) 0];
  }

  List<MapEntry<String, double>>? _topFineEmotionsCache;

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

    _topFineEmotionsCache = lst;
    return lst;
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

class BadRequestException implements Exception {
  final String? message;

  BadRequestException([this.message]);

  bool isNotImage() => _messageContains('not a image');

  bool isNoBody() => _messageContains('no human body');

  bool isNoEmo() => _messageContains('no emotion');

  bool isMissingQuery() => _messageContains('required query');

  bool isMissingPostImg() => _messageContains('post data img');

  bool isEmptySeed() => _messageContains('empty seed');

  bool _messageContains(String s) {
    return message?.toLowerCase().contains(s) ?? false;
  }

  @override
  String toString() {
    return 'Bad Request: $message';
  }
}

/// RecommendPage 拿到 [HomePage] 传来的 seed [text] 或 [pic]，
/// 请求 emotional_recommender.py 服务，获取心情音乐推荐。
/// 输入的 seed 文本或图片会作为该页面的 AppBar 的背景（[RecommendAppBar]）。
/// 推荐的结果会在页面中显示出来（[EmotionalRecommendResultView]）。
class RecommendPage extends StatefulWidget {
  const RecommendPage({
    Key? key,
    // required this.seedType,
    this.text,
    this.pic,
  }) : super(key: key);

  /// 输入的文本推荐种子
  final String? text;

  /// 输入的图片推荐种子
  final SimpleFile? pic;

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  /// data 是心情音乐推荐的结果：在 [initState] 时，由 [requestEmotextRecommend] 或
  /// [requestEmopicRecommend] 赋值。
  ///
  /// 后面 View 要在 FutureBuilder 中从该变量获取值。
  late Future<RecommendResult> data;

  /// parseRecommendResponse 解析 emotional_recommender.py 服务返回的
  /// 响应，即获取 emotext/emopic 的推荐结果
  RecommendResult parseRecommendResponse(http.Response response) {
    if (response.statusCode == 200) {
      var json = jsonDecode(response.body);
      var result = RecommendResult.fromJson(json);

      if (kDebugMode) {
        print(result);
      }

      return result;
    } else {
      if (kDebugMode) {
        print(
            'recommender server error response: [${response.statusCode}] ${response.reasonPhrase} \n\t ${response.body}');
      }
      if (response.statusCode == 400) {
        var e = BadRequestException(response.body);
        if (e.isNoEmo()) {
          return RecommendResult.empty();
        }
        throw e;
      }
      throw Exception(response.body);
    }
  }

  /// requestEmopicRecommend 请求 emopic 服务，获取从图像的心情音乐推荐结果。
  ///
  /// ```
  ///   POST http://emopic.server/pic
  ///      FILE: img={filename=pic.filename, file=pic.file}
  /// ```
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

  /// requestEmotextRecommend 请求 emotext 服务，获取从文本的心情音乐推荐结果。
  ///
  /// ```
  ///   GET http://emotext.server/text?text={text}
  /// ```
  Future<RecommendResult> requestEmotextRecommend() async {
    final uri = emotextUri(widget.text ?? '');
    if (kDebugMode) {
      print('request ${uri.toString()}');
    }

    final response = await http.get(uri);

    return parseRecommendResponse(response);
  }

  /// 在初始化时调用就 requestEmo*Recommend 请求推荐
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
      // NestedScrollView
      //   |- SliverAppBar
      //   |    |- FlexibleSpaceBar
      //   |- SingleChildScrollView
      // 这一套东西组合起来实现可以收展的标题栏（Android 里面的 CollapsingToolbarLayout）
      // 遗憾: 没能实现 App Store 顶部图片那种下拉回弹的效果。
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
          child: FutureBuilder(
              future: data,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  var data = snapshot.data as RecommendResult;
                  return EmotionalRecommendResultView(data: data);
                }
                if (snapshot.hasError) {
                  return RecommendErrorView(
                    error: snapshot.error,
                    isPic: (widget.pic != null),
                  );
                }
                // waiting
                return const ProgressIndicator(text: Text('正在为你推荐...'));
              }),
        ),
      ),
    );
  }
}

/// RecommendAppBar 是 [RecommendPage] 的顶部标题栏。
///
/// - 如果是用 emotext 从文本推荐，则显示文本的前两行作为背景；
/// - 如果是用 emopic  从图片推荐，则以输入图片作为背景；
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
              /// 输入的图片作为背景
              return Image.memory(
                pic!.bytes,
                fit: BoxFit.cover,
              );
            }
            if (text != null) {
              /// 输入的文字作为背景
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

/// ProgressIndicator 就是个简单的等待的无限转圈进度条。
/// [text] 是显示在圈下面的文本。
class ProgressIndicator extends StatelessWidget {
  final Widget text;

  const ProgressIndicator({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // const text = Text('正在为你推荐...');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(
            child: CircularProgressIndicator(),
            width: 50,
            height: 50,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: text,
          )
        ],
      ),
    );
  }
}

/// EmotionalRecommendResultView 是心情音乐推荐的全部结果，
/// 包含一个 [EmotionView] 和一个 [RecommendList]。
class EmotionalRecommendResultView extends StatelessWidget {
  const EmotionalRecommendResultView({
    Key? key,
    required this.data,
  }) : super(key: key);

  final RecommendResult data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            children: [
              EmotionView(data: data),
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
  }
}

/// EmotionView 显示分析得到的心情结果
class EmotionView extends StatelessWidget {
  final RecommendResult data;

  const EmotionView({Key? key, required this.data}) : super(key: key);

  static const lipsum =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque scelerisque efficitur posuere. Curabitur tincidunt placerat diam ac efficitur. Cras rutrum egestas nisl vitae pulvinar. Donec id mollis diam, id hendrerit neque. Donec accumsan efficitur libero, vitae feugiat odio fringilla ac. Aliquam a turpis bibendum, varius erat dictum, feugiat libero. Nam et dignissim nibh. Morbi elementum varius elit, at dignissim ex accumsan a';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmotionPieChart(data: data),
          const VerticalDivider(),
          Expanded(
            child: buildEmotionDescription(context),
          ),
        ],
      ),
    );
  }

  /// buildEmotionDescription 构建出 [EmotionPieChart] 旁边的文字信息。
  /// 包含：
  /// - 前三个细类心情，
  /// - todo 的推荐语
  /// - 以及画饼的播放按钮。
  ///
  /// 如果 getTopFineEmotions 得到空列表，即没有分析出心情，则显示"抱歉"，
  /// 其他的按钮什么的全都不再显示。
  Widget buildEmotionDescription(BuildContext context) {
    var emotions = data.getTopFineEmotions();

    var subtitle = '抱歉！';
    var value = '未能分析出您的心情';

    if (emotions.isNotEmpty) {
      subtitle = '你的心情';
      value = emotions
          .map((e) => e.key)
          // '${e.key}: ${(e.value * 100).roundToDouble() / 100}'
          .join("、");
    }

    // 文本：您的心情 \n 快乐、悲伤、惊讶
    List<Widget> texts = [
      Text(
        subtitle,
        style: Theme.of(context).textTheme.subtitle1,
      ),
      Text(
        value,
        style: TextStyle(
            fontSize: Theme.of(context).textTheme.subtitle2?.fontSize,
            color: Colors.grey[600]),
      ),
    ];

    // 长文本描述以及按钮
    // 如果没有推荐结果，就全部没有了
    List<Widget> descriptionAndButtons = [];
    if (emotions.isNotEmpty) {
      descriptionAndButtons = [
        const Spacer(),
        // describe text
        const PopupText(text: lipsum),
        const Spacer(),
        // Buttons
        buildButtons(context),
      ];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...texts,
        ...descriptionAndButtons,
      ],
    );
  }

  Widget buildButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        ElevatedButton(
          onPressed: null,
          // onPressed: null => button is disabled (both logically & for UI)
          child: Row(
            children: const [Icon(Icons.play_arrow), Text(" 播放")],
          ),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color?>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.disabled)) {
                  return Colors.grey[300];
                }
                return Colors.grey[100];
              },
            ),
            foregroundColor:
                MaterialStateProperty.all(Theme.of(context).primaryColor),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.share),
          color: Theme.of(context).primaryColor,
        )
      ],
    );
  }
}

/// PopupText 默认展示有限部分，但可以点击弹出全部的文本。
/// Apple Music 的唱片介绍"更多"那种。
class PopupText extends StatelessWidget {
  final String text;

  const PopupText({
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

/// EmotionPieChart 是生动展现心情大类的饼图
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
      child: Builder(builder: (context) {
        if (kIsWeb) {
          return HighCharts(
            loader: const SizedBox(
              child: LinearProgressIndicator(),
              width: 80,
            ),
            size: const Size(150, 150),
            data: highChartJsData(data.getEmotionPieSections()),
            scripts: const [
              "https://code.highcharts.com/highcharts.js",
              'https://code.highcharts.com/modules/networkgraph.js',
              'https://code.highcharts.com/modules/exporting.js',
            ],
          );
        } else {
          return PieChart(
            PieChartData(
              sections: data
                  .getEmotionPieSections()
                  .map((e) => PieChartSectionData(
                        title: e.title,
                        value: e.value,
                        color: e.color,
                        titleStyle: const TextStyle(color: Colors.white),
                      ))
                  .toList(),
              borderData: FlBorderData(
                show: false,
              ),
            ),
          );
        }
        // impossible
        return Container(color: Colors.amber);
      }),
    );
  }
}

/// RecommendList 是推荐的歌曲列表
class RecommendList extends StatelessWidget {
  final RecommendResult data;

  const RecommendList({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.getTopFineEmotions().isEmpty) {
      return const Center(
        child: Text("没有推荐的音乐。"),
      );
    }

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

/// RecommendErrorView 是出错、无法显示推荐结果的 [EmotionalRecommendResultView] 时，
/// 作为替代的错误视图。
class RecommendErrorView extends StatelessWidget {
  final Object? error;
  final bool? isPic;

  static const _tips = {
    'network': '请检查网络连接，或稍等片刻重试。',
    'nobody': '请确保图片包含人像，并保持网络连接通畅。',
    'unknown': '请检查网络连接并稍后重试，若错误仍然出现请联系开发者。',
  };

  const RecommendErrorView({
    Key? key,
    this.error,
    this.isPic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var tip = _tips['unknown'];
    if (error.runtimeType == BadRequestException) {
      var e = error as BadRequestException;
      if (e.isNoBody()) {
        tip = _tips['nobody'];
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            Text('出错啦', style: Theme.of(context).textTheme.subtitle1),
            Text('$error', style: Theme.of(context).textTheme.caption),
            Text(tip ?? 'Unexpected error!')
          ],
        ),
      ),
    );
  }
}

/// DEBUG: DataPreviewWidget shows the raw input seed and response result
/// in RecommendPage for debug.
///
/// Notice: data here is Future<RecommendResult>,
/// so put this widget out of a FutureBuilder.
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
