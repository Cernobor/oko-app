import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n.dart';
import 'main_widget.dart';

const cbBlack = Color(0xff191919);
const cbGreen = Color(0xff153d24);
const cbBrown = Color(0xff793520);
const cbYellow = Color(0xffcda813);
const cbWhite = Color(0xfff4f3ee);

const colorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: cbYellow, // text field focus cursors, selection background
  // date picker bottom buttons, selected date and today date
  // time picker input box background (with alpha), text, clock hand, buttons
  // edited/new badges
  onPrimary: cbBlack, // date and time picker selected value text
  surface:
      cbGreen, // time picker background, app bar, date picker header background
  background: cbBlack,
  onBackground: cbWhite, // time picker clock background - with alpha
  onSurface: cbWhite, // time picker non-selected values (both boxes and clock)
  secondary: cbBrown, // FAB bg
  onSecondary: cbWhite, // FAB text/fg
  primaryContainer: Color(0xFF005229),
  onPrimaryContainer: cbWhite,
  secondaryContainer: Color(0xFF7C2D14),
  onSecondaryContainer: Color(0xFFFFDACF),
  tertiary: Color(0xFF55D6F4),
  onTertiary: Color(0xFF003641),
  tertiaryContainer: Color(0xFF004E5D),
  onTertiaryContainer: Color(0xFFA6EDFF),
  error: Color(0xffff3c00),
  errorContainer: Color(0xFF930006),
  onError: cbBlack,
  onErrorContainer: Color(0xFFFFDAD4),
  surfaceVariant: Color(0xFF414941), // >card color
  onSurfaceVariant: cbWhite,
  outline: Color(0xFF8B938A),
  onInverseSurface: Color(0xFF1A1C1A),
  inverseSurface: Color(0xFFE1E3DE),
  inversePrimary: Color(0xFF006D3A),
  shadow: Color(0xFF000000),
);

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext ctx) => I18N.of(ctx).appTitle,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          disabledColor: colorScheme.onSurface
              .withOpacity(.35), // disabled items text/foreground
          bottomAppBarColor: colorScheme.surface, // bottom bar
          errorColor: colorScheme.error, // errors
          scaffoldBackgroundColor:
              colorScheme.background, // background of subpages
          cardColor: colorScheme.surfaceVariant, // info target background
          toggleableActiveColor: colorScheme
              .primary, // active/selected radio buttons, switches, checkbox background
          unselectedWidgetColor:
              null, // inactive/unselected radio buttons, checkbox outlines
          dividerColor: null, // dividers
          highlightColor: null, // scrollbar
          hintColor: null, // text field top hint when unfocused
          dialogBackgroundColor: null, // default background of dialogs
          shadowColor: null, // shadows
          secondaryHeaderColor: null,
          indicatorColor: null,
          focusColor: null,
          primaryColorLight: null,
          hoverColor: null,
          backgroundColor: null,
          primaryColor: null,
          primaryColorDark: null,
          canvasColor: null,
          selectedRowColor: null, //
          splashColor: null, //
          accentColor: null,
          buttonColor: null,
          // themes
          drawerTheme: DrawerThemeData(
            backgroundColor: colorScheme.background,
          ),
          textButtonTheme: TextButtonThemeData(
              style: ButtonStyle(
                  foregroundColor:
                      MaterialStateProperty.all(colorScheme.primary))),
          checkboxTheme: CheckboxThemeData(
              checkColor: MaterialStateProperty.all(colorScheme.onPrimary)),
          tooltipTheme: const TooltipThemeData(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8))),
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
