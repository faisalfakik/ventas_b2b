/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Configuración de runtime
const runtimeOpts = {
  timeoutSeconds: 60,
  memory: '256MB'
};

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

exports.helloWorld = functions.region('us-central1').https.onRequest(async (req, res) => {
  try {
    res.status(200).json({
      message: 'Hello from Firebase!',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Función auxiliar para calcular distancia entre dos puntos
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Radio de la Tierra en metros
  const phi1 = lat1 * Math.PI/180;
  const phi2 = lat2 * Math.PI/180;
  const deltaPhi = (lat2-lat1) * Math.PI/180;
  const deltaLambda = (lon2-lon1) * Math.PI/180;

  const a = Math.sin(deltaPhi/2) * Math.sin(deltaPhi/2) +
          Math.cos(phi1) * Math.cos(phi2) *
          Math.sin(deltaLambda/2) * Math.sin(deltaLambda/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return R * c; // Distancia en metros
}

// Función para enviar notificaciones push
async function sendPushNotification(token, title, body, data = {}) {
  try {
    const message = {
      notification: {
        title,
        body
      },
      data: Object.entries(data).reduce((acc, [key, value]) => {
        acc[key] = String(value);
        return acc;
      }, {}),
      token
    };

    const response = await admin.messaging().send(message);
    console.log('Notificación enviada exitosamente:', response);
    return response;
  } catch (error) {
    console.error('Error al enviar notificación:', error);
    throw error;
  }
}

// Función para manejar nuevas cotizaciones
exports.onNewQuote = functions.region('us-central1').https.onRequest(async (req, res) => {
  try {
    const { quoteData, quoteId } = req.body;

    // Obtener el token del vendedor
    const vendorDoc = await db.collection('users').doc(quoteData.vendorId).get();

    if (!vendorDoc.exists) {
      throw new Error('Vendedor no encontrado');
    }

    const vendorData = vendorDoc.data();
    if (!vendorData.fcmToken) {
      throw new Error('Token FCM no encontrado para el vendedor');
    }

    // Enviar notificación al vendedor
    await sendPushNotification(
      vendorData.fcmToken,
      'Nueva cotización recibida',
      `Has recibido una nueva cotización de ${quoteData.clientName}`,
      {
        type: 'new_quote',
        quoteId: quoteId,
        clientId: quoteData.clientId,
        clientName: quoteData.clientName,
        amount: quoteData.totalAmount.toString(),
        timestamp: new Date().toISOString()
      }
    );

    // Actualizar el estado de la cotización
    await db.collection('quotes').doc(quoteId).update({
      notificationSent: true,
      notificationSentAt: new Date()
    });

    console.log('Notificación de nueva cotización enviada exitosamente');
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error en onNewQuote:', error);
    res.status(500).json({ error: error.message });
  }
});

// Función para manejar pagos recibidos
exports.onPaymentReceived = functions.region('us-central1').https.onRequest(async (req, res) => {
  try {
    const { paymentData, paymentId } = req.body;

    // Obtener el token del vendedor
    const vendorDoc = await db.collection('users').doc(paymentData.vendorId).get();

    if (!vendorDoc.exists) {
      throw new Error('Vendedor no encontrado');
    }

    const vendorData = vendorDoc.data();
    if (!vendorData.fcmToken) {
      throw new Error('Token FCM no encontrado para el vendedor');
    }

    // Enviar notificación al vendedor
    await sendPushNotification(
      vendorData.fcmToken,
      'Pago recibido',
      `Has recibido un pago de ${paymentData.amount} por el pedido ${paymentData.orderId}`,
      {
        type: 'payment_received',
        paymentId: paymentId,
        orderId: paymentData.orderId,
        amount: paymentData.amount.toString(),
        timestamp: new Date().toISOString()
      }
    );

    // Actualizar el estado del pago
    await db.collection('payments').doc(paymentId).update({
      notificationSent: true,
      notificationSentAt: new Date()
    });

    console.log('Notificación de pago recibido enviada exitosamente');
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error en onPaymentReceived:', error);
    res.status(500).json({ error: error.message });
  }
});

// Función para manejar actualizaciones de pedidos
exports.onOrderUpdate = functions.region('us-central1').https.onRequest(async (req, res) => {
  try {
    const { newData, previousData, orderId } = req.body;

    // Solo procesar si el estado ha cambiado
    if (newData.status === previousData.status) {
      return res.status(200).json({ success: true, message: 'No hay cambios en el estado' });
    }

    // Obtener el token del cliente
    const clientDoc = await db.collection('users').doc(newData.clientId).get();

    if (!clientDoc.exists) {
      throw new Error('Cliente no encontrado');
    }

    const clientData = clientDoc.data();
    if (!clientData.fcmToken) {
      throw new Error('Token FCM no encontrado para el cliente');
    }

    // Enviar notificación al cliente
    await sendPushNotification(
      clientData.fcmToken,
      'Actualización de pedido',
      `Tu pedido ${orderId} ha sido actualizado a: ${newData.status}`,
      {
        type: 'order_update',
        orderId: orderId,
        status: newData.status,
        timestamp: new Date().toISOString()
      }
    );

    // Actualizar el estado de la notificación
    await db.collection('orders').doc(orderId).update({
      lastNotificationSent: true,
      lastNotificationSentAt: new Date()
    });

    console.log('Notificación de actualización de pedido enviada exitosamente');
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error en onOrderUpdate:', error);
    res.status(500).json({ error: error.message });
  }
});

// Función para manejar vendedores cercanos
exports.onVendorNearby = functions.region('us-central1').https.onRequest(async (req, res) => {
  try {
    const { newData, previousData, vendorId } = req.body;

    // Solo procesar si la ubicación ha cambiado significativamente
    const distance = calculateDistance(
      previousData.location.latitude,
      previousData.location.longitude,
      newData.location.latitude,
      newData.location.longitude
    );

    // Si la distancia es menor a 100 metros, no procesar
    if (distance < 100) {
      return res.status(200).json({ success: true, message: 'Distancia insuficiente para notificar' });
    }

    // Obtener clientes cercanos
    const clientsSnapshot = await db.collection('client_locations').get();
    const nearbyClients = [];

    for (const doc of clientsSnapshot.docs) {
      const clientData = doc.data();
      const clientDistance = calculateDistance(
        newData.location.latitude,
        newData.location.longitude,
        clientData.location.latitude,
        clientData.location.longitude
      );

      // Si el cliente está a menos de 5 km
      if (clientDistance < 5000) {
        nearbyClients.push({
          clientId: doc.id,
          distance: clientDistance,
          fcmToken: clientData.fcmToken
        });
      }
    }

    // Enviar notificaciones a clientes cercanos
    for (const client of nearbyClients) {
      await sendPushNotification(
        client.fcmToken,
        'Vendedor cercano',
        `Hay un vendedor cerca de ti (${Math.round(client.distance/1000)} km)`,
        {
          type: 'vendor_nearby',
          vendorId: vendorId,
          distance: client.distance.toString(),
          timestamp: new Date().toISOString()
        }
      );
    }

    console.log('Notificaciones de vendedor cercano enviadas exitosamente');
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error en onVendorNearby:', error);
    res.status(500).json({ error: error.message });
  }
});
