import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class NodeSelection extends StatelessWidget {
  const NodeSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: const Info(label: '节点选择', iconData: Icons.hub),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
            ),
          );
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          alignment: Alignment.bottomLeft,
          child: Text(
            "点击进入",
            style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
          ),
        ),
      ),
    );
  }
}
