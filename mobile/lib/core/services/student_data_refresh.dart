import 'package:flutter/widgets.dart';

/// Lets screens notice when the student comes back to the main tabs, so data
/// that a test (or any other pushed screen) may have changed is reloaded.
///
/// * [appRouteObserver] is registered on the MaterialApp; MainLayoutScreen
///   subscribes to it and refreshes when a page pushed on top of it closes.
/// * [studentDataRefreshTick] is bumped by MainLayoutScreen whenever it
///   refreshes; tabs that own their own cubit (e.g. Progress) listen to it.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

final ValueNotifier<int> studentDataRefreshTick = ValueNotifier<int>(0);
