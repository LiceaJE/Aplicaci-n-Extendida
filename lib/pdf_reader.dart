import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdfx/pdfx.dart'; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncpdf;

class PDFReader extends StatefulWidget {
  final File pdfFile;
  
  const PDFReader({super.key, required this.pdfFile});

  @override
  State<PDFReader> createState() => _PDFReaderState();
}

class _PDFReaderState extends State<PDFReader> {
  // 1. Controladores y Estados
  late FlutterTts flutterTts;
  late PdfControllerPinch pdfController;

  String ttsStatus = "Cargando PDF y motor de voz...";
  bool isPlaying = false;
  String fullText = ""; 
  bool isExtracting = false; 
  String currentLanguage = "es-ES";
  double speechRate = 0.4;
  
  // --- VARIABLES DE SEGMENTACIÓN (CHUNKING) ---
  int currentTextIndex = 0; // Índice de inicio del chunk actual (punto de lectura)
  // *** CAMBIO CLAVE: Reducir el tamaño del segmento para mayor estabilidad ***
  int chunkSize = 4000;    // Tamaño máximo de cada segmento de texto (antes 10000)
  // ---------------------------------------------

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }
  
  void _initializeAll() async {
    pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.pdfFile.path),
    );
    await _extractTextFromPdf();
    await _initializeTts();
  }
  
  // --- LÓGICA DE EXTRACCIÓN DE TEXTO CON LIMPIEZA ---
  Future<void> _extractTextFromPdf() async {
    if (isExtracting) return;

    setState(() {
      isExtracting = true;
      ttsStatus = "Extrayendo texto, esto puede tardar...";
    });

    try {
      final List<int> bytes = await widget.pdfFile.readAsBytes();
      final syncpdf.PdfDocument document = syncpdf.PdfDocument(inputBytes: bytes);
      final syncpdf.PdfTextExtractor extractor = syncpdf.PdfTextExtractor(document);

      String extractedText = extractor.extractText();
      document.dispose();
      
      // *** LIMPIEZA EXTREMADAMENTE AGRESIVA Y SEGURA ***
      // Deja solo letras, números, espacios, punto y coma.
      String cleanedText = extractedText.replaceAll(RegExp(r'[^a-zA-Z0-9\s\.\,]'), ' ');
      cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      // **********************************

      setState(() {
        fullText = cleanedText;
        isExtracting = false;
        ttsStatus = "Texto extraído y limpiado (${fullText.length} chars). Motor listo. (${currentLanguage})";
        currentTextIndex = 0; 
      });
    } catch (e) {
      setState(() {
        isExtracting = false;
        ttsStatus = "Error al extraer texto del PDF: $e";
      });
    }
  }

  // --- LÓGICA DE VOZ (TTS) ---
  Future<void> _initializeTts() async {
    flutterTts = FlutterTts();
    
    // ** INICIALIZACIÓN DIRECTA Y EN SECUENCIA **

    // 1. Forzar el motor de Google TTS (solución a Samsung TTS y error -8)
    try {
      await flutterTts.setEngine('com.google.android.tts');
      print('Motor de TTS configurado a Google TTS.');
    } catch (e) {
      print('No se pudo configurar Google TTS, usando el motor por defecto. Error: $e');
    }
    
    // 2. Cargar preferencias y aplicar configuración inicial
    final prefs = await SharedPreferences.getInstance();
    currentLanguage = prefs.getString('ttsLanguage') ?? "es-ES"; 
    speechRate = prefs.getDouble('speechRate') ?? 0.4;
    
    await flutterTts.setLanguage(currentLanguage);
    await flutterTts.setSpeechRate(speechRate); 
    await flutterTts.setVolume(1.0); 

    // *************************************************

    flutterTts.setStartHandler(() {
      setState(() {
        isPlaying = true;
      });
    });

    // Handler de finalización: Llama al siguiente segmento
    flutterTts.setCompletionHandler(() {
      currentTextIndex += chunkSize;
      
      if (currentTextIndex < fullText.length) {
        _speakChunk();
      } else {
        setState(() {
          ttsStatus = "Lectura finalizada.";
          isPlaying = false;
          currentTextIndex = 0; 
        });
      }
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        ttsStatus = "Error de TTS: $msg. Detenido.";
        isPlaying = false;
        currentTextIndex = 0;
      });
    });
  }
  
  // --- FUNCIÓN CENTRAL DE SEGMENTACIÓN ---
  Future<void> _speakChunk() async {
    if (currentTextIndex >= fullText.length) {
      setState(() {
        ttsStatus = "Lectura finalizada.";
        isPlaying = false;
        currentTextIndex = 0;
      });
      return;
    }
    
    // El clamp asegura que no intentemos leer más allá del final del texto
    int endIndex = (currentTextIndex + chunkSize).clamp(0, fullText.length);
    String chunk = fullText.substring(currentTextIndex, endIndex);
    
    // Actualizar el estado para el usuario
    setState(() {
        int totalChunks = (fullText.length / chunkSize).ceil();
        int currentChunk = currentTextIndex ~/ chunkSize + 1;
        ttsStatus = "Leyendo segmento $currentChunk / $totalChunks...";
    });
    
    await flutterTts.setLanguage(currentLanguage);
    await flutterTts.setSpeechRate(speechRate); 
    
    await flutterTts.speak(chunk);
  }
  
  // --- DIÁLOGO DE AJUSTES DE VOZ ---
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ajustes de Lectura"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text("Idioma de Lectura:"),
              StatefulBuilder(
                builder: (context, setStateSB) { 
                  return DropdownButton<String>(
                    value: currentLanguage,
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('ttsLanguage', newValue);
                        
                        setState(() {
                          currentLanguage = newValue;
                        });
                        
                        setStateSB(() {}); 
                        await flutterTts.setLanguage(currentLanguage);
                        ttsStatus = "Idioma cambiado a ${newValue == 'es-ES' ? 'Español' : 'Inglés'}.";
                      }
                    },
                    items: <String>['es-ES', 'en-US']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value == 'es-ES' ? 'Español' : 'Inglés'),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text("Velocidad de Lectura:"),
              StatefulBuilder(
                builder: (context, setStateSB) {
                  return Slider(
                    value: speechRate,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: speechRate.toStringAsFixed(1),
                    onChanged: (double newValue) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('speechRate', newValue);

                      setState(() {
                        speechRate = newValue;
                      });
                      setStateSB(() {});
                      await flutterTts.setSpeechRate(speechRate);
                    },
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cerrar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  // --- MÉTODOS DE CONTROL ---

  // NUEVO: Retrocede al inicio del segmento anterior
  Future<void> _rewindTts() async {
    await flutterTts.stop();
    // Retrocede el índice dos veces (uno para el segmento actual, otro para el anterior)
    currentTextIndex = (currentTextIndex - chunkSize * 2).clamp(0, fullText.length);
    
    setState(() {
      isPlaying = false;
      ttsStatus = "Retrocediendo a segmento anterior...";
    });
    // Llama a toggleSpeak para empezar a leer desde el nuevo punto
    _toggleSpeak(); 
  }

  // NUEVO: Avanza al inicio del siguiente segmento
  Future<void> _skipTts() async {
    await flutterTts.stop();
    // Avanza el índice al inicio del siguiente segmento
    currentTextIndex = (currentTextIndex + chunkSize).clamp(0, fullText.length);
    
    setState(() {
      isPlaying = false;
      ttsStatus = "Saltando a segmento siguiente...";
    });
    // Llama a toggleSpeak para empezar a leer desde el nuevo punto
    _toggleSpeak();
  }
  
  Future<void> _stopTts() async {
    await flutterTts.stop();
    setState(() {
      isPlaying = false;
      currentTextIndex = 0; 
      ttsStatus = "Lectura detenida y reiniciada.";
    });
  }

  Future<void> _pauseTts() async {
    await flutterTts.stop(); 
    setState(() {
      isPlaying = false;
      ttsStatus = "Lectura en pausa.";
    });
  }

  Future<void> _toggleSpeak() async {
    if (fullText.isEmpty || isExtracting) {
       setState(() {
        ttsStatus = "Esperando texto extraído...";
      });
      return;
    }
    
    if (isPlaying) {
      _pauseTts(); 
    } else {
      if (currentTextIndex >= fullText.length) {
        currentTextIndex = 0; 
      }
      
      await flutterTts.setLanguage(currentLanguage);
      await flutterTts.setSpeechRate(speechRate); 

      _speakChunk(); 
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    pdfController.dispose();
    super.dispose();
  }

  // --- CONSTRUCCIÓN DE LA INTERFAZ ---
  @override
  Widget build(BuildContext context) {
    if (isExtracting && fullText.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(ttsStatus),
            ],
          ),
        ),
      );
    }

    double progress = fullText.isEmpty ? 0.0 : currentTextIndex / fullText.length;

    return Scaffold(
      appBar: AppBar(
        // Solución de Overflow: Usar el título para el estado.
        title: Text(
          ttsStatus,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.teal,
        actions: const [
          // Acciones vacías para asegurar que el título tenga todo el espacio.
        ],
      ),
      
      body: Stack(
        children: [
          // 1. Visor de PDFx 
          PdfViewPinch(
            controller: pdfController,
          ),
          // 2. Barra de progreso de lectura en la parte superior del PDF
          Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: Colors.lightGreen,
            ),
          ),
        ],
      ),
      
      // Barra de control de lectura
  bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blueGrey.shade800,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // Botón de Detener
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.redAccent, size: 30),
                onPressed: isPlaying ? _stopTts : null,
                tooltip: 'Detener y Reiniciar',
              ),
              
              // Botón de Retroceder 1 segmento (NUEVO)
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white, size: 30),
                onPressed: fullText.isNotEmpty && currentTextIndex > 0 ? _rewindTts : null,
                tooltip: 'Retroceder segmento',
              ),
              
              // Botón de Play / Pause
              FloatingActionButton(
                heroTag: "playPauseButton",
                backgroundColor: isPlaying ? Colors.orange : Colors.lightGreen,
                onPressed: fullText.isNotEmpty && !isExtracting ? _toggleSpeak : null,
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 35, color: Colors.white),
              ),
              
              // Botón de Avanzar 1 segmento (NUEVO)
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white, size: 30),
                onPressed: fullText.isNotEmpty && currentTextIndex < fullText.length ? _skipTts : null,
                tooltip: 'Avanzar segmento',
              ),
              
              // Botón de Ajustes 
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                onPressed: _showSettingsDialog,
                tooltip: 'Ajustes de Voz',
              ),
            ],
          ),
        ),
      ),
    );
  }
}