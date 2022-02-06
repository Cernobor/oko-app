import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main_widget.dart';
import 'i18n.dart';

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext ctx) => I18N.of(ctx).appTitle,
      theme: ThemeData(
          colorScheme: const ColorScheme(
              primary: Color(0xff153d24),
              primaryVariant: Color(0xff001900),
              secondary: Color(0xff752f1a),
              secondaryVariant: Color(0xff460200),
              surface: Color(0xff40684c),
              background: Color(0xff000000),
              error: Color(0xffff6200),
              onPrimary: Color(0xffffffff),
              onSecondary: Color(0xffffffff),
              onSurface: Color(0xffffffff),
              onBackground: Color(0xffffffff),
              onError: Color(0xff000000),
              brightness: Brightness.dark),
          primaryColorLight: const Color(0xffcda813),
          disabledColor: const Color(0x88909090),
          backgroundColor: const Color(0xff153d24)),
      home: const MainWidget(),
      localizationsDelegates: const [
        I18NDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: const [Locale('en'), Locale('cs')],
    );
  }
}

void main() => runApp(const Home());
