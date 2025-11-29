import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart' as barcode;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../models/factura.dart';
import '../models/pago.dart';
import '../services/connectivity_service.dart';

/// Bill Generator Service
/// 
/// Generates PDF invoices with concurrent processing using Flutter Isolates.
/// Implements local caching and Firebase Storage sync.
/// 
/// University Requirements Implemented:
/// - **Concurrency**: Uses Flutter Isolate (compute) for background PDF generation
/// - **Local Storage**: Saves PDFs to /bills/ directory
/// - **Caching**: LRU cache with max 100 entries for PDF paths
/// - **Eventual Connectivity**: Uploads PDFs to Firebase Storage when online
class BillGeneratorService {
  // Singleton pattern
  static final BillGeneratorService _instance = BillGeneratorService._internal();
  factory BillGeneratorService() => _instance;
  BillGeneratorService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // LRU Cache for PDF paths (MAX 100 ENTRIES - CACHING REQUIREMENT)
  final _lruCache = <String, String>{};
  static const int _maxCacheSize = 100;
  final _cacheAccessOrder = <String>[]; // Track access order for LRU

  String? _billsDirectory;
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Create bills directory (LOCAL STORAGE REQUIREMENT)
      final appDocDir = await getApplicationDocumentsDirectory();
      _billsDirectory = '${appDocDir.path}/bills';
      
      final billsDir = Directory(_billsDirectory!);
      if (!await billsDir.exists()) {
        await billsDir.create(recursive: true);
        debugPrint('📁 Created bills directory: $_billsDirectory');
      }

      _isInitialized = true;
      debugPrint('📄 BillGeneratorService: Initialized');
    } catch (e) {
      debugPrint('❌ BillGeneratorService: Init failed: $e');
      rethrow;
    }
  }

  /// Generate bill PDF for payment
  /// 
  /// Parameters:
  /// - payment: Payment object
  /// - orderDetails: Order details including medicines, pharmacy, user info
  /// 
  /// Returns: Map with success status and file paths
  Future<Map<String, dynamic>> generateBill({
    required Pago payment,
    required Map<String, dynamic> orderDetails,
  }) async {
    try {
      if (!_isInitialized) await init();

      debugPrint('📄 Generating bill for payment: ${payment.id}');

      // Check LRU cache first (CACHING REQUIREMENT)
      final cachedPath = _getCachedPath(payment.id);
      if (cachedPath != null && await File(cachedPath).exists()) {
        debugPrint('✅ Bill found in cache: $cachedPath');
        return {
          'success': true,
          'localPath': cachedPath,
          'fromCache': true,
        };
      }

      // Generate PDF in isolate (CONCURRENCY REQUIREMENT)
      final localPath = await _generatePdfInIsolate(payment, orderDetails);

      // Cache the path (LRU)
      _addToCache(payment.id, localPath);

      // Create factura metadata
      final factura = await _createFacturaMetadata(payment, orderDetails, localPath);

      // Try to upload to Firebase Storage if online
      final isOnline = await _connectivity.checkConnectivity();
      if (isOnline) {
        await _uploadToFirebase(factura, localPath);
      } else {
        debugPrint('📴 Offline: Bill will sync later');
      }

      debugPrint('✅ Bill generated: $localPath');

      return {
        'success': true,
        'localPath': localPath,
        'facturaId': factura.id,
        'fromCache': false,
      };
    } catch (e) {
      debugPrint('❌ Bill generation failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Generate PDF in isolate for concurrent processing (CONCURRENCY REQUIREMENT)
  Future<String> _generatePdfInIsolate(
    Pago payment,
    Map<String, dynamic> orderDetails,
  ) async {
    // Use Flutter's compute for isolate-based processing
    final result = await compute(
      _generatePdfWorker,
      {
        'payment': json.encode({
          'id': payment.id,
          'userId': payment.userId,
          'prescriptionId': payment.prescriptionId,
          'pharmacyId': payment.pharmacyId,
          'orderId': payment.orderId,
          'total': payment.total,
          'method': payment.method,
          'prices': payment.prices,
          'deliveryFee': payment.deliveryFee,
          'transactionDate': payment.transactionDate.millisecondsSinceEpoch,
          'status': payment.status,
        }),
        'orderDetails': orderDetails,
        'billsDirectory': _billsDirectory!,
      },
    );

    return result['filePath'] as String;
  }

  /// Isolate worker function for PDF generation
  static Future<Map<String, dynamic>> _generatePdfWorker(
    Map<String, dynamic> params,
  ) async {
    final paymentJson = params['payment'] as String;
    final orderDetails = params['orderDetails'] as Map<String, dynamic>;
    final billsDirectory = params['billsDirectory'] as String;

    final payment = Pago.fromJson(paymentJson);
    final fileName = 'bill_${payment.id}.pdf';
    final filePath = '$billsDirectory/$fileName';

    // Create PDF document
    final pdf = pw.Document();

    // Generate QR code data
    final qrData = _generateQrData(payment, orderDetails);

    // Add page with bill content
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with QR code
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FACTURA',
                          style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'MyMeds - Sistema de Gestión de Medicamentos',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    // QR Code
                    pw.Container(
                      width: 80,
                      height: 80,
                      color: PdfColors.white,
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.BarcodeWidget(
                        data: qrData,
                        barcode: barcode.Barcode.qrCode(),
                        drawText: false,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // QR Code explanation
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Icon(
                      const pw.IconData(0xe15f), // info icon
                      size: 16,
                      color: PdfColors.blue700,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'Escanea el código QR para verificar esta transacción',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Invoice info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Factura #: ${payment.orderId}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Fecha: ${_formatDate(payment.transactionDate)}'),
                      pw.Text('Método de pago: ${_formatPaymentMethod(payment.method)}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // User info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CLIENTE',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 8),
                    pw.Text('Nombre: ${orderDetails['userName'] ?? 'N/A'}'),
                    pw.Text('Email: ${orderDetails['userEmail'] ?? 'N/A'}'),
                    pw.Text('Teléfono: ${orderDetails['phoneNumber'] ?? 'N/A'}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Pharmacy info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FARMACIA',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 8),
                    pw.Text('Nombre: ${orderDetails['pharmacyName'] ?? 'N/A'}'),
                    pw.Text('Dirección: ${orderDetails['pharmacyAddress'] ?? 'N/A'}'),
                    pw.Text('Teléfono: ${orderDetails['pharmacyPhone'] ?? 'N/A'}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Medicines table
              pw.Text('MEDICAMENTOS',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 12),
              _buildMedicinesTable(orderDetails['items'] as List<dynamic>),
              pw.SizedBox(height: 20),

              // Totals
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    _buildTotalRow('Subtotal:', orderDetails['subtotal'] ?? 0.0),
                    _buildTotalRow('Envío:', orderDetails['deliveryFee'] ?? 0.0),
                    pw.Divider(),
                    _buildTotalRow(
                      'TOTAL:',
                      payment.total,
                      bold: true,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Gracias por su compra',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Para cualquier consulta, contáctenos a soporte@mymeds.com',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to file
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return {
      'filePath': filePath,
      'fileSize': await file.length(),
      'pageCount': pdf.document.pdfPageList.pages.length,
    };
  }

  /// Build medicines table
  static pw.Widget _buildMedicinesTable(List<dynamic> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Medicamento', isHeader: true),
            _buildTableCell('Cantidad', isHeader: true),
            _buildTableCell('Precio Unit.', isHeader: true),
            _buildTableCell('Subtotal', isHeader: true),
          ],
        ),
        // Data rows
        ...items.map((item) {
          return pw.TableRow(
            children: [
              _buildTableCell(item['medicationName'] ?? 'N/A'),
              _buildTableCell('${item['quantity'] ?? 0}'),
              _buildTableCell('\$${(item['pricePerUnit'] ?? 0).toStringAsFixed(2)}'),
              _buildTableCell('\$${(item['subtotal'] ?? 0).toStringAsFixed(2)}'),
            ],
          );
        }),
      ],
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 10,
        ),
      ),
    );
  }

  /// Build total row
  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool bold = false,
    double fontSize = 12,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
        pw.Text(
          '\$${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  /// Format date
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Format payment method
  static String _formatPaymentMethod(String method) {
    switch (method) {
      case 'credit':
        return 'Tarjeta de Crédito';
      case 'debit':
        return 'Tarjeta de Débito';
      case 'cash_on_delivery':
        return 'Pago Contra Entrega';
      case 'mock':
        return 'Pago de Prueba';
      default:
        return method;
    }
  }

  /// Generate QR code data with transaction information
  static String _generateQrData(Pago payment, Map<String, dynamic> orderDetails) {
    final qrInfo = {
      'orderId': payment.orderId,
      'paymentId': payment.id,
      'total': payment.total,
      'date': payment.transactionDate.toIso8601String(),
      'pharmacyId': payment.pharmacyId,
      'method': payment.method,
      'status': payment.status,
      'verificationUrl': 'https://mymeds.com/verify/${payment.orderId}',
    };
    return json.encode(qrInfo);
  }

  /// Create factura metadata
  Future<Factura> _createFacturaMetadata(
    Pago payment,
    Map<String, dynamic> orderDetails,
    String localPath,
  ) async {
    final file = File(localPath);
    final fileSize = await file.length();

    final now = DateTime.now();
    final facturaId = 'FACT_${payment.orderId}';

    return Factura(
      id: facturaId,
      invoiceNumber: payment.orderId,
      localPdfPath: localPath,
      pdfUrl: null, // Will be set after upload
      storageRef: null, // Will be set after upload
      orderSnapshot: orderDetails,
      status: 'generated',
      syncedToCloud: false,
      retryCount: 0,
      createdAt: now,
      updatedAt: now,
      syncedAt: null,
      userId: payment.userId,
      orderId: payment.orderId,
      pageCount: 1, // Would be set by PDF generation
      fileSize: fileSize,
      generatedAt: now.millisecondsSinceEpoch,
      metadata: {
        'generator': 'BillGeneratorService',
        'version': '1.0',
      },
      errorMessage: null,
      userEmail: orderDetails['userEmail'],
      userName: orderDetails['userName'],
    );
  }

  /// Upload to Firebase Storage and sync metadata (EVENTUAL CONNECTIVITY)
  Future<void> _uploadToFirebase(Factura factura, String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('PDF file not found: $localPath');
      }

      // Upload to Firebase Storage: invoices/{userId}/bill_{orderId}.pdf
      final fileName = 'bill_${factura.orderId}.pdf';
      final storageRef = _storage.ref().child('invoices/${factura.userId}/$fileName');

      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      debugPrint('☁️ PDF uploaded to Firebase Storage: $downloadUrl');

      // Update factura with cloud info
      final updatedFactura = factura.copyWith(
        pdfUrl: downloadUrl,
        storageRef: storageRef.fullPath,
        status: 'uploaded',
        syncedToCloud: true,
        syncedAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now(),
      );

      // Save metadata to Firestore: usuarios/{userId}/facturas/{facturaId}
      await _firestore
          .collection('usuarios')
          .doc(factura.userId)
          .collection('facturas')
          .doc(factura.id)
          .set(updatedFactura.toMap());

      debugPrint('🔥 Factura metadata synced to Firestore: ${factura.id}');
    } catch (e) {
      debugPrint('❌ Firebase upload failed: $e');
      // Save failed status to Firestore
      final failedFactura = factura.copyWith(
        status: 'failed',
        errorMessage: e.toString(),
        retryCount: factura.retryCount + 1,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('usuarios')
          .doc(factura.userId)
          .collection('facturas')
          .doc(factura.id)
          .set(failedFactura.toMap());
    }
  }

  /// Get cached PDF path (LRU CACHE)
  String? _getCachedPath(String paymentId) {
    if (_lruCache.containsKey(paymentId)) {
      // Move to end (most recently used)
      _cacheAccessOrder.remove(paymentId);
      _cacheAccessOrder.add(paymentId);
      return _lruCache[paymentId];
    }
    return null;
  }

  /// Add to LRU cache (MAX 100 ENTRIES)
  void _addToCache(String paymentId, String filePath) {
    // If cache is full, remove least recently used
    if (_lruCache.length >= _maxCacheSize) {
      final lruKey = _cacheAccessOrder.removeAt(0);
      _lruCache.remove(lruKey);
      debugPrint('🗑️ Removed LRU cache entry: $lruKey');
    }

    _lruCache[paymentId] = filePath;
    _cacheAccessOrder.add(paymentId);
    debugPrint('💾 Added to LRU cache: $paymentId (size: ${_lruCache.length}/$_maxCacheSize)');
  }

  /// Open bill PDF
  Future<void> openBill(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open PDF: ${result.message}');
      }
      debugPrint('📄 Opened PDF: $filePath');
    } catch (e) {
      debugPrint('❌ Failed to open PDF: $e');
      rethrow;
    }
  }

  /// Share bill PDF
  Future<void> shareBill(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('PDF file not found');
      }

      await Share.shareXFiles([XFile(filePath)], text: 'Factura MyMeds');
      debugPrint('📤 Shared PDF: $filePath');
    } catch (e) {
      debugPrint('❌ Failed to share PDF: $e');
      rethrow;
    }
  }

  /// Get cache size
  int getCacheSize() => _lruCache.length;

  /// Clear cache
  void clearCache() {
    _lruCache.clear();
    _cacheAccessOrder.clear();
    debugPrint('🗑️ Cache cleared');
  }

  /// Get bill by payment ID from Firestore (uses LRU cache)
  Future<Factura?> getBillByPaymentId(String paymentId, String userId) async {
    try {
      // Check cache first (LRU CACHE REQUIREMENT)
      final cachedPath = _getCachedPath(paymentId);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          debugPrint('💾 Bill found in LRU cache: $paymentId');
          // Return a minimal Factura object for cached bills
          return Factura(
            id: 'bill_$paymentId',
            invoiceNumber: paymentId,
            localPdfPath: cachedPath,
            orderSnapshot: {},
            status: 'cached',
            syncedToCloud: false,
            retryCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            userId: userId,
            orderId: paymentId,
            pageCount: 1,
            fileSize: await file.length(),
            generatedAt: DateTime.now().millisecondsSinceEpoch,
            metadata: {'source': 'lru_cache'},
          );
        }
      }

      // Query Firestore for bill metadata
      final querySnapshot = await _firestore
          .collection('usuarios')
          .doc(userId)
          .collection('facturas')
          .where('orderId', isEqualTo: paymentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('⚠️ No bill found in Firestore for payment: $paymentId');
        return null;
      }

      final doc = querySnapshot.docs.first;
      final factura = Factura.fromMap(doc.data(), documentId: doc.id);
      
      // Check if local file exists and add to cache
      if (factura.localPdfPath.isNotEmpty) {
        final file = File(factura.localPdfPath);
        if (await file.exists()) {
          _addToCache(paymentId, factura.localPdfPath);
          debugPrint('💾 Added bill to LRU cache: $paymentId');
        }
      }

      return factura;
    } catch (e) {
      debugPrint('❌ Error getting bill by payment ID: $e');
      return null;
    }
  }
}
