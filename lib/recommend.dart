import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// enum RecommendSeedType {
//   text,
//   pic,
// }

const emotextServer = '192.168.43.214:8081';

Uri emotextUri(String text) {
  return Uri.http(emotextServer, '/text', {'text': text});
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
  final List<int>? pic;

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  late Future<RecommendResult> data;

  Future<RecommendResult> requestEmopicRecommend() async {
    throw ('Not implemented'); // TODO: requestEmopicRecommend not implemented
    var request = http.MultipartRequest('POST', Uri.parse('uri'));
    request.files.add(http.MultipartFile.fromBytes('img', widget.pic!));
    final response = await request.send();

    // .then((response) {
    //   if (response.statusCode == 200) print("Uploaded!");
    // });
    // return response.stream.toString();
    return RecommendResult([], [], []);
  }

  Future<RecommendResult> requestEmotextRecommend() async {
    final uri = emotextUri(widget.text ?? '');
    if (kDebugMode) {
      print('request ${uri.toString()}');
    }

    final response = await http.get(uri);
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
      appBar: AppBar(
        title: const Text('recommend'),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          children: [
            widget.text != null ? Text(widget.text!) : const Text("no text"),
            widget.pic != null
                ? Image.memory(Uint8List.fromList(widget.pic!))
                : const Text("no img"),
            FutureBuilder(
              future: data,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                List<Widget> children;

                if (snapshot.hasData) {
                  children = [
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('resp: ${snapshot.data}'),
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
      ),
    );
  }
}
