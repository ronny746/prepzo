import 'package:flutter/widgets.dart';

/// Shared observer so screens kept alive under pushed routes (e.g. Home under
/// an exam) can react via [RouteAware.didPopNext] and refresh their data.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
