import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/tab.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NodeSelection extends ConsumerWidget {
  const NodeSelection({super.key});

  Future<void> _showProxySheet(BuildContext context, WidgetRef ref) async {
    final proxiesTabKey = GlobalKey<ProxiesTabViewState>();
    await showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: '节点选择',
          actions: [
            IconButton(
              tooltip: appLocalizations.sync,
              onPressed: () async {
                final profile = ref.read(currentProfileProvider);
                if (profile == null || profile.type == ProfileType.file) {
                  return;
                }
                await appController.updateProfile(profile, showLoading: true);
              },
              icon: const Icon(Icons.sync),
            ),
            IconButton(
              tooltip: appLocalizations.delayTest,
              onPressed: () async {
                await proxiesTabKey.currentState?.delayTestCurrentGroup();
              },
              icon: const Icon(Icons.network_ping),
            ),
            const CloseButton(),
          ],
          body: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ProxiesTabView(key: proxiesTabKey),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentGroupName =
        ref.watch(currentProfileProvider.select((state) => state?.currentGroupName)) ??
        GroupName.GLOBAL.name;
    final selectedProxyName =
        ref.watch(getSelectedProxyNameProvider(currentGroupName)) ??
        ref.watch(getSelectedProxyNameProvider(GroupName.GLOBAL.name)) ??
        '';
    final proxyName =
        selectedProxyName.isEmpty ? appLocalizations.noProxy : selectedProxyName;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: const Info(label: '节点选择', iconData: Icons.public),
        onPressed: () {
          _showProxySheet(context, ref);
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              Expanded(
                child: EmojiText(
                  proxyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.toSoftBold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: context.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
