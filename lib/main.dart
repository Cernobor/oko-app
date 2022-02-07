import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main_widget.dart';
import 'i18n.dart';

const _primary = Color(0xff153d24);
const _primaryVariant = Color(0xff001900);
const _onPrimary = Color(0xffffffff);
const _secondary = Color(0xffffa74c);
const _secondaryVariant = Color(0xffc7781b);
const _onSecondary = Color(0xff000000);
const _surface = Color(0xff40684c);
const _onSurface = Color(0xffffffff);
const _background = Color(0xff000000);
const _onBackground = Color(0xffffffff);
const _error = Color(0xff890000);
const _onError = Color(0xffffffff);
const _disabled = Color(0x88909090);
const _onDisabled = Color(0x88ffffff);

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext ctx) => I18N.of(ctx).appTitle,
      theme: ThemeData(
          colorScheme: const ColorScheme(
              primary: _primary,
              primaryVariant: _primaryVariant,
              secondary: _secondary,
              secondaryVariant: _secondaryVariant,
              surface: _surface,
              background: _background,
              error: _error,
              onPrimary: _onPrimary,
              onSecondary: _onSecondary,
              onSurface: _onSurface,
              onBackground: _onBackground,
              onError: _onError,
              brightness: Brightness.dark),
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.disabled)) {
                return _disabled;
              }
              if (states.contains(MaterialState.selected)) {
                return _secondary;
              }
            }),
            checkColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.disabled)) {
                return _onDisabled;
              }
              if (states.contains(MaterialState.selected)) {
                return _onSecondary;
              }
            })
          ),
          disabledColor: _disabled,
          backgroundColor: _background),
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
