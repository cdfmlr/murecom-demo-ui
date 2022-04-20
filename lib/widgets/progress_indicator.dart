import 'package:flutter/material.dart';

/// ProgressIndicator 就是个简单的等待的无限转圈进度条。
/// [text] 是显示在圈下面的文本。
class TextProgressIndicator extends StatelessWidget {
  final Widget text;

  const TextProgressIndicator({
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
