import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'GB'),
    Locale('en', 'US'),
  ];

  /// The name of the application.
  ///
  /// In en, this message translates to:
  /// **'HueTap'**
  String get appTitle;

  /// Label for a button that closes a success dialog or bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Label for a button that returns to the previous screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Label for a button that retries a failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Label for a button that restarts a network scan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get commonRescan;

  /// Generic error line shown when a screen fails to load.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String commonErrorMessage(String message);

  /// AppBar title on the home screen. Usually the product name.
  ///
  /// In en, this message translates to:
  /// **'HueTap'**
  String get homeAppBarTitle;

  /// Floating action button label on the home screen — opens a menu to add a card or bridge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get homeNewActionLabel;

  /// Menu item title: start the flow to bind an NFC card to a scene.
  ///
  /// In en, this message translates to:
  /// **'Bind a new card'**
  String get homeAddSheetBindCardTitle;

  /// Menu item subtitle explaining the bind flow.
  ///
  /// In en, this message translates to:
  /// **'Pick a scene, then tap a blank tag'**
  String get homeAddSheetBindCardSubtitle;

  /// Menu item title: start the flow to pair an additional Hue bridge.
  ///
  /// In en, this message translates to:
  /// **'Pair another bridge'**
  String get homeAddSheetPairBridgeTitle;

  /// Title of the bottom sheet shown when the user must choose among multiple paired bridges.
  ///
  /// In en, this message translates to:
  /// **'Pick a bridge'**
  String get homePickBridgeSheetTitle;

  /// Empty-state headline shown when the user has no paired bridges.
  ///
  /// In en, this message translates to:
  /// **'No bridge paired yet'**
  String get homeEmptyBridgesTitle;

  /// Empty-state body shown when the user has no paired bridges.
  ///
  /// In en, this message translates to:
  /// **'Find your Hue bridge on Wi-Fi, then press its link button.'**
  String get homeEmptyBridgesDescription;

  /// Primary call-to-action button label in the empty-bridges state.
  ///
  /// In en, this message translates to:
  /// **'Find bridge'**
  String get homeEmptyBridgesCta;

  /// Section header above the list of paired bridges.
  ///
  /// In en, this message translates to:
  /// **'Bridges'**
  String get homeSectionBridges;

  /// Section header above the list of NFC cards bound to scenes.
  ///
  /// In en, this message translates to:
  /// **'Bound cards'**
  String get homeSectionBoundCards;

  /// Placeholder title used when a bridge has no human-readable name yet.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get homeBridgeFallbackName;

  /// Empty-state headline shown when the user has no bound NFC cards.
  ///
  /// In en, this message translates to:
  /// **'No cards bound yet'**
  String get homeEmptyCardsTitle;

  /// Empty-state body shown when the user has no bound NFC cards.
  ///
  /// In en, this message translates to:
  /// **'Pick a scene and tap a blank NTAG card to bind it.'**
  String get homeEmptyCardsDescription;

  /// Primary call-to-action button label in the empty-cards state.
  ///
  /// In en, this message translates to:
  /// **'Pick a scene'**
  String get homeEmptyCardsCta;

  /// Card subtitle showing how many times this card has been tapped.
  ///
  /// In en, this message translates to:
  /// **'Taps: {count}'**
  String homeCardTapsSubtitle(int count);

  /// Card subtitle showing tap count and the timestamp of the most recent tap.
  ///
  /// In en, this message translates to:
  /// **'Taps: {count} · last: {lastTapped}'**
  String homeCardTapsWithLastSubtitle(int count, String lastTapped);

  /// AppBar title on the bridge discovery screen.
  ///
  /// In en, this message translates to:
  /// **'Find bridge'**
  String get discoveryScreenTitle;

  /// Tooltip on the rescan button in the discovery app bar.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get discoveryRescanTooltip;

  /// Status line shown while the network scan is in progress.
  ///
  /// In en, this message translates to:
  /// **'Scanning the network…'**
  String get discoveryStatusScanning;

  /// Status line shown when a completed scan found no bridges.
  ///
  /// In en, this message translates to:
  /// **'No bridges found'**
  String get discoveryStatusNoBridges;

  /// Status line shown when a completed scan found exactly one bridge.
  ///
  /// In en, this message translates to:
  /// **'Found 1 bridge'**
  String get discoveryStatusFoundOne;

  /// Status line shown when a completed scan found multiple bridges.
  ///
  /// In en, this message translates to:
  /// **'Found {count} bridges'**
  String discoveryStatusFoundMany(int count);

  /// Empty-state card headline on the discovery screen.
  ///
  /// In en, this message translates to:
  /// **'No bridges found'**
  String get discoveryEmptyTitle;

  /// Empty-state card body on the discovery screen.
  ///
  /// In en, this message translates to:
  /// **'Make sure your phone is on the same Wi-Fi as the bridge. You can also rescan or enter an IP below.'**
  String get discoveryEmptyDescription;

  /// Card title for the manual-IP fallback on the discovery screen.
  ///
  /// In en, this message translates to:
  /// **'Enter IP manually'**
  String get discoveryManualIpTitle;

  /// Placeholder text in the manual-IP text field. An IPv4 address example.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.10'**
  String get discoveryManualIpHint;

  /// Button label that submits a manually entered IP and starts pairing.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get discoveryManualIpSubmit;

  /// AppBar title on the link-button polling screen.
  ///
  /// In en, this message translates to:
  /// **'Pair bridge'**
  String get pairPollScreenTitle;

  /// Success banner title shown when pairing completes.
  ///
  /// In en, this message translates to:
  /// **'Paired!'**
  String get pairPollSuccessTitle;

  /// Failure banner title shown when pairing fails.
  ///
  /// In en, this message translates to:
  /// **'Pair failed'**
  String get pairPollFailedTitle;

  /// Instruction shown while polling the bridge for link-button confirmation.
  ///
  /// In en, this message translates to:
  /// **'Press the link button'**
  String get pairPollLinkButtonTitle;

  /// Detailed instruction for the link-button step, including the bridge's IP.
  ///
  /// In en, this message translates to:
  /// **'Push the large round button on top of your Hue bridge at {ip}.'**
  String pairPollLinkButtonDescription(String ip);

  /// Countdown label beneath the circular progress indicator.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s remaining'**
  String pairPollSecondsRemaining(int seconds);

  /// Empty-state title on the scenes list for a bridge.
  ///
  /// In en, this message translates to:
  /// **'No scenes yet'**
  String get scenesEmptyTitle;

  /// Empty-state body on the scenes list for a bridge.
  ///
  /// In en, this message translates to:
  /// **'Create a scene in the Hue app, then pull to refresh.'**
  String get scenesEmptyDescription;

  /// Scene action-sheet option: fire this scene immediately to test it.
  ///
  /// In en, this message translates to:
  /// **'Fire scene now'**
  String get sceneActionFireNowTitle;

  /// Subtitle for the 'fire now' scene action explaining its purpose.
  ///
  /// In en, this message translates to:
  /// **'Test the connection'**
  String get sceneActionFireNowSubtitle;

  /// Scene action-sheet option: bind this scene to an NFC card.
  ///
  /// In en, this message translates to:
  /// **'Bind to NFC card'**
  String get sceneActionBindTitle;

  /// Subtitle for the 'bind' scene action explaining its purpose.
  ///
  /// In en, this message translates to:
  /// **'Write this scene to a blank tag'**
  String get sceneActionBindSubtitle;

  /// SnackBar message shown after a scene fires successfully.
  ///
  /// In en, this message translates to:
  /// **'Fired {sceneName}'**
  String sceneFiredSnackbar(String sceneName);

  /// Bottom-sheet title for the card-binding flow.
  ///
  /// In en, this message translates to:
  /// **'Bind a card'**
  String get bindCardSheetTitle;

  /// Subtitle showing which scene the new card will be bound to.
  ///
  /// In en, this message translates to:
  /// **'Scene: {sceneName}'**
  String bindCardSceneLabel(String sceneName);

  /// Text field label where the user can name the card.
  ///
  /// In en, this message translates to:
  /// **'Card label (optional)'**
  String get bindCardLabelField;

  /// Placeholder text in the card-label field. Example of a typical card location.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nightstand'**
  String get bindCardLabelHint;

  /// Button that starts the NFC write session in the bind flow.
  ///
  /// In en, this message translates to:
  /// **'Hold a blank card'**
  String get bindCardStartButton;

  /// Status title shown while the phone is waiting for an NFC tag.
  ///
  /// In en, this message translates to:
  /// **'Waiting for tag…'**
  String get bindCardWaitingTitle;

  /// Status body shown while the phone is waiting for an NFC tag.
  ///
  /// In en, this message translates to:
  /// **'Hold a blank NTAG card against the back of your phone.'**
  String get bindCardWaitingDescription;

  /// Status title shown after a card is successfully bound.
  ///
  /// In en, this message translates to:
  /// **'Card bound!'**
  String get bindCardSuccessTitle;

  /// Status text shown on the cold-start fire screen and the foreground firing indicator.
  ///
  /// In en, this message translates to:
  /// **'Firing…'**
  String get tapFiringStatus;

  /// SnackBar message shown after a scene fires successfully from a foreground tap.
  ///
  /// In en, this message translates to:
  /// **'Fired {sceneName}'**
  String tapFiredSnackbar(String sceneName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return AppLocalizationsEnGb();
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
