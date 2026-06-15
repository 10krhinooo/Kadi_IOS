/* eslint-disable @typescript-eslint/no-explicit-any */
import * as admin from "firebase-admin";
import { sendPushToUser } from "./push";

jest.mock("firebase-admin", () => {
  const firestoreMock: any = jest.fn();
  return {
    firestore: firestoreMock,
    messaging: jest.fn(),
  };
});

describe("sendPushToUser", () => {
  const notification = { title: "Title", body: "Body" };

  let userDocGet: jest.Mock;
  let userDocUpdate: jest.Mock;
  let sendEachForMulticast: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();

    userDocUpdate = jest.fn().mockResolvedValue(undefined);
    userDocGet = jest.fn();

    const docRef = { get: userDocGet, update: userDocUpdate };
    const collection = jest.fn().mockReturnValue({
      doc: jest.fn().mockReturnValue(docRef),
    });
    (admin.firestore as unknown as jest.Mock).mockReturnValue({ collection });
    (admin.firestore as any).FieldValue = {
      arrayRemove: jest.fn((...tokens: string[]) => ({ arrayRemove: tokens })),
    };

    sendEachForMulticast = jest.fn();
    (admin.messaging as unknown as jest.Mock).mockReturnValue({
      sendEachForMulticast,
    });
  });

  it("does nothing when the user has no tokens", async () => {
    userDocGet.mockResolvedValue({ data: () => ({ fcmTokens: [] }) });

    await sendPushToUser("uid1", notification);

    expect(sendEachForMulticast).not.toHaveBeenCalled();
    expect(userDocUpdate).not.toHaveBeenCalled();
  });

  it("sends to all tokens and leaves them when all succeed", async () => {
    userDocGet.mockResolvedValue({
      data: () => ({ fcmTokens: ["token-a", "token-b"] }),
    });
    sendEachForMulticast.mockResolvedValue({
      responses: [{ success: true }, { success: true }],
    });

    await sendPushToUser("uid1", notification, { type: "dm" });

    expect(sendEachForMulticast).toHaveBeenCalledWith({
      tokens: ["token-a", "token-b"],
      notification,
      data: { type: "dm" },
    });
    expect(userDocUpdate).not.toHaveBeenCalled();
  });

  it("removes tokens reported as no-longer-registered", async () => {
    userDocGet.mockResolvedValue({
      data: () => ({ fcmTokens: ["token-a", "token-b"] }),
    });
    sendEachForMulticast.mockResolvedValue({
      responses: [
        { success: true },
        {
          success: false,
          error: { code: "messaging/registration-token-not-registered" },
        },
      ],
    });

    await sendPushToUser("uid1", notification);

    expect(userDocUpdate).toHaveBeenCalledWith({
      fcmTokens: { arrayRemove: ["token-b"] },
    });
  });
});
