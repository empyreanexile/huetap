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
  String get commonDone => 'Done';

  @override
  String get commonBack => 'Back';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonRescan => 'Rescan';

  @override
  String commonErrorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get homeAppBarTitle => 'HueTap';

  @override
  String get homeNewActionLabel => 'New';

  @override
  String get homeAddSheetBindCardTitle => 'Bind a new card';

  @override
  String get homeAddSheetBindCardSubtitle =>
      'Pick a scene, then tap a blank tag';

  @override
  String get homeAddSheetPairBridgeTitle => 'Pair another bridge';

  @override
  String get homePickBridgeSheetTitle => 'Pick a bridge';

  @override
  String get homeEmptyBridgesTitle => 'No bridge paired yet';

  @override
  String get homeEmptyBridgesDescription =>
      'Find your Hue bridge on Wi-Fi, then press its link button.';

  @override
  String get homeEmptyBridgesCta => 'Find bridge';

  @override
  String get homeSectionBridges => 'Bridges';

  @override
  String get homeSectionBoundCards => 'Bound cards';

  @override
  String get homeBridgeFallbackName => 'Bridge';

  @override
  String get homeEmptyCardsTitle => 'No cards bound yet';

  @override
  String get homeEmptyCardsDescription =>
      'Pick a scene and tap a blank NTAG card to bind it.';

  @override
  String get homeEmptyCardsCta => 'Pick a scene';

  @override
  String homeCardTapsSubtitle(int count) {
    return 'Taps: $count';
  }

  @override
  String homeCardTapsWithLastSubtitle(int count, String lastTapped) {
    return 'Taps: $count · last: $lastTapped';
  }

  @override
  String get discoveryScreenTitle => 'Find bridge';

  @override
  String get discoveryRescanTooltip => 'Rescan';

  @override
  String get discoveryStatusScanning => 'Scanning the network…';

  @override
  String get discoveryStatusNoBridges => 'No bridges found';

  @override
  String get discoveryStatusFoundOne => 'Found 1 bridge';

  @override
  String discoveryStatusFoundMany(int count) {
    return 'Found $count bridges';
  }

  @override
  String get discoveryEmptyTitle => 'No bridges found';

  @override
  String get discoveryEmptyDescription =>
      'Make sure your phone is on the same Wi-Fi as the bridge. You can also rescan or enter an IP below.';

  @override
  String get discoveryManualIpTitle => 'Enter IP manually';

  @override
  String get discoveryManualIpHint => '192.168.1.10';

  @override
  String get discoveryManualIpSubmit => 'Pair';

  @override
  String get pairPollScreenTitle => 'Pair bridge';

  @override
  String get pairPollSuccessTitle => 'Paired!';

  @override
  String get pairPollFailedTitle => 'Pair failed';

  @override
  String get pairPollLinkButtonTitle => 'Press the link button';

  @override
  String pairPollLinkButtonDescription(String ip) {
    return 'Push the large round button on top of your Hue bridge at $ip.';
  }

  @override
  String pairPollSecondsRemaining(int seconds) {
    return '${seconds}s remaining';
  }

  @override
  String get scenesEmptyTitle => 'No scenes yet';

  @override
  String get scenesEmptyDescription =>
      'Create a scene in the Hue app, then pull to refresh.';

  @override
  String get sceneActionFireNowTitle => 'Fire scene now';

  @override
  String get sceneActionFireNowSubtitle => 'Test the connection';

  @override
  String get sceneActionBindTitle => 'Bind to NFC card';

  @override
  String get sceneActionBindSubtitle => 'Write this scene to a blank tag';

  @override
  String sceneFiredSnackbar(String sceneName) {
    return 'Fired $sceneName';
  }

  @override
  String get bindCardSheetTitle => 'Bind a card';

  @override
  String bindCardSceneLabel(String sceneName) {
    return 'Scene: $sceneName';
  }

  @override
  String get bindCardLabelField => 'Card label (optional)';

  @override
  String get bindCardLabelHint => 'e.g. Nightstand';

  @override
  String get bindCardStartButton => 'Hold a blank card';

  @override
  String get bindCardWaitingTitle => 'Waiting for tag…';

  @override
  String get bindCardWaitingDescription =>
      'Hold a blank NTAG card against the back of your phone.';

  @override
  String get bindCardSuccessTitle => 'Card bound!';

  @override
  String get tapFiringStatus => 'Firing…';

  @override
  String tapFiredSnackbar(String sceneName) {
    return 'Fired $sceneName';
  }
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String get appTitle => 'HueTap';

  @override
  String get commonDone => 'Done';

  @override
  String get commonBack => 'Back';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonRescan => 'Rescan';

  @override
  String commonErrorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get homeAppBarTitle => 'HueTap';

  @override
  String get homeNewActionLabel => 'New';

  @override
  String get homeAddSheetBindCardTitle => 'Bind a new card';

  @override
  String get homeAddSheetBindCardSubtitle =>
      'Pick a scene, then tap a blank tag';

  @override
  String get homeAddSheetPairBridgeTitle => 'Pair another bridge';

  @override
  String get homePickBridgeSheetTitle => 'Pick a bridge';

  @override
  String get homeEmptyBridgesTitle => 'No bridge paired yet';

  @override
  String get homeEmptyBridgesDescription =>
      'Find your Hue bridge on Wi-Fi, then press its link button.';

  @override
  String get homeEmptyBridgesCta => 'Find bridge';

  @override
  String get homeSectionBridges => 'Bridges';

  @override
  String get homeSectionBoundCards => 'Bound cards';

  @override
  String get homeBridgeFallbackName => 'Bridge';

  @override
  String get homeEmptyCardsTitle => 'No cards bound yet';

  @override
  String get homeEmptyCardsDescription =>
      'Pick a scene and tap a blank NTAG card to bind it.';

  @override
  String get homeEmptyCardsCta => 'Pick a scene';

  @override
  String homeCardTapsSubtitle(int count) {
    return 'Taps: $count';
  }

  @override
  String homeCardTapsWithLastSubtitle(int count, String lastTapped) {
    return 'Taps: $count · last: $lastTapped';
  }

  @override
  String get discoveryScreenTitle => 'Find bridge';

  @override
  String get discoveryRescanTooltip => 'Rescan';

  @override
  String get discoveryStatusScanning => 'Scanning the network…';

  @override
  String get discoveryStatusNoBridges => 'No bridges found';

  @override
  String get discoveryStatusFoundOne => 'Found 1 bridge';

  @override
  String discoveryStatusFoundMany(int count) {
    return 'Found $count bridges';
  }

  @override
  String get discoveryEmptyTitle => 'No bridges found';

  @override
  String get discoveryEmptyDescription =>
      'Make sure your phone is on the same Wi-Fi as the bridge. You can also rescan or enter an IP below.';

  @override
  String get discoveryManualIpTitle => 'Enter IP manually';

  @override
  String get discoveryManualIpHint => '192.168.1.10';

  @override
  String get discoveryManualIpSubmit => 'Pair';

  @override
  String get pairPollScreenTitle => 'Pair bridge';

  @override
  String get pairPollSuccessTitle => 'Paired!';

  @override
  String get pairPollFailedTitle => 'Pair failed';

  @override
  String get pairPollLinkButtonTitle => 'Press the link button';

  @override
  String pairPollLinkButtonDescription(String ip) {
    return 'Push the large round button on top of your Hue bridge at $ip.';
  }

  @override
  String pairPollSecondsRemaining(int seconds) {
    return '${seconds}s remaining';
  }

  @override
  String get scenesEmptyTitle => 'No scenes yet';

  @override
  String get scenesEmptyDescription =>
      'Create a scene in the Hue app, then pull to refresh.';

  @override
  String get sceneActionFireNowTitle => 'Fire scene now';

  @override
  String get sceneActionFireNowSubtitle => 'Test the connection';

  @override
  String get sceneActionBindTitle => 'Bind to NFC card';

  @override
  String get sceneActionBindSubtitle => 'Write this scene to a blank tag';

  @override
  String sceneFiredSnackbar(String sceneName) {
    return 'Fired $sceneName';
  }

  @override
  String get bindCardSheetTitle => 'Bind a card';

  @override
  String bindCardSceneLabel(String sceneName) {
    return 'Scene: $sceneName';
  }

  @override
  String get bindCardLabelField => 'Card label (optional)';

  @override
  String get bindCardLabelHint => 'e.g. Bedside table';

  @override
  String get bindCardStartButton => 'Hold a blank card';

  @override
  String get bindCardWaitingTitle => 'Waiting for tag…';

  @override
  String get bindCardWaitingDescription =>
      'Hold a blank NTAG card against the back of your phone.';

  @override
  String get bindCardSuccessTitle => 'Card bound!';

  @override
  String get tapFiringStatus => 'Firing…';

  @override
  String tapFiredSnackbar(String sceneName) {
    return 'Fired $sceneName';
  }
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get appTitle => 'HueTap';

  @override
  String get commonDone => 'Done';

  @override
  String get commonBack => 'Back';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonRescan => 'Rescan';

  @override
  String commonErrorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get homeAppBarTitle => 'HueTap';

  @override
  String get homeNewActionLabel => 'New';

  @override
  String get homeAddSheetBindCardTitle => 'Bind a new card';

  @override
  String get homeAddSheetBindCardSubtitle =>
      'Pick a scene, then tap a blank tag';

  @override
  String get homeAddSheetPairBridgeTitle => 'Pair another bridge';

  @override
  String get homePickBridgeSheetTitle => 'Pick a bridge';

  @override
  String get homeEmptyBridgesTitle => 'No bridge paired yet';

  @override
  String get homeEmptyBridgesDescription =>
      'Find your Hue bridge on Wi-Fi, then press its link button.';

  @override
  String get homeEmptyBridgesCta => 'Find bridge';

  @override
  String get homeSectionBridges => 'Bridges';

  @override
  String get homeSectionBoundCards => 'Bound cards';

  @override
  String get homeBridgeFallbackName => 'Bridge';

  @override
  String get homeEmptyCardsTitle => 'No cards bound yet';

  @override
  String get homeEmptyCardsDescription =>
      'Pick a scene and tap a blank NTAG card to bind it.';

  @override
  String get homeEmptyCardsCta => 'Pick a scene';

  @override
  String homeCardTapsSubtitle(int count) {
    return 'Taps: $count';
  }

  @override
  String homeCardTapsWithLastSubtitle(int count, String lastTapped) {
    return 'Taps: $count · last: $lastTapped';
  }

  @override
  String get discoveryScreenTitle => 'Find bridge';

  @override
  String get discoveryRescanTooltip => 'Rescan';

  @override
  String get discoveryStatusScanning => 'Scanning the network…';

  @override
  String get discoveryStatusNoBridges => 'No bridges found';

  @override
  String get discoveryStatusFoundOne => 'Found 1 bridge';

  @override
  String discoveryStatusFoundMany(int count) {
    return 'Found $count bridges';
  }

  @override
  String get discoveryEmptyTitle => 'No bridges found';

  @override
  String get discoveryEmptyDescription =>
      'Make sure your phone is on the same Wi-Fi as the bridge. You can also rescan or enter an IP below.';

  @override
  String get discoveryManualIpTitle => 'Enter IP manually';

  @override
  String get discoveryManualIpHint => '192.168.1.10';

  @override
  String get discoveryManualIpSubmit => 'Pair';

  @override
  String get pairPollScreenTitle => 'Pair bridge';

  @override
  String get pairPollSuccessTitle => 'Paired!';

  @override
  String get pairPollFailedTitle => 'Pair failed';

  @override
  String get pairPollLinkButtonTitle => 'Press the link button';

  @override
  String pairPollLinkButtonDescription(String ip) {
    return 'Push the large round button on top of your Hue bridge at $ip.';
  }

  @override
  String pairPollSecondsRemaining(int seconds) {
    return '${seconds}s remaining';
  }

  @override
  String get scenesEmptyTitle => 'No scenes yet';

  @override
  String get scenesEmptyDescription =>
      'Create a scene in the Hue app, then pull to refresh.';

  @override
  String get sceneActionFireNowTitle => 'Fire scene now';

  @override
  String get sceneActionFireNowSubtitle => 'Test the connection';

  @override
  String get sceneActionBindTitle => 'Bind to NFC card';

  @override
  String get sceneActionBindSubtitle => 'Write this scene to a blank tag';

  @override
  String sceneFiredSnackbar(String sceneName) {
    return 'Fired $sceneName';
  }

  @override
  String get bindCardSheetTitle => 'Bind a card';

  @override
  String bindCardSceneLabel(String sceneName) {
    return 'Scene: $sceneName';
  }

  @override
  String get bindCardLabelField => 'Card label (optional)';

  @override
  String get bindCardLabelHint => 'e.g. Nightstand';

  @override
  String get bindCardStartButton => 'Hold a blank card';

  @override
  String get bindCardWaitingTitle => 'Waiting for tag…';

  @override
  String get bindCardWaitingDescription =>
      'Hold a blank NTAG card against the back of your phone.';

  @override
  String get bindCardSuccessTitle => 'Card bound!';

  @override
  String get tapFiringStatus => 'Firing…';

  @override
  String tapFiredSnackbar(String sceneName) {
    return 'Fired $sceneName';
  }
}
