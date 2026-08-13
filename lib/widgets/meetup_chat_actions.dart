import 'package:flutter/material.dart';

import '../models/spot_meetup.dart';
import '../screens/chat_screen.dart';

Future<void> openMeetupHostChat(BuildContext context, SpotMeetup meetup) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        otherUserId: meetup.hostId,
        otherDisplayName: meetup.hostName,
        sourceType: 'meetup',
        sourceId: meetup.id,
      ),
    ),
  );
}
