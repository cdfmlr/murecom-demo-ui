import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';

import 'package:murecom/widgets/expandable_fab.dart';
import 'package:murecom/recommend.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'model.dart';

Future<void> main() async {
  runApp(const MyApp());
}

const String appTitle = '基于心情的音乐推荐';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const HomePage(title: appTitle),
    );
  }
}

/// HomePage 完成 文本/图片 输入、提交，然后转到 [RecommendPage]。
///
/// 默认显示文本输入，类似于 Google 搜索首页。输入文本后提交，进行文本情感音乐推荐。
///
/// 通过右下角的 FAB 可以从拍照，或从相册选择图片。选择或拍照后，
/// 文本框会被替换为图片预览，点击提交按钮，进行从图像的情感音乐推荐。
///
/// 显示图像预览的状态下也可以通过 FAB 的一个子按钮返回到文本输入界面。
class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String text = '';
  XFile? pic;

  final ImagePicker _picker = ImagePicker();

  bool _textSubmitable = false;

  /// DO NOT TOUCH THIS VALUE. Use _showTextInsteadOfPic instead.
  bool _showText = true;

  bool get _showTextInsteadOfPic => _showText; // false to show pic
  set _showTextInsteadOfPic(bool v) {
    if (_showText != v) {
      _showText = v;

      text = _showText ? text : '';
      _textSubmitable = text.isNotEmpty;
      pic = _showText ? null : pic;

      setState(() {});
    }
  }

  void _onTextChanged(String value) {
    text = value;

    // submitable?
    if (text.isNotEmpty) {
      setState(() {
        _textSubmitable = true;
      });
    } else if (_textSubmitable) {
      setState(() {
        _textSubmitable = false;
      });
    }

    if (kDebugMode) {
      print("text: " + text);
    }
  }

  void _onTextSubmit() {
    if (text.isEmpty) {
      if (kDebugMode) {
        print('submit(pic): unexpected empty string!');
      }
      return;
    }

    if (kDebugMode) {
      print('submit(text): ' + text);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendPage(
          text: text,
        ),
      ),
    );
  }

  void _onPicSubmit() {
    if (pic == null) {
      if (kDebugMode) {
        print('submit(pic): unexpected null pic!');
      }
      return;
    }

    if (kDebugMode) {
      print('submit(pic): ' + pic!.name);
    }

    var imgBytes = pic!.readAsBytes();
    imgBytes.then((value) {
      if (kDebugMode) {
        print('pic length in bytes: ${value.lengthInBytes}');
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecommendPage(
            pic: SimpleFile(pic!.name, value),
          ),
        ),
      );
    });
  }

  Future<void> _imagePick(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
        source: source,
        // Compression
        maxHeight: 600,
        maxWidth: 600,
        imageQuality: 100);

    if (kDebugMode) {
      print(image?.name);
    }

    if (image != null) {
      pic = image;
      _showTextInsteadOfPic = false;
      setState(() {});
    }
  }

  Future<void> _onCameraPressed() async {
    if (kDebugMode) {
      print('pack image from camera');
    }
    // TODO: camera not supported on web
    _imagePick(ImageSource.camera);
  }

  Future<void> _onPhotoPressed() async {
    if (kDebugMode) {
      print('pack image from gallery');
    }

    _imagePick(ImageSource.gallery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),

      body: Container(
        margin: const EdgeInsets.only(left: 24, right: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // title
              const Title(),
              // main: emotext or emopic
              _showTextInsteadOfPic ? buildEmotext() : buildEmopic(context),
              // version
              const Padding(
                padding: EdgeInsets.only(top: 100.0),
                child: VersionText(),
              ),
            ],
          ),
        ),
      ),

      // fab: text | pic_from_photo | pic_from_camera
      floatingActionButton: ExpandableFab(
        icon: const Icon(Icons.insert_emoticon),
        distance: 112.0,
        children: [
          ActionButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () {
              _showTextInsteadOfPic = true;
            },
          ),
          ActionButton(
            icon: const Icon(Icons.photo),
            onPressed: () => _onPhotoPressed(),
          ),
          ActionButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _onCameraPressed(),
          ),
        ],
      ),
    );
  }

  /// buildEmotext 构建输入/提交文本的 widget
  Widget buildEmotext() {
    return Row(
      // emotext
      children: <Widget>[
        // input text
        Flexible(
          child: TextField(
            minLines: 1,
            maxLines: 10,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.text_fields),
                labelText: '你想说的话'),
            onChanged: (value) => _onTextChanged(value),
          ),
        ),
        // Submit text
        Visibility(
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            child: ElevatedButton(
              onPressed: () => _onTextSubmit(),
              child: const Text('提交'),
            ),
          ),
          visible: _textSubmitable,
        ),
      ],
    );
  }

  /// buildEmopic 构建预览/提交图片的 widget
  Widget buildEmopic(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.shortestSide / 1.2,
        maxHeight: MediaQuery.of(context).size.shortestSide / 1.2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // emopic
        children: [
          // pic image preview

          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: InteractiveViewer(
              child: kIsWeb
                  ? Image.network(pic!.path,
                      height: MediaQuery.of(context).size.shortestSide / 1.5,
                      width: MediaQuery.of(context).size.shortestSide / 1.5)
                  : Image.file(File(pic!.path),
                      height: MediaQuery.of(context).size.shortestSide / 1.5,
                      width: MediaQuery.of(context).size.shortestSide / 1.5),
            ),
          ),

          // submit button
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: () => _onPicSubmit(),
              child: const Text('提交'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title 显示一个 murecom 的大字标题，类似于 Google 搜索首页
class Title extends StatelessWidget {
  const Title({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'murecom',
        style: Theme.of(context).textTheme.headline2,
      ),
    );
  }
}

/// VersionText 显示版本
class VersionText extends StatelessWidget {
  const VersionText({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            var packageInfo = snapshot.data as PackageInfo;
            return Text(
                'version: ${packageInfo.version} (build ${packageInfo.buildNumber})',
                style: Theme.of(context).textTheme.overline);
          }
          return Container();
        });
  }
}
