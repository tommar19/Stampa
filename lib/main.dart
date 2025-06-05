import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';

void main() {
  runApp(const SurgeCafeScannerApp());
}

class SurgeCafeScannerApp extends StatelessWidget {
  const SurgeCafeScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scanner',
      theme: ThemeData(
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
          bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Roboto'),
          headlineSmall: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.grey[900],
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white70),
        ),
      ),
      home: const QRScannerScreen(),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool isScanned = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!isScanned) {
      setState(() => isScanned = true);

      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 100, 50, 100]);
      }

      final id = capture.barcodes.first.rawValue;
      if (kDebugMode) print('ID escaneado: $id');

      try {
        final response = await http.post(
          Uri.parse('https://surge-card-backend.vercel.app/api/customers/qr-code-scan'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final stamps = result['stamps'] ?? 0;
          final name = result['name'] ?? 'Desconocido';
          final favoriteDrink = result['favoriteDrink'] ?? 'No especificada';
          final birthdate = result['birthdate'] ?? 'No disponible';
          _showSuccessDialog(stamps, name, favoriteDrink, birthdate);
        } else {
          _showErrorDialog('Error del servidor: ${response.statusCode}');
        }
      } on TimeoutException {
        _showErrorDialog('Tiempo de espera agotado.');
      } catch (error) {
        _showErrorDialog('Error: $error');
      }
    }
  }

  void _showSuccessDialog(int stamps, String name, String favoriteDrink, String birthdate) {
    // Estado siempre "Activo" con ícono check_circle
    String status = 'Activo';
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.black.withOpacity(0.9), // Fondo oscuro como en la app
        contentPadding: const EdgeInsets.all(16), // Espaciado interno
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección superior: Icono y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icono del cliente
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800], // Fondo gris oscuro para el ícono
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                // Estado siempre "Activo"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2), // Fondo suave del estado
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(color: statusColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Espacio vertical como en React
            
            // Información del cliente
            Text(
              name,
              style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Text(
              '$stamps de 8',
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            
            // Barra de progreso para los sellos con porcentaje a la derecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progreso',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  '${(stamps / 8 * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: stamps / 8, // Progreso basado en sellos
              backgroundColor: Colors.grey[800],
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 14),
            
            // Bebida favorita
            Row(
              children: [
                const Icon(Icons.coffee, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Bebida Favorita: $favoriteDrink',
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Cumpleaños
            Row(
              children: [
                const Icon(Icons.cake, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Cumpleaños: $birthdate',
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
        actions: [
          // Botón OK centrado
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // Color destacado como en la app
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isScanned = false;
                  controller.start();
                });
              },
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.redAccent, size: 50),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                isScanned = false;
                controller.start();
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 10),
                      Text(
                        'QR Scanner',
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                              fontSize: 28,
                            ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: FadeTransition(
                    opacity: _pulseAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Apunta al QR del cliente',
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}