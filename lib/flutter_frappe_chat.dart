/// Frappe Chat for Flutter: realtime messaging, attachments, voice notes and a
/// ready-made chat screen.
///
/// ```dart
/// final config = FrappeChatConfig(
///   baseUrl: 'https://erp.example.com',
///   sid: mySessionId,
/// );
///
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ChatScreen(
///     config: config,
///     room: 'room-id',
///     sender: 'Jane Doe',
///     senderEmail: 'jane@example.com',
///   ),
/// ));
/// ```
///
/// Requires the [frappe/chat](https://github.com/frappe/chat) app on the site.
library;

export 'src/api/frappe_api.dart';
export 'src/models/chat_config.dart';
export 'src/models/chat_message.dart';
export 'src/models/chat_theme.dart';
export 'src/screens/chat_screen.dart';
export 'src/socket/socket_manager.dart';
export 'src/utils/permissions.dart';
export 'src/widgets/attachment_sheet.dart' show AttachmentSheet, PickedAttachment;
export 'src/widgets/message_bubble.dart' show MessageBubble, ChatAttachmentKind;
export 'src/widgets/typing_indicator.dart';
