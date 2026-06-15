import * as admin from "firebase-admin";

export interface PushNotification {
  title: string;
  body: string;
}

/**
 * Sends `notification`/`data` to every token in `/users/{uid}.fcmTokens` via
 * `sendEachForMulticast`, removing any token that FCM reports as no longer
 * registered.
 */
export async function sendPushToUser(
  uid: string,
  notification: PushNotification,
  data: Record<string, string> = {}
): Promise<void> {
  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();
  const tokens: string[] = userDoc.data()?.fcmTokens ?? [];

  if (tokens.length === 0) {
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification,
    data,
  });

  const staleTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (
      !result.success &&
      result.error?.code === "messaging/registration-token-not-registered"
    ) {
      staleTokens.push(tokens[index]);
    }
  });

  if (staleTokens.length > 0) {
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
    });
  }
}
