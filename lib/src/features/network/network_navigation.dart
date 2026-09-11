import '../../bindings/bindings.dart';

/// The three connection families presented by the console.
enum NetworkTab { wifi, ethernet, vpn }

/// Wi-Fi navigation carries precisely the data needed by the current view.
sealed class WifiPage {
  const WifiPage();
}

/// The active connection and its shortcuts.
final class WifiOverview extends WifiPage {
  const WifiOverview();
}

/// Nearby access points, including scan and connection feedback.
final class WifiChoosing extends WifiPage {
  const WifiChoosing();
}

/// A secured access point awaiting credentials.
final class WifiCredentials extends WifiPage {
  const WifiCredentials(this.entry, {this.error});
  final NetworkEntry entry;
  final String? error;
}

/// A submitted join, pending a matching backend result or live confirmation.
final class WifiJoining extends WifiPage {
  const WifiJoining(this.entry);
  final NetworkEntry entry;
}

/// A manually named or hidden network's name and credential flow.
final class WifiOther extends WifiPage {
  const WifiOther();
}

/// An open-network join failed without introducing an irrelevant password field.
final class WifiFailure extends WifiPage {
  const WifiFailure(this.entry, this.message);
  final NetworkEntry entry;
  final String message;
}
