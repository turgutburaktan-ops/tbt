import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // TBT visual identity: cinematic dark surfaces + controlled cyan/violet neon.
  static const background = Color(0xFF05060A);
  static const backgroundRaised = Color(0xFF080A10);
  static const surface = Color(0xFF0D1017);
  static const surfaceAlt = Color(0xFF131722);
  static const surfaceStrong = Color(0xFF1A1F2C);
  static const surfaceElevated = Color(0xFF202636);
  static const navigation = Color(0xFF090B11);

  static const cyan = Color(0xFF45E7F2);
  static const violet = Color(0xFF9B67F6);
  static const violetBright = Color(0xFFB482FF);
  static const cyanSoft = Color(0x2245E7F2);
  static const violetSoft = Color(0x229B67F6);

  static const primary = violet;
  static const primaryBright = Color(0xFFF5F4FA);
  static const secondary = cyan;
  static const accent = violet;

  static const border = Color(0xFF252B37);
  static const borderStrong = Color(0xFF343C4B);
  static const borderAccent = Color(0x668F73E8);
  static const textMuted = Color(0xFF9CA4B2);
  static const textSubtle = Color(0xFF6F7888);
  static const liked = Color(0xFFFF617A);
  static const success = Color(0xFF67D6B1);
  static const warning = Color(0xFFF4BE6A);

  static const accentGradient = LinearGradient(
    colors: [cyan, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradientHorizontal = LinearGradient(
    colors: [cyan, violet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const subtleGradient = LinearGradient(
    colors: [Color(0x2245E7F2), Color(0x229B67F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadii {
  AppRadii._();
  static const small = 10.0;
  static const medium = 14.0;
  static const large = 18.0;
  static const xLarge = 22.0;
  static const pill = 999.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.violet,
      secondary: AppColors.cyan,
      tertiary: AppColors.violetBright,
      surface: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceAlt,
      outline: AppColors.border,
      outlineVariant: AppColors.borderStrong,
      onPrimary: Colors.white,
      onSecondary: const Color(0xFF031113),
      error: AppColors.liked,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -.3,
        ),
        iconTheme: IconThemeData(color: Color(0xFFE7E9EF), size: 22),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 28,
          height: 1.05,
          fontWeight: FontWeight.w900,
          letterSpacing: -.75,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 23,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: -.5,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.15,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFE8EAF0),
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFC5CAD3),
          fontSize: 13,
          height: 1.38,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          height: 1.32,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: .05,
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFD7DBE3), size: 22),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        floatingLabelStyle: const TextStyle(
          color: AppColors.violetBright,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 13),
        prefixIconColor: const Color(0xFFB7BECA),
        suffixIconColor: AppColors.textMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.35),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.liked),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.liked, width: 1.35),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textSubtle,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          foregroundColor: const Color(0xFFF0F1F5),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.violetBright,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: const Color(0xFF242139),
        disabledColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          color: Color(0xFFC2C7D0),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textMuted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF242139)
                : AppColors.surface,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? AppColors.borderAccent
                  : AppColors.border,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 62,
        backgroundColor: AppColors.navigation,
        indicatorColor: Color(0xFF242139),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.navigation,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.surfaceStrong,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      dividerColor: AppColors.border,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
