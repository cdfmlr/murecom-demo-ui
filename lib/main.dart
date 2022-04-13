import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';

import 'package:murecom/expandable_fab.dart';

Future<void> main() async {
  runApp(const MyApp());
}

const String appTitle = 'murecom demo';

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
    // TODO: submit text
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

    // TODO: submit pic
  }

  Future<void> _imagePick(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);

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
        title: Text(widget.title),
      ),

      body: Container(
        margin: const EdgeInsets.only(left: 24, right: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'murecom',
                  style: Theme.of(context).textTheme.headline2,
                ),
              ),

              // main: emotext or emopic
              _showTextInsteadOfPic
                  ? Row(
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
                    )
                  : Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.shortestSide / 1.2,
                        maxHeight:
                            MediaQuery.of(context).size.shortestSide / 1.2,
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
                                      height: MediaQuery.of(context)
                                              .size
                                              .shortestSide /
                                          1.5,
                                      width: MediaQuery.of(context)
                                              .size
                                              .shortestSide /
                                          1.5)
                                  : Image.file(File(pic!.path),
                                      height: MediaQuery.of(context)
                                              .size
                                              .shortestSide /
                                          1.5,
                                      width: MediaQuery.of(context)
                                              .size
                                              .shortestSide /
                                          1.5),
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
                    ),

              const SizedBox(height: 100),
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
}
