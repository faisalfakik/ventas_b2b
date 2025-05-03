#!/bin/bash
# Script para asegurar que el enlace simbólico del APK siempre está en su lugar

# Cambiar al directorio del proyecto
cd "$(dirname "$0")"

# Compilar con Gradle directamente
cd android
./gradlew assembleDebug
cd ..

# Verificar si el APK se generó correctamente
if [ -f "android/app/build/outputs/apk/debug/app-debug.apk" ]; then
  echo "✅ APK generado correctamente por Gradle"
  
  # Crear directorio destino si no existe
  mkdir -p build/app/outputs/flutter-apk/
  
  # Eliminar enlace anterior si existe
  rm -f build/app/outputs/flutter-apk/app-debug.apk
  
  # Crear enlace simbólico
  ln -s "$(pwd)/android/app/build/outputs/apk/debug/app-debug.apk" "$(pwd)/build/app/outputs/flutter-apk/app-debug.apk"
  echo "✅ Enlace simbólico creado correctamente"
  
  # Verificar que el enlace se creó correctamente
  if [ -L "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo "✅ Todo listo para compilar con Flutter"
  else
    echo "❌ Error al crear el enlace simbólico"
  fi
else
  echo "❌ Error: No se encontró el APK generado por Gradle"
fi 