# PDF Voice Reader 

Una aplicación móvil desarrollada con **Flutter** que permite cargar archivos PDF, visualizar su contenido y convertir el texto a voz (TTS) de forma eficiente y segmentada.

> **Nota:** Este repositorio contiene únicamente el código fuente de la lógica principal. No se proporciona una versión compilada (.apk o .ipa).

---

## Características Principales

* **Visor de PDF Integrado:** Visualización fluida de documentos mediante el uso de la librería `pdfx`.
* **Lectura TTS Segmentada:** Implementa un sistema de *chunking* (segmentación) de 4000 caracteres para evitar errores de memoria y mejorar la estabilidad del motor de voz.
* **Limpieza Automática de Texto:** Incluye un algoritmo de limpieza agresiva que elimina caracteres especiales no deseados para asegurar una lectura fluida.
* **Control de Lectura:** * Botones de Reproducir/Pausa.
    * Navegación entre segmentos (Avanzar/Retroceder).
    * Botón de detención y reinicio.
* **Personalización:**
    * Soporte multilingüe (Español e Inglés).
    * Ajuste de velocidad de lectura (Speech Rate).
    * Persistencia de ajustes mediante `shared_preferences`.

---

## Tecnologías y Librerías

El proyecto hace uso de las siguientes dependencias clave:

| Librería | Propósito |
| :--- | :--- |
| `flutter_tts` | Motor de síntesis de voz (TTS). |
| `pdfx` | Renderizado y visualización de documentos PDF. |
| `syncfusion_flutter_pdf` | Extracción precisa de texto desde archivos binarios. |
| `file_picker` | Selector de archivos del sistema. |
| `shared_preferences` | Almacenamiento local de preferencias de usuario. |

---

## Estructura del Proyecto

* **`main.dart`**: Punto de entrada que gestiona la selección inicial de archivos y el tema de la aplicación.
* **`pdf_reader.dart`**: El núcleo de la aplicación. Contiene la lógica de extracción de texto, el controlador del visor y la gestión del motor de voz de Google.

---

## Detalles Técnicos de Implementación

Para garantizar que la lectura no se interrumpa en documentos extensos, la aplicación procesa el texto en bloques. El estado de la lectura se visualiza mediante una **barra de progreso** en la parte superior del visor de PDF.

---

Desarrollado usando Flutter.
