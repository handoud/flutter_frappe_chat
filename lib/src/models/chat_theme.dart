import 'package:flutter/material.dart';

/// Colours and shapes for the bundled chat UI.
///
/// Defaults to the classic green chat look. Call [FrappeChatTheme.fromTheme] to
/// derive one from the app's own [ColorScheme] instead, including dark mode.
///
/// ```dart
/// ChatScreen(
///   config: config,
///   room: room,
///   sender: name,
///   senderEmail: email,
///   theme: FrappeChatTheme.fromTheme(Theme.of(context)),
/// );
/// ```
@immutable
class FrappeChatTheme {
  /// Background behind the message list.
  final Color background;

  /// Bubble colour for the current user's messages.
  final Color outgoingBubble;

  /// Bubble colour for everyone else's messages.
  final Color incomingBubble;

  /// Text colour inside outgoing bubbles.
  final Color outgoingText;

  /// Text colour inside incoming bubbles.
  final Color incomingText;

  /// Colour of the sender name above incoming bubbles.
  final Color senderNameColor;

  /// Colour of timestamps and read receipts.
  final Color metaColor;

  /// Background of the message input bar.
  final Color inputBackground;

  /// Colour of the send and microphone buttons.
  final Color accent;

  /// App bar background. Null uses the ambient theme.
  final Color? appBarBackground;

  /// App bar foreground. Null uses the ambient theme.
  final Color? appBarForeground;

  /// Corner radius for message bubbles.
  final double bubbleRadius;

  /// Text style for message bodies. Merged over the default.
  final TextStyle? messageTextStyle;

  const FrappeChatTheme({
    this.background = const Color(0xFFECE5DD),
    this.outgoingBubble = const Color(0xFFDCF8C6),
    this.incomingBubble = Colors.white,
    this.outgoingText = const Color(0xFF111B21),
    this.incomingText = const Color(0xFF111B21),
    this.senderNameColor = const Color(0xFFE65100),
    this.metaColor = const Color(0xFF667781),
    this.inputBackground = Colors.white,
    this.accent = const Color(0xFF075E54),
    this.appBarBackground,
    this.appBarForeground,
    this.bubbleRadius = 12,
    this.messageTextStyle,
  });

  /// Derives a theme from the app's [ThemeData], honouring light and dark mode.
  factory FrappeChatTheme.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return FrappeChatTheme(
      background: isDark
          ? Color.alphaBlend(scheme.surfaceTint.withValues(alpha: 0.04),
              scheme.surface)
          : scheme.surfaceContainerLowest,
      outgoingBubble: scheme.primaryContainer,
      incomingBubble: scheme.surfaceContainerHighest,
      outgoingText: scheme.onPrimaryContainer,
      incomingText: scheme.onSurface,
      senderNameColor: scheme.primary,
      metaColor: scheme.onSurfaceVariant,
      inputBackground: scheme.surfaceContainerHigh,
      accent: scheme.primary,
      appBarBackground: scheme.surface,
      appBarForeground: scheme.onSurface,
      messageTextStyle: theme.textTheme.bodyMedium,
    );
  }

  FrappeChatTheme copyWith({
    Color? background,
    Color? outgoingBubble,
    Color? incomingBubble,
    Color? outgoingText,
    Color? incomingText,
    Color? senderNameColor,
    Color? metaColor,
    Color? inputBackground,
    Color? accent,
    Color? appBarBackground,
    Color? appBarForeground,
    double? bubbleRadius,
    TextStyle? messageTextStyle,
  }) {
    return FrappeChatTheme(
      background: background ?? this.background,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      incomingBubble: incomingBubble ?? this.incomingBubble,
      outgoingText: outgoingText ?? this.outgoingText,
      incomingText: incomingText ?? this.incomingText,
      senderNameColor: senderNameColor ?? this.senderNameColor,
      metaColor: metaColor ?? this.metaColor,
      inputBackground: inputBackground ?? this.inputBackground,
      accent: accent ?? this.accent,
      appBarBackground: appBarBackground ?? this.appBarBackground,
      appBarForeground: appBarForeground ?? this.appBarForeground,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      messageTextStyle: messageTextStyle ?? this.messageTextStyle,
    );
  }
}

/// How the realtime connection is doing.
enum ChatConnectionState {
  /// Not connected and not trying.
  disconnected,

  /// Handshake in progress.
  connecting,

  /// Connected and subscribed.
  connected,

  /// The server refused the connection. [ChatConnectionStatus.message] says why.
  failed,
}

/// The realtime connection state plus the reason, when it failed.
@immutable
class ChatConnectionStatus {
  final ChatConnectionState state;

  /// The server's reason for a failure, e.g. `Invalid namespace`.
  final String? message;

  const ChatConnectionStatus(this.state, [this.message]);

  bool get isConnected => state == ChatConnectionState.connected;

  @override
  bool operator ==(Object other) =>
      other is ChatConnectionStatus &&
      other.state == state &&
      other.message == message;

  @override
  int get hashCode => Object.hash(state, message);

  @override
  String toString() =>
      'ChatConnectionStatus(${state.name}${message == null ? '' : ': $message'})';
}
