import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// Importamos el widget de la siguiente pantalla que crearemos
import 'pdf_reader.dart';

void main() {
  // Asegura que Flutter esté inicializado antes de ejecutar la app
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfVoiceReaderApp());
}

class PdfVoiceReaderApp extends StatelessWidget {
  const PdfVoiceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lector PDF a Voz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Usamos la fuente Inter para un look moderno
        // Nota: Flutter usa la fuente predeterminada del sistema si no se configura explícitamente Inter.
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: const FileSelectionScreen(),
    );
  }
}

// --- PANTALLA DE SELECCIÓN DE ARCHIVOS ---
class FileSelectionScreen extends StatefulWidget {
  const FileSelectionScreen({super.key});

  @override
  State<FileSelectionScreen> createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends State<FileSelectionScreen> {

  // Función para abrir el selector de archivos del sistema
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // Solo permite seleccionar archivos PDF
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      // El usuario seleccionó un archivo
      PlatformFile platformFile = result.files.first;
      
      // Aseguramos que el path existe
      if (platformFile.path != null) {
        File file = File(platformFile.path!);

        // Navegamos a la siguiente pantalla (PDFReader)
        // Pasamos el archivo (File) seleccionado como argumento
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReader(pdfFile: file),
          ),
        );
      }
    } else {
      // El usuario canceló la selección
      // Puedes mostrar un snackbar si quieres
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona un PDF'),
        elevation: 4,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Icono grande para la selección
            Icon(
              Icons.picture_as_pdf,
              size: 80,
              color: Colors.redAccent,
            ),
            SizedBox(height: 20),
            Text(
              'Abre el lector pulsando el botón de abajo',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            Text(
              'Funciona en Linux, Android e iOS',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      // Botón Flotante para iniciar la selección
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickFile,
        label: const Text('Abrir PDF'),
        icon: const Icon(Icons.folder_open),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}