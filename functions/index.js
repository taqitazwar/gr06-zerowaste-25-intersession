/* eslint-disable max-len */
/**
 * ZeroWaste App Cloud Functions
 * Comprehensive notification system for food sharing app
 */

const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

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
    data: {
      ...data,
      // Ensure all data values are strings
      ...Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value)]),
      ),
    },
    android: {
      notification: {
        channelId: "zerowaste_channel",
        priority: "high",
        sound: "default",
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
exports.notifyFoodClaimed = onDocumentCreated("claims/{claimId}", async (event) => {
  try {
    const claimData = event.data.data();
    const claimId = event.params.claimId;

    logger.info("New claim created:", claimId, claimData);

    // Get the post details
    const postDoc = await db.collection("posts").doc(claimData.postId).get();
    if (!postDoc.exists) {
      logger.error("Post not found:", claimData.postId);
      return;
    }

    const postData = postDoc.data();

    // Get the poster's user details (creatorId from claim)
    const posterDoc = await db.collection("users").doc(claimData.creatorId).get();
    if (!posterDoc.exists) {
      logger.error("Poster not found:", claimData.creatorId);
      return;
    }

    const posterData = posterDoc.data();

    // Get the claimant's user details
    const claimantDoc = await db.collection("users").doc(claimData.claimerId).get();
    if (!claimantDoc.exists) {
      logger.error("Claimant not found:", claimData.claimerId);
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
            claimantId: claimData.claimerId,
            claimantName: claimantData.name,
          },
      );
    }

    logger.info("Food claimed notification sent successfully");
  } catch (error) {
    logger.error("Error in notifyFoodClaimed:", error);
  }
});

// 2. Notify claimant when their claim is accepted or rejected
exports.notifyClaimUpdate = onDocumentUpdated("claims/{claimId}", async (event) => {
  try {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const claimId = event.params.claimId;

    // Check if status changed
    if (beforeData.status === afterData.status) {
      return; // No status change, no notification needed
    }

    // Only notify for accepted or rejected status
    if (afterData.status !== "accepted" && afterData.status !== "rejected") {
      return;
    }

    logger.info("Claim status updated:", claimId, beforeData.status, "->", afterData.status);

    // Get the post details
    const postDoc = await db.collection("posts").doc(afterData.postId).get();
    if (!postDoc.exists) {
      logger.error("Post not found:", afterData.postId);
      return;
    }

    const postData = postDoc.data();

    // Get the claimant's user details
    const claimantDoc = await db.collection("users").doc(afterData.claimerId).get();
    if (!claimantDoc.exists) {
      logger.error("Claimant not found:", afterData.claimerId);
      return;
    }

    const claimantData = claimantDoc.data();

    // Get the poster's name for context
    const posterDoc = await db.collection("users").doc(afterData.creatorId).get();
    const posterName = posterDoc.exists ? posterDoc.data().name : "Food poster";

    // Send notification to the claimant
    if (claimantData.fcmToken) {
      const isAccepted = afterData.status === "accepted";
      const title = isAccepted ? "Claim Accepted! 🎉" : "Claim Declined 😔";
      const body = isAccepted ?
        `${posterName} accepted your claim for "${postData.title}"!` :
        `${posterName} declined your claim for "${postData.title}".`;

      await sendNotification(
          claimantData.fcmToken,
          title,
          body,
          {
            type: isAccepted ? "claim_accepted" : "claim_rejected",
            postId: afterData.postId,
            claimId: claimId,
            status: afterData.status,
            postTitle: postData.title,
          },
      );
    }

    logger.info("Claim update notification sent successfully");
  } catch (error) {
    logger.error("Error in notifyClaimUpdate:", error);
  }
});

// 3. Notify nearby users when new food is posted
exports.notifyNearbyFood = onDocumentCreated("posts/{postId}", async (event) => {
  try {
    const postData = event.data.data();
    const postId = event.params.postId;

    logger.info("New post created:", postId, postData);

    // Get post location
    const postLat = postData.location.latitude;
    const postLon = postData.location.longitude;

    // Get the poster's details to exclude them from notifications
    const posterDoc = await db.collection("users").doc(postData.postedBy).get();
    if (!posterDoc.exists) {
      logger.error("Poster not found:", postData.postedBy);
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
      if (userId === postData.postedBy) {
        return;
      }

      // Skip users without FCM tokens
      if (!userData.fcmToken) {
        return;
      }

      // Skip users without location
      if (!userData.location || !userData.location.latitude || !userData.location.longitude) {
        return;
      }

      // Calculate distance
      const userLat = userData.location.latitude;
      const userLon = userData.location.longitude;
      const distance = calculateDistance(postLat, postLon, userLat, userLon);

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

    logger.info(`Found ${nearbyUsers.length} nearby users for post ${postId}`);

    // Send notifications to nearby users
    const notificationPromises = nearbyUsers.map(async (user) => {
      try {
        await sendNotification(
            user.fcmToken,
            "New food nearby! 📍",
            `${posterData.name} shared "${postData.title}" ${user.distance}km away`,
            {
              type: "new_food_nearby",
              postId: postId,
              distance: user.distance,
              posterId: postData.postedBy,
              postTitle: postData.title,
            },
        );
      } catch (error) {
        logger.error(`Failed to send notification to user ${user.userId}:`, error);
      }
    });

    await Promise.allSettled(notificationPromises);
    logger.info("Nearby food notifications sent successfully");
  } catch (error) {
    logger.error("Error in notifyNearbyFood:", error);
  }
});

// 4. Notify users when they receive new chat messages - TRIGGER ON MESSAGE DOC CREATE
exports.notifyNewMessage = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  try {
    const {chatId, messageId} = event.params;
    const messageData = event.data.data();

    const senderId = messageData.senderId || messageData.sender || "";
    const messageContent = messageData.content || "";

    // Fetch chat document to get participants & post context
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      logger.error("Chat not found:", chatId);
      return;
    }

    const chatData = chatDoc.data();
    const participants = chatData.participants || [];
    const receiverId = participants.find((id) => id !== senderId);

    if (!receiverId) {
      logger.error("Could not determine receiver for chat:", chatId);
      return;
    }

    // Get sender details
    const senderDoc = await db.collection("users").doc(senderId).get();
    if (!senderDoc.exists) {
      logger.error("Sender not found:", senderId);
      return;
    }
    const senderData = senderDoc.data();

    // Get receiver details
    const receiverDoc = await db.collection("users").doc(receiverId).get();
    if (!receiverDoc.exists) {
      logger.error("Receiver not found:", receiverId);
      return;
    }
    const receiverData = receiverDoc.data();

    // Send notification to the receiver
    if (receiverData.fcmToken) {
      await sendNotification(
          receiverData.fcmToken,
          `New message from ${senderData.name} 💬`,
        messageContent.length > 50 ?
           messageContent.substring(0, 50) + "..." : messageContent,
        {
          type: "new_message",
          chatId: chatId,
          senderId: senderId,
          senderName: senderData.name,
          postId: chatData.postId || "",
          postTitle: chatData.postTitle || "",
          messageId: messageId,
        },
      );
    }

    logger.info("New message notification sent successfully");
  } catch (error) {
    logger.error("Error in notifyNewMessage:", error);
  }
});

// 5. Notify users when they receive a new rating
exports.notifyNewRating = onDocumentCreated("ratings/{ratingId}", async (event) => {
  try {
    const ratingData = event.data.data();
    const ratingId = event.params.ratingId;

    logger.info("New rating created:", ratingId, ratingData);

    // Get the user who gave the rating
    const fromUserDoc = await db.collection("users").doc(ratingData.fromUserId).get();
    if (!fromUserDoc.exists) {
      logger.error("Rating giver not found:", ratingData.fromUserId);
      return;
    }

    const fromUserData = fromUserDoc.data();

    // Get the user who received the rating
    const toUserDoc = await db.collection("users").doc(ratingData.toUserId).get();
    if (!toUserDoc.exists) {
      logger.error("Rating receiver not found:", ratingData.toUserId);
      return;
    }

    const toUserData = toUserDoc.data();

    // Get post details for context
    const postDoc = await db.collection("posts").doc(ratingData.postId).get();
    const postTitle = postDoc.exists ? postDoc.data().title : "a food post";

    // Send notification to the user who received the rating
    if (toUserData.fcmToken) {
      const stars = "⭐".repeat(Math.floor(ratingData.rating));
      const title = "You received a new rating! ⭐";
      const body = ratingData.review ?
        `${fromUserData.name} rated you ${ratingData.rating}/5 ${stars} for "${postTitle}": "${ratingData.review}"` :
        `${fromUserData.name} rated you ${ratingData.rating}/5 ${stars} for "${postTitle}"`;

      await sendNotification(
          toUserData.fcmToken,
          title,
          body,
          {
            type: "new_rating",
            ratingId: ratingId,
            fromUserId: ratingData.fromUserId,
            fromUserName: fromUserData.name,
            rating: ratingData.rating.toString(),
            postId: ratingData.postId,
            postTitle: postTitle,
          },
      );
    }

    logger.info("New rating notification sent successfully");
  } catch (error) {
    logger.error("Error in notifyNewRating:", error);
  }
});

// 6. Test function to verify notifications are working
exports.testNotification = onDocumentCreated("test_notifications/{testId}", async (event) => {
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

// 7. Clean up expired posts (runs when posts are updated)
exports.cleanupExpiredPosts = onDocumentUpdated("posts/{postId}", async (event) => {
  try {
    const postData = event.data.after.data();
    const postId = event.params.postId;

    // Check if post has expired
    const now = new Date();
    const expiry = postData.expiry.toDate();

    if (now > expiry && postData.status === "available") {
      // Update post status to expired (you might want to add this status)
      logger.info(`Post ${postId} has expired, should be cleaned up`);

      // You could update the post status here if you add an "expired" status
      // await db.collection("posts").doc(postId).update({ status: "expired" });
    }
  } catch (error) {
    logger.error("Error in cleanupExpiredPosts:", error);
  }
});
