import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:murecom/recommend.dart';
import 'package:murecom/widgets/progress_indicator.dart';

/// 提供 next-song 服务的 murecom-intro 服务器
const nextSongServer = '192.168.43.214:8082';

/// nextSongUri 构造 next-song 请求的 URL。传入 [seed] 参数构造 GET 请求的 query.
Uri nextSongUri(Track seed) {
  return Uri.http(
      nextSongServer, '/next-song', {'track_name': seed.name, 'k': '10'});
}

/// NextSongPage 是显示续曲的页面。
class NextSongPage extends StatefulWidget {
  final Track seedTrack;

  const NextSongPage({Key? key, required this.seedTrack}) : super(key: key);

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
      body: Container(
          margin: const EdgeInsets.all(16.0),
          child: FutureBuilder(
            future: requestNextSong(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                var tracks = snapshot.data as List<Track>;
                return RecommendList(tracks: tracks);
              }
              if (snapshot.hasError) {
                return RecommendErrorView(error: snapshot.error);
              }

              // loading
              return const TextProgressIndicator(text: Text("查询中..."));
            },
          )),
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
    final uri = nextSongUri(widget.seedTrack);
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
