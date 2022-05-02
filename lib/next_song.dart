import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:murecom/recommend.dart';
import 'package:murecom/requests.dart';
import 'package:murecom/widgets/progress_indicator.dart';

import 'model.dart';

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
          return const Center(
              child: TextProgressIndicator(text: Text("查询中...")));
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

  /// requestNextSong 请求 next-song 服务，获取续曲推荐结果。
  Future<List<Track>> requestNextSong() async {
    var k = nextSongCount;
    var shift = k * (widget.fromNext ?? 0);
    if (shift > 1000) {
      shift = 1000;
    }
    return queryNextSong(widget.seedTrack, k, shift);
  }
}
