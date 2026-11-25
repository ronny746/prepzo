import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.header,
    this.showAppBar = true,
    this.drawer,
    this.onRefresh,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? header;
  final bool showAppBar;
  final Widget? drawer;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      extendBody: true,
      drawer: drawer,
      appBar: showAppBar
          ? AppBar(
              title: Text(
                title,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
              leading: drawer != null 
                  ? null 
                  : Builder(
                      builder: (context) {
                        if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
                          return IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          );
                        }
                        return Navigator.canPop(context) ? const BackButton() : const SizedBox.shrink();
                      },
                    ),
              actions: actions,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: onRefresh != null
              ? RefreshIndicator(
                  onRefresh: onRefresh!,
                  child: _buildScrollableBody(context),
                )
              : _buildScrollableBody(context),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildScrollableBody(BuildContext context) {
    return SingleChildScrollView(
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!showAppBar) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Builder(
                  builder: (context) {
                    if (drawer == null && Navigator.canPop(context)) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: BackButton(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                if (title.isNotEmpty)
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                  ),
                if (actions != null) Row(children: actions!),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (header != null) ...[header!, const SizedBox(height: 24)],
          body,
        ],
      ),
    );
  }
}
