const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Triggers when a new document is created in the 'promo_notifications' collection.
 * Sends a push notification to all devices subscribed to the 'promo_notifications' topic.
 */
exports.sendPromoNotification = functions.firestore
  .document('promo_notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    
    // Check if notification is active
    if (data.isActive === false) {
      console.log('Notification is inactive, skipping push.');
      return null;
    }

    const title = data.title || 'New Announcement';
    const body = data.body || 'Open the app to see the latest updates!';
    
    // Construct the notification payload
    const payload = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        promoId: context.params.notificationId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: data.type || 'announcement'
      },
      topic: 'promo_notifications'
    };

    // Add image if available
    if (data.imageUrl) {
      payload.notification.image = data.imageUrl;
      payload.data.imageUrl = data.imageUrl;
    }

    try {
      const response = await admin.messaging().send(payload);
      console.log('Successfully sent message:', response);
      return { success: true, response: response };
    } catch (error) {
      console.error('Error sending message:', error);
      return { success: false, error: error };
    }
  });
