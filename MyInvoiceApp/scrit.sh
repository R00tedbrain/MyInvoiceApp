#!/usr/bin/env bash

# Archivo de salida
output_file="output.txt"

# Borrar el contenido previo de output.txt si existe
> "$output_file"

# 1. Generar el árbol de directorios y guardarlo en output.txt
echo "----- Árbol del directorio -----" >> "$output_file"
# Usamos 'tree -A' para mostrar el árbol con caracteres ASCII;
# si no tienes 'tree' instalado, puedes usar 'find' en su lugar.
tree -A >> "$output_file" 2>/dev/null || find . >> "$output_file"
echo "" >> "$output_file"

# 2. Listar el contenido de cada archivo
echo "----- Contenido de los archivos -----" >> "$output_file"
echo "" >> "$output_file"

count=1

# Usamos find con -print0 y un while para manejar correctamente
# nombres de archivos con espacios u otros caracteres especiales.
while IFS= read -r -d '' file; do
  # Mostramos un encabezado con "codigo N" y el nombre del archivo
  echo "codigo $count: ($file)" >> "$output_file"
  # Volcamos el contenido del archivo
  cat "$file" >> "$output_file"
  echo "" >> "$output_file"
  echo "-----" >> "$output_file"
  echo "" >> "$output_file"
  ((count++))
done < <(find . -type f -print0)

echo "El resultado se ha guardado en $output_file"

