/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/**
 * Helper function to send push notification to a user
 * @param {string} fcmToken - The FCM token of the recipient
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Additional data payload
 * @return {Promise} - Promise that resolves when notification is sent
 */
async function sendNotification(fcmToken, title, body, data = {}) {
  if (!fcmToken) {
    logger.warn("No FCM token provided");
    return;
  }

  const message = {
    token: fcmToken,
    notification: {
      title: title,
      body: body,
    },
    data: data,
    android: {
      notification: {
        channelId: "zerowaste_channel",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title: title,
            body: body,
          },
          badge: 1,
          sound: "default",
        },
      },
    },
  };

  try {
    const response = await messaging.send(message);
    logger.info("Successfully sent message:", response);
    return response;
  } catch (error) {
    logger.error("Error sending message:", error);
    if (error.code === "messaging/registration-token-not-registered") {
      logger.info("Token is invalid, should remove from database");
    }
    throw error;
  }
}

/**
 * Calculate distance between two points using Haversine formula
 * @param {number} lat1 - Latitude of first point
 * @param {number} lon1 - Longitude of first point
 * @param {number} lat2 - Latitude of second point
 * @param {number} lon2 - Longitude of second point
 * @return {number} - Distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distance = R * c; // Distance in kilometers
  return distance;
}

// 1. Notify food poster when someone claims their food
exports.notifyFoodClaimed = onDocumentCreated("claims/{claimId}",
    async (event) => {
      try {
        const claimData = event.data.data();
        const claimId = event.params.claimId;

        logger.info("New claim created:", claimId, claimData);

        // Get the post details
        const postDoc = await db.collection("posts").doc(claimData.postId)
            .get();
        if (!postDoc.exists) {
          logger.error("Post not found:", claimData.postId);
          return;
        }

        const postData = postDoc.data();

        // Get the poster's user details
        const posterDoc = await db.collection("users").doc(postData.userId)
            .get();
        if (!posterDoc.exists) {
          logger.error("Poster not found:", postData.userId);
          return;
        }

        const posterData = posterDoc.data();

        // Get the claimant's user details
        const claimantDoc = await db.collection("users").doc(claimData.userId)
            .get();
        if (!claimantDoc.exists) {
          logger.error("Claimant not found:", claimData.userId);
          return;
        }

        const claimantData = claimantDoc.data();

        // Send notification to the food poster
        if (posterData.fcmToken) {
          await sendNotification(
              posterData.fcmToken,
              "Someone claimed your food! 🍽️",
              `${claimantData.name} wants to claim "${postData.title}"`,
              {
                type: "food_claimed",
                postId: claimData.postId,
                claimId: claimId,
                claimantId: claimData.userId,
              },
          );
        }

        logger.info("Food claimed notification sent successfully");
      } catch (error) {
        logger.error("Error in notifyFoodClaimed:", error);
      }
    });

// 2. Notify claimant when their claim is accepted or rejected
exports.notifyClaimUpdate = onDocumentUpdated("claims/{claimId}",
    async (event) => {
      try {
        const beforeData = event.data.before.data();
        const afterData = event.data.after.data();
        const claimId = event.params.claimId;

        // Check if status changed
        if (beforeData.status === afterData.status) {
          return; // No status change, no notification needed
        }

        // Only notify for accepted or rejected status
        if (afterData.status !== "accepted" &&
          afterData.status !== "rejected") {
          return;
        }

        logger.info("Claim status updated:", claimId, beforeData.status,
            "->", afterData.status);

        // Get the post details
        const postDoc = await db.collection("posts").doc(afterData.postId)
            .get();
        if (!postDoc.exists) {
          logger.error("Post not found:", afterData.postId);
          return;
        }

        const postData = postDoc.data();

        // Get the claimant's user details
        const claimantDoc = await db.collection("users").doc(afterData.userId)
            .get();
        if (!claimantDoc.exists) {
          logger.error("Claimant not found:", afterData.userId);
          return;
        }

        const claimantData = claimantDoc.data();

        // Send notification to the claimant
        if (claimantData.fcmToken) {
          const isAccepted = afterData.status === "accepted";
          const title = isAccepted ?
            "Claim Accepted! 🎉" : "Claim Declined 😔";
          const body = isAccepted ?
            `Your claim for "${postData.title}" was accepted!` :
            `Your claim for "${postData.title}" was declined.`;

          await sendNotification(
              claimantData.fcmToken,
              title,
              body,
              {
                type: isAccepted ? "claim_accepted" : "claim_rejected",
                postId: afterData.postId,
                claimId: claimId,
                status: afterData.status,
              },
          );
        }

        logger.info("Claim update notification sent successfully");
      } catch (error) {
        logger.error("Error in notifyClaimUpdate:", error);
      }
    });

// 3. Notify nearby users when new food is posted
exports.notifyNearbyFood = onDocumentCreated("posts/{postId}",
    async (event) => {
      try {
        const postData = event.data.data();
        const postId = event.params.postId;

        logger.info("New post created:", postId, postData);

        // Get post location
        const postLat = postData.location.latitude;
        const postLon = postData.location.longitude;

        // Get the poster's details to exclude them from notifications
        const posterDoc = await db.collection("users").doc(postData.userId)
            .get();
        if (!posterDoc.exists) {
          logger.error("Poster not found:", postData.userId);
          return;
        }

        const posterData = posterDoc.data();

        // Get all users to check proximity
        const usersSnapshot = await db.collection("users").get();
        const nearbyUsers = [];

        usersSnapshot.forEach((userDoc) => {
          const userData = userDoc.data();
          const userId = userDoc.id;

          // Skip the poster themselves
          if (userId === postData.userId) {
            return;
          }

          // Skip users without FCM tokens
          if (!userData.fcmToken) {
            return;
          }

          // Skip users without location
          if (!userData.location || !userData.location.latitude ||
            !userData.location.longitude) {
            return;
          }

          // Calculate distance
          const userLat = userData.location.latitude;
          const userLon = userData.location.longitude;
          const distance = calculateDistance(postLat, postLon,
              userLat, userLon);

          // If within 20km, add to nearby users
          if (distance <= 20) {
            nearbyUsers.push({
              userId: userId,
              fcmToken: userData.fcmToken,
              name: userData.name,
              distance: distance.toFixed(1),
            });
          }
        });

        logger.info(`Found ${nearbyUsers.length} nearby users for ` +
          `post ${postId}`);

        // Send notifications to nearby users
        const notificationPromises = nearbyUsers.map(async (user) => {
          try {
            await sendNotification(
                user.fcmToken,
                "New food nearby! 📍",
                `${posterData.name} shared "${postData.title}" ` +
                `${user.distance}km away`,
                {
                  type: "new_food_nearby",
                  postId: postId,
                  distance: user.distance,
                  posterId: postData.userId,
                },
            );
          } catch (error) {
            logger.error(`Failed to send notification to user ` +
              `${user.userId}:`, error);
          }
        });

        await Promise.allSettled(notificationPromises);
        logger.info("Nearby food notifications sent successfully");
      } catch (error) {
        logger.error("Error in notifyNearbyFood:", error);
      }
    });

// 4. Notify users when they receive new messages
exports.notifyNewMessage = onDocumentCreated("messages/{messageId}",
    async (event) => {
      try {
        const messageData = event.data.data();
        const messageId = event.params.messageId;

        logger.info("New message created:", messageId, messageData);

        // Get the sender's details
        const senderDoc = await db.collection("users").doc(messageData.senderId)
            .get();
        if (!senderDoc.exists) {
          logger.error("Sender not found:", messageData.senderId);
          return;
        }

        const senderData = senderDoc.data();

        // Get the receiver's details
        const receiverDoc = await db.collection("users")
            .doc(messageData.receiverId).get();
        if (!receiverDoc.exists) {
          logger.error("Receiver not found:", messageData.receiverId);
          return;
        }

        const receiverData = receiverDoc.data();

        // Send notification to the receiver
        if (receiverData.fcmToken) {
          await sendNotification(
              receiverData.fcmToken,
              `New message from ${senderData.name} 💬`,
              messageData.text || "You have a new message",
              {
                type: "new_message",
                messageId: messageId,
                senderId: messageData.senderId,
                receiverId: messageData.receiverId,
                postId: messageData.postId || "",
              },
          );
        }

        logger.info("New message notification sent successfully");
      } catch (error) {
        logger.error("Error in notifyNewMessage:", error);
      }
    });

// 5. Test function to verify notifications are working
exports.testNotification = onDocumentCreated("test_notifications/{testId}",
    async (event) => {
      try {
        const testData = event.data.data();

        if (testData.fcmToken) {
          await sendNotification(
              testData.fcmToken,
              "Test Notification 🧪",
              "This is a test notification from Cloud Functions!",
              {
                type: "test",
                timestamp: new Date().toISOString(),
              },
          );

          logger.info("Test notification sent successfully");
        }
      } catch (error) {
        logger.error("Error in testNotification:", error);
      }
    });
