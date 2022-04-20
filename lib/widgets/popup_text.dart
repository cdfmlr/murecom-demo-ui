import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
