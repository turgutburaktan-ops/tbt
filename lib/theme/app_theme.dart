import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // TBT visual identity: cinematic dark surfaces + controlled cyan/violet neon.
  static const background = Color(0xFF0B0D10);
  static const backgroundRaised = Color(0xFF111419);
  static const surface = Color(0xFF171A1F);
  static const surfaceAlt = Color(0xFF22262C);
  static const surfaceStrong = Color(0xFF22262C);
  static const surfaceElevated = Color(0xFF292E35);
  static const messageOutgoing = Color(0xFF203C39);
  static const navigation = Color(0xFF0B0D10);

  // Brand-only neon remains unchanged in the main navigation and logo accents.
  static const brandCyan = Color(0xFF09D7F2);
  static const brandBlue = Color(0xFF267CFF);
  static const brandViolet = Color(0xFF9828FF);
  static const textPrimary = Color(0xFFF2F1ED);
  static const onPrimary = Color(0xFF0B0D10);
  static const selection = Color(0xFF1B302D);
  static const cyan = Color(0xFF55CDBB);
  static const violet = Color(0xFF9828FF);
  static const violetBright = Color(0xFF9828FF);
  static const cyanSoft = Color(0x2255CDBB);
  static const violetSoft = Color(0x229828FF);

  static const blue = Color(0xFF267CFF);
  static const primary = cyan;
  static const primaryBright = cyan;
  static const secondary = cyan;
  static const accent = cyan;

  static const border = Color(0xFF32373E);
  static const borderStrong = Color(0xFF42484F);
  static const borderAccent = Color(0x6655CDBB);
  static const textMuted = Color(0xFFABA9A4);
  static const textSubtle = Color(0xFF8F9295);
  static const liked = Color(0xFFFF617A);
  static const success = Color(0xFF67D6B1);
  static const warning = Color(0xFFF4BE6A);

  static const accentGradient = LinearGradient(
    colors: [brandCyan, brandBlue, brandViolet],
    stops: [0, .52, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradientHorizontal = LinearGradient(
    colors: [brandCyan, brandBlue, brandViolet],
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
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.primary,
          tertiary: AppColors.cyan,
          primaryContainer: AppColors.surfaceStrong,
          secondaryContainer: AppColors.surfaceStrong,
          tertiaryContainer: AppColors.surfaceStrong,
          onPrimaryContainer: AppColors.textPrimary,
          onSecondaryContainer: AppColors.textPrimary,
          onTertiaryContainer: AppColors.textPrimary,
          surface: AppColors.surface,
          surfaceContainerHighest: AppColors.surfaceStrong,
          surfaceContainer: AppColors.surface,
          surfaceContainerLow: AppColors.backgroundRaised,
          surfaceContainerHigh: AppColors.surfaceAlt,
          surfaceContainerLowest: AppColors.background,
          surfaceTint: Colors.transparent,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textMuted,
          outline: AppColors.border,
          outlineVariant: AppColors.borderStrong,
          onPrimary: AppColors.onPrimary,
          onSecondary: AppColors.onPrimary,
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
        cursorColor: AppColors.primary,
        selectionColor: Color(0x4455CDBB),
        selectionHandleColor: AppColors.primary,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navigation,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        iconTheme: IconThemeData(color: Color(0xFFE7E9EF), size: 22),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          height: 1.05,
          fontWeight: FontWeight.w700,
          letterSpacing: -.75,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 23,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -.15,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          height: 1.32,
        ),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
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
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surfaceAlt,
        headerForegroundColor: AppColors.textPrimary,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.surface,
        dialBackgroundColor: AppColors.surfaceAlt,
        dialHandColor: AppColors.primary,
        entryModeIconColor: AppColors.primary,
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
          color: AppColors.primary,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.35),
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
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
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
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: const Color(0xFF1B302D),
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
          color: AppColors.textPrimary,
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
                ? AppColors.textPrimary
                : AppColors.textMuted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF1B302D)
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
        indicatorColor: Color(0xFF1B302D),
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
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.surfaceStrong,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: AppColors.textPrimary,
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
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
