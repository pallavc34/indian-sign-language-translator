import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kPrimaryColor = Color(0xFFE65100); // Deep Orange
const Color kBackgroundColor = Color(0xFFF9F9F9);

ThemeData appThemeData = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryColor,
    brightness: Brightness.light,
    surface: kBackgroundColor,
  ),
  textTheme: GoogleFonts.outfitTextTheme(),
  appBarTheme: const AppBarThemeData(
    centerTitle: true,
    elevation: 0,
    backgroundColor: kBackgroundColor,
    foregroundColor: Colors.black87,
  ),
  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: kPrimaryColor.withValues(alpha: 0.2),
  ),
);

ThemeData darkAppThemeData = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryColor,
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
  appBarTheme: const AppBarThemeData(
    centerTitle: true,
    elevation: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: kPrimaryColor.withValues(alpha: 0.4),
  ),
);
