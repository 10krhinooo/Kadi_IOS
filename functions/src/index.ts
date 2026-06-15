import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { sendPushToUser } from "./push";

admin.initializeApp();
setGlobalOptions({ region: "europe-west1" });

/** `/friendRequests/{id}` — notifies `toUid` that `fromName` sent a friend request. */
export const onFriendRequestCreated = onDocumentCreated(
  "friendRequests/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { fromName, toUid } = data as { fromName: string; toUid: string };

    await sendPushToUser(
      toUid,
      {
        title: "Friend Request",
        body: `${fromName} sent you a friend request`,
      },
      { type: "friendRequest" }
    );
  }
);

/** `/gameInvites/{id}` — notifies `toUid` that `fromName` invited them to a game. */
export const onGameInviteCreated = onDocumentCreated(
  "gameInvites/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { fromName, toUid, roomId } = data as {
      fromName: string;
      toUid: string;
      roomId: string;
    };

    await sendPushToUser(
      toUid,
      {
        title: "Game Invite",
        body: `${fromName} invited you to a game`,
      },
      { type: "gameInvite", roomId }
    );
  }
);

const DM_BODY_MAX_LENGTH = 100;

/**
 * `/conversations/{convId}/messages/{id}` — notifies the other participant of
 * `convId` (`sortedUidA_sortedUidB`) that `senderUid` sent a message.
 */
export const onDmMessageCreated = onDocumentCreated(
  "conversations/{convId}/messages/{id}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { senderUid, text } = data as { senderUid: string; text: string };
    const convId = event.params.convId;
    const recipientUid = convId.split("_").find((uid) => uid !== senderUid);
    if (!recipientUid) return;

    const senderDoc = await admin
      .firestore()
      .collection("users")
      .doc(senderUid)
      .get();
    const senderName = (senderDoc.data()?.displayName as string) ?? "Someone";

    const body =
      text.length > DM_BODY_MAX_LENGTH
        ? `${text.slice(0, DM_BODY_MAX_LENGTH)}…`
        : text;

    await sendPushToUser(
      recipientUid,
      { title: senderName, body },
      { type: "dm", convId }
    );
  }
);
