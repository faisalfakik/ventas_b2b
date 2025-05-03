#!/bin/bash
# Script para sincronizar la ubicación del APK entre Gradle y Flutter

# Cambiar al directorio del script
cd "$(dirname "$0")"

# Compilar con Gradle
cd android
./gradlew assembleDebug
cd ..

# Crear directorio destino si no existe
mkdir -p build/app/outputs/flutter-apk/

# Eliminar enlace anterior si existe
rm -f build/app/outputs/flutter-apk/app-debug.apk

# Crear enlace simbólico
ln -s "$(pwd)/android/app/build/outputs/apk/debug/app-debug.apk" "$(pwd)/build/app/outputs/flutter-apk/app-debug.apk"

echo "APK vinculado correctamente. Ahora puedes ejecutar 'flutter build apk --debug'" 