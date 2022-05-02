import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'model.dart';

// region baseURLs

/// 提供 next-song 服务的 murecom-intro 服务器
const nextSongServer = '192.168.43.214:8082';

/// 提供 emotext 服务的 emotional_recommender.py 服务器
const emotextServer = '192.168.43.214:8081';

/// 提供 emotext 服务的 emotional_recommender.py 服务器
const emopicServer = '192.168.43.214:8081';

/// 提供 TextGenerate 服务的 mta-lstm/infer.py 服务器
const writerServer = '192.168.43.214:8083';

// endregion baseURLs

// region URLConstructors

/// emotextUri 构造 emotext 请求的 URL。传入 [text] 参数构造 GET 请求的 query.
Uri emotextUri(String text) {
  return Uri.http(emotextServer, '/text', {'text': text});
}

/// emopicUri 获取 emopic 服务的 URL。
/// 因为要上传图片，所以这个用 POST 请求传数据，所以这里不构造 query 了。
Uri emopicUri() {
  return Uri.http(emopicServer, '/pic');
}

/// writerUri 是获取推荐语 (recommendWords) 的服务的 URL。
/// 传入请求的种子文本 [texts]，作为 query 写到 url 里。
Uri writerUri(List<String> texts) {
  return Uri.http(writerServer, '/gen', {'s': texts});
  // var s = texts.map((s) => s.replaceAll(' ', '-')).map((s) => Uri.encodeFull(s)).join('+');
  // return Uri.parse('http://$writerServer/gen?s=$s');
}

/// nextSongUri 构造 next-song 请求的 URL。传入 [seed] 参数构造 GET 请求的 query.
Uri nextSongUri(Track seed, {int? k = 10, int? shift = 0}) {
  return Uri.http(nextSongServer, '/next-song', {
    'track_name': seed.name,
    'k': k?.toString() ?? '10',
    'shift': shift?.toString() ?? '0',
  });
}

// endregion URLConstructors

// region requests

/// queryNextSong 请求 next-song 服务，获取续曲推荐结果。
///
/// ```
///   POST http://next-song.server/next-song?track_name={seedTrack.name}&k=10&shift=3
/// ```
Future<List<Track>> queryNextSong(Track seedTrack, int? k, int? shift) async {
  final uri = nextSongUri(seedTrack, k: k, shift: shift);
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

/// queryRecommendWords 请求 murecom-writer 服务，获取推荐语写作结果。
///
/// ```
///   POST http://writer.server/next-song?s={text[0]}&s={text[1]}&...
/// ```
Future<String> queryRecommendWords(List<String> seedTexts) async {
  final uri = writerUri(seedTexts);
  if (kDebugMode) {
    print('request ${uri.toString()}');
  }

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    var e = BadRequestException(response.body);
    throw e;
  }

  return response.body;
}

/// requestEmopicRecommend 请求 emopic 服务，获取从图像的心情音乐推荐结果。
///
/// ```
///   POST http://emopic.server/pic
///      FILE: img={filename=pic.filename, file=pic.file}
/// ```
Future<RecommendResult> queryEmopicRecommend(SimpleFile pic) async {
  var request = http.MultipartRequest('POST', emopicUri());
  request.files.add(
    http.MultipartFile.fromBytes('img', pic.bytes, filename: pic.filename),
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
Future<RecommendResult> queryEmotextRecommend(String text) async {
  final uri = emotextUri(text);
  if (kDebugMode) {
    print('request ${uri.toString()}');
  }

  final response = await http.get(uri);

  return parseRecommendResponse(response);
}

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

// endregion requests

// region exceptions

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

// endregion exceptions
