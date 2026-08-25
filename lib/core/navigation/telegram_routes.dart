import 'package:flutter/material.dart';

abstract final class TelegramLayoutBreakpoints {
  static const double mobile = 800;
  static const double threeColumn = 840;
  static const double chatListWidth = 340;
}

abstract final class TelegramNavigationDurations {
  static const Duration push = Duration(milliseconds: 175);
  static const Duration fade = Duration(milliseconds: 175);
}

class TelegramPushRoute<T> extends MaterialPageRoute<T> {
  TelegramPushRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
  });

  @override
  Duration get transitionDuration => TelegramNavigationDurations.push;

  @override
  Duration get reverseTransitionDuration => TelegramNavigationDurations.push;
}

class TelegramFadeRoute<T> extends PageRouteBuilder<T> {
  TelegramFadeRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
          transitionDuration: TelegramNavigationDurations.fade,
          reverseTransitionDuration: TelegramNavigationDurations.fade,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}

class TelegramSlideTransitionsBuilder extends PageTransitionsBuilder {
  const TelegramSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final offsetAnimation = animation.drive(
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).chain(
        CurveTween(curve: Curves.easeOutCubic),
      ),
    );
    return SlideTransition(position: offsetAnimation, child: child);
  }
}

abstract final class TelegramRoutes {
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
  }) {
    return Navigator.of(context).push<T>(
      TelegramPushRoute<T>(settings: settings, builder: (_) => page),
    );
  }

  static Future<T?> fade<T extends Object?>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      TelegramFadeRoute<T>(
        settings: settings,
        fullscreenDialog: fullscreenDialog,
        builder: (_) => page,
      ),
    );
  }
}
