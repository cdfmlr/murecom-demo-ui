import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:murecom/recommend.dart';
import 'package:murecom/widgets/progress_indicator.dart';

/// 提供 next-song 服务的 murecom-intro 服务器
const nextSongServer = '192.168.43.214:8082';

/// nextSongCount 是续曲推荐的曲目数
const nextSongCount = 10;

/// nextSongUri 构造 next-song 请求的 URL。传入 [seed] 参数构造 GET 请求的 query.
Uri nextSongUri(Track seed, {int? k = 10, int? shift = 0}) {
  return Uri.http(nextSongServer, '/next-song', {
    'track_name': seed.name,
    'k': k?.toString() ?? '10',
    'shift': shift?.toString() ?? '0',
  });
}

/// NextSongPage 是显示续曲的页面。
class NextSongPage extends StatefulWidget {
  final Track seedTrack;

  /// 这个页面是来自第几个 NextSongPage 的：
  /// NextSongPage(0) -> NextSongPage(1) -> NextSongPage(2) -> ...
  final int? fromNext;

  const NextSongPage({Key? key, required this.seedTrack, this.fromNext = 0})
      : super(key: key);

  @override
  State<NextSongPage> createState() => _NextSongPageState();
}

class _NextSongPageState extends State<NextSongPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('更多类似「${widget.seedTrack.name}」的歌曲'),
      ),
      body: FutureBuilder(
        future: requestNextSong(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            var tracks = snapshot.data as List<Track>;
            return ListView(
              children: [
                Container(
                  margin: const EdgeInsets.all(16.0),
                  child:
                      RecommendList(tracks: tracks, fromNext: widget.fromNext),
                )
              ],
            );
          }
          if (snapshot.hasError) {
            return Center(child: RecommendErrorView(error: snapshot.error));
          }

          // loading
          return const Center(child: TextProgressIndicator(text: Text("查询中...")));
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.insert_emoticon),
        onPressed: _onEmotionFabPressed,
      ),
    );
  }

  /// _onEmotionFabPressed 处理点击 FAB 的事件：返回到首页。
  void _onEmotionFabPressed() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<List<Track>> requestNextSong() async {
    var k = nextSongCount;
    var shift = k * (widget.fromNext ?? 0);
    if (shift > 1000) {
      shift = 1000;
    }
    final uri = nextSongUri(widget.seedTrack, k: k, shift: shift);
    if (kDebugMode) {
      print('request ${uri.toString()}');
    }

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      var e = BadRequestException(response.body);
      throw e;
    }

    var jsonResult = jsonDecode(response.body);
    var tracks = (jsonResult as List).map((e) => Track.fromJson(e)).toList();

    return tracks;
  }
}
