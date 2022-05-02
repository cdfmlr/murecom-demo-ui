import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:high_chart/high_chart.dart';
import 'package:http/http.dart' as http;
import 'package:murecom/next_song.dart';
import 'package:murecom/requests.dart';

import 'model.dart';
import 'widgets/popup_text.dart';
import 'widgets/album_cover.dart';
import 'widgets/progress_indicator.dart';

/// RecommendPage 拿到 [HomePage] 传来的 seed [text] 或 [pic]，
/// 请求 emotional_recommender.py 服务，获取心情音乐推荐。
/// 输入的 seed 文本或图片会作为该页面的 AppBar 的背景（[RecommendAppBar]）。
/// 推荐的结果会在页面中显示出来（[EmotionalRecommendResultView]）。
class RecommendPage extends StatefulWidget {
  const RecommendPage({
    Key? key,
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

  /// requestEmopicRecommend 请求 emopic 服务，获取从图像的心情音乐推荐结果。
  Future<RecommendResult> requestEmopicRecommend() async {
    return queryEmopicRecommend(widget.pic!);
  }

  /// requestEmotextRecommend 请求 emotext 服务，获取从文本的心情音乐推荐结果。
  Future<RecommendResult> requestEmotextRecommend() async {
    return queryEmotextRecommend(widget.text ?? '');
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
                return const TextProgressIndicator(text: Text('正在为你推荐...'));
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
              EmotionView(emotion: data.seedEmotion, tracks: data.tracks),
              const Divider(),
              RecommendList(tracks: data.tracks),
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
  final Emotion emotion;
  final List<Track>? tracks; // for 推荐语

  const EmotionView({Key? key, required this.emotion, this.tracks})
      : super(key: key);

  static const lipsum =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque scelerisque efficitur posuere. Curabitur tincidunt placerat diam ac efficitur. Cras rutrum egestas nisl vitae pulvinar. Donec id mollis diam, id hendrerit neque. Donec accumsan efficitur libero, vitae feugiat odio fringilla ac. Aliquam a turpis bibendum, varius erat dictum, feugiat libero. Nam et dignissim nibh. Morbi elementum varius elit, at dignissim ex accumsan a';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmotionPieChart(emotion: emotion),
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
    var emotions = emotion.getTopFineEmotions();

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
        RecommendWords(emotion: emotion, tracks: tracks),
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

/// RecommendWords 是心情音乐推荐的推荐语
class RecommendWords extends StatelessWidget {
  final Emotion? emotion;
  final List<Track>? tracks;

  const RecommendWords({Key? key, this.emotion, this.tracks}) : super(key: key);

  /// requestRecommendWords 请求 murecom-writer 服务，获取推荐语写作结果。
  Future<String> requestRecommendWords() async {
    // 种子文本：前三心情 + 推荐歌名
    List<String> texts = [];
    if (emotion != null) {
      texts.add(emotion!
          .getTopFineEmotions()
          .map((e) => e.key)
          .map((s) => s
              .replaceAll(RegExp(r'\(.*?\)'), '')
              .replaceAll('疚', '内疚')
              .replaceAll('贬责', '烦恼'))
          .join("、"));
    }
    texts.addAll(tracks?.map((t) => t.name) ?? []);

    return queryRecommendWords(texts);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: requestRecommendWords(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          if (kDebugMode) {
            print(snapshot.data);
          }
          return PopupText(text: (snapshot.data as String));
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            print(snapshot.error);
          }
          return const SizedBox(height: 50);
        }
        // loading
        return const SizedBox(
          height: 50,
          child: Text('...'),
        );
      },
    );
  }
}

/// EmotionPieChart 是生动展现心情大类的饼图
class EmotionPieChart extends StatelessWidget {
  final Emotion emotion;

  const EmotionPieChart({
    Key? key,
    required this.emotion,
  }) : super(key: key);

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
            data: highChartJsData(emotion.getEmotionPieSections()),
            scripts: const [
              "https://code.highcharts.com/highcharts.js",
              'https://code.highcharts.com/modules/networkgraph.js',
              'https://code.highcharts.com/modules/exporting.js',
            ],
          );
        } else {
          return PieChart(
            PieChartData(
              sections: emotion
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
  final List<Track> tracks;

  /// 若该 [RecommendList] 属于 [NextSongPage]，
  /// 则应该设置 [fromNext] 为当前 [NextSongPage] 的层数。
  ///
  /// [RecommendPage] 的 [RecommendList] [fromNext] 应设置为 -1，
  /// [RecommendPage] 第一次调用 [NextSongPage] 时 [fromNext] 为 0，
  /// 再次点击列表中的歌，进行续曲推荐，则 [fromNext] 为 1，
  /// 再一次为 2，然后 3，4，5，...
  final int? fromNext;

  /// 若该 RecommendList 属于 [NextSongPage]，则应该另 fromNext++
  const RecommendList({
    Key? key,
    required this.tracks,
    this.fromNext = -1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text("没有推荐的音乐。"),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        var track = tracks[index];
        return ListTile(
          // TODO: track cover
          leading: AlbumCoverImage(
            track.albumCover ?? "",
            height: 50,
            width: 50,
          ),
          title: Text(tracks[index].name),
          subtitle: Text(track.artists.join(" & ")),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NextSongPage(
                  seedTrack: track,
                  fromNext: (fromNext ?? -1) + 1,
                ),
              ),
            );
            // showDialog(
            //   context: context,
            //   builder: (context) => Dialog(
            //     child: Column(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         Padding(
            //           padding: const EdgeInsets.all(16.0),
            //           child: Center(
            //             child:
            //                 Text('${track.name}\n${track.artists.join(' & ')}'),
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // );
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
@Deprecated('debug')
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
