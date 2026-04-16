// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HueTap';

  @override
  String get scaffoldingPlaceholderTitle => 'Scaffolding in progress';

  @override
  String get scaffoldingPlaceholderBody =>
      'Repository scaffolding is set up against spec v1.4. Feature implementation has not started yet.';
}
