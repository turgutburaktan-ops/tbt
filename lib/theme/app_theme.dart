import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // TBT visual identity: cinematic dark surfaces + controlled cyan/violet neon.
  static const background = Color(0xFF08090B);
  static const backgroundRaised = Color(0xFF0D0F12);
  static const surface = Color(0xFF14161B);
  static const surfaceAlt = Color(0xFF191C22);
  static const surfaceStrong = Color(0xFF20242B);
  static const surfaceElevated = Color(0xFF252A32);
  static const messageOutgoing = Color(0xFF172B46);
  static const navigation = Color(0xFF08090B);

  static const cyan = Color(0xFF09D7F2);
  static const violet = Color(0xFF9828FF);
  static const violetBright = Color(0xFF9828FF);
  static const cyanSoft = Color(0x2209D7F2);
  static const violetSoft = Color(0x229828FF);

  static const blue = Color(0xFF267CFF);
  static const primary = blue;
  static const primaryBright = blue;
  static const secondary = cyan;
  static const accent = violet;

  static const border = Color(0xFF292D35);
  static const borderStrong = Color(0xFF383E48);
  static const borderAccent = Color(0x66267CFF);
  static const textMuted = Color(0xFFADB4C0);
  static const textSubtle = Color(0xFF8D96A5);
  static const liked = Color(0xFFFF617A);
  static const success = Color(0xFF67D6B1);
  static const warning = Color(0xFFF4BE6A);

  static const accentGradient = LinearGradient(
    colors: [cyan, blue, violet],
    stops: [0, .52, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradientHorizontal = LinearGradient(
    colors: [cyan, blue, violet],
    stops: [0, .52, 1],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const subtleGradient = LinearGradient(
    colors: [surface, surfaceAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadii {
  AppRadii._();
  static const small = 10.0;
  static const medium = 14.0;
  static const large = 14.0;
  static const xLarge = 18.0;
  static const pill = 999.0;
}

class AppSpacing {
  AppSpacing._();
  static const page = 16.0;
  static const small = 8.0;
  static const gap = 12.0;
  static const section = 24.0;
  static const controlHeight = 48.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.blue,
          secondary: AppColors.blue,
          tertiary: AppColors.cyan,
          primaryContainer: AppColors.surfaceStrong,
          secondaryContainer: AppColors.surfaceStrong,
          tertiaryContainer: AppColors.surfaceStrong,
          onPrimaryContainer: Colors.white,
          onSecondaryContainer: Colors.white,
          onTertiaryContainer: Colors.white,
          surface: AppColors.surface,
          surfaceContainerHighest: AppColors.surfaceStrong,
          surfaceContainer: AppColors.surface,
          surfaceContainerLow: AppColors.backgroundRaised,
          surfaceContainerHigh: AppColors.surfaceAlt,
          surfaceContainerLowest: AppColors.background,
          surfaceTint: Colors.transparent,
          onSurface: Colors.white,
          onSurfaceVariant: AppColors.textMuted,
          outline: AppColors.border,
          outlineVariant: AppColors.borderStrong,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          error: AppColors.liked,
        );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      splashFactory: InkRipple.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.blue,
        selectionColor: Color(0x44267CFF),
        selectionHandleColor: AppColors.blue,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navigation,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
      ),
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
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        iconTheme: IconThemeData(color: Color(0xFFE7E9EF), size: 22),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 28,
          height: 1.05,
          fontWeight: FontWeight.w700,
          letterSpacing: -.75,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 23,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -.15,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFE8EAF0),
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFC5CAD3),
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          height: 1.32,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: .05,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surfaceAlt,
        headerForegroundColor: Colors.white,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.surface,
        dialBackgroundColor: AppColors.surfaceAlt,
        dialHandColor: AppColors.blue,
        entryModeIconColor: AppColors.blue,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        floatingLabelStyle: const TextStyle(
          color: AppColors.blue,
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
          borderSide: const BorderSide(color: AppColors.blue, width: 1.35),
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
          minimumSize: const Size(0, AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textSubtle,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          foregroundColor: const Color(0xFFF0F1F5),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: const Color(0xFF142840),
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
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textMuted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF142840)
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
        indicatorColor: Color(0xFF142840),
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
        color: AppColors.blue,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.surfaceStrong,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.blue,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
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
