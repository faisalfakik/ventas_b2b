import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../models/payment_model.dart';

class EmailService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Enviar recibo por correo usando método simplificado
  Future<bool> sendReceiptEmail({
    required String clientEmail,
    required String adminEmail,
    String? vendorEmail,
    required String subject,
    required String body,
    required String attachmentPath,
  }) async {
    try {
      // Usar flutter_email_sender
      final Email email = Email(
        body: body,
        subject: subject,
        recipients: [clientEmail],
        cc: [adminEmail],
        bcc: vendorEmail != null && vendorEmail.isNotEmpty ? [vendorEmail] : [],
        attachmentPaths: [attachmentPath],
        isHTML: body.contains('<html>'), // Detectar si es HTML
      );

      await FlutterEmailSender.send(email);
      return true;
    } catch (e) {
      debugPrint('Error al enviar correo: $e');
      return false;
    }
  }

  // Alternativa usando Firebase Cloud Functions (requiere implementar la función en Firebase)
  Future<bool> _sendEmailWithCloudFunction({
    required Payment payment,
    required String clientEmail,
    required String adminEmail,
    required String vendorEmail,
    required String receiptUrl,
    required String subject,
    required String body,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('sendReceiptEmail');
      final result = await callable.call({
        'paymentId': payment.id,
        'clientEmail': clientEmail,
        'adminEmail': adminEmail,
        'vendorEmail': vendorEmail,
        'subject': subject,
        'body': body,
        'receiptUrl': receiptUrl,
        'amount': payment.amount,
        'date': payment.date.toIso8601String(),
        'clientName': payment.clientId, // Cambiado por seguridad
      });

      return result.data['success'] ?? false;
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return false;
    }
  }

  // Generar el contenido HTML del correo para el recibo
  String generateReceiptEmailBody(Payment payment, String clientName, String vendorName) {
    return '''
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 20px; }
        .details { margin-bottom: 30px; }
        .details table { width: 100%; border-collapse: collapse; }
        .details th, .details td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        .footer { margin-top: 30px; text-align: center; font-size: 12px; color: #777; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h2>Recibo de Pago</h2>
          <p>Comprobante de pago #${payment.id.substring(0, 8)}</p>
        </div>
        
        <div class="details">
          <table>
            <tr>
              <th>Cliente:</th>
              <td>${clientName}</td>
            </tr>
            <tr>
              <th>Fecha:</th>
              <td>${payment.date.day}/${payment.date.month}/${payment.date.year}</td>
            </tr>
            <tr>
              <th>Monto:</th>
              <td>\$${payment.amount.toStringAsFixed(2)}</td>
            </tr>
            <tr>
              <th>Método de pago:</th>
              <td>${_getMethodName(payment.method)}</td>
            </tr>
            <tr>
              <th>Atendido por:</th>
              <td>${vendorName}</td>
            </tr>
          </table>
        </div>
        
        <p>Gracias por su pago. Se adjunta el recibo en formato PDF para su referencia.</p>
        
        <div class="footer">
          <p>Este es un correo automático, por favor no responder a este mensaje.</p>
        </div>
      </div>
    </body>
    </html>
    ''';
  }

  // Método auxiliar para obtener el nombre del método de pago
  String _getMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.transfer:
        return 'Transferencia/Depósito';
      case PaymentMethod.check:
        return 'Cheque';
      default:
        return 'Otro';
    }
  }
}