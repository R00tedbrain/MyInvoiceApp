#!/usr/bin/env bash

# Archivo de salida
output_file="output.txt"

# Borrar el contenido previo de output.txt si existe
> "$output_file"

# 1. Generar el árbol de directorios excluyendo las carpetas de test y guardarlo en output.txt
echo "----- Árbol del directorio -----" >> "$output_file"
# Se usa 'tree -A -I' para excluir MyInvoiceAppTests y MyInvoiceAppUITests;
# si 'tree' no está instalado, se utiliza 'find' con -prune.
tree -A -I "MyInvoiceAppTests|MyInvoiceAppUITests" >> "$output_file" 2>/dev/null || \
find . \( -path './MyInvoiceAppTests' -o -path './MyInvoiceAppUITests' \) -prune -o -print >> "$output_file"
echo "" >> "$output_file"

# 2. Listar el contenido de los archivos .swift, excluyendo los que se encuentran en las carpetas de test
echo "----- Contenido de los archivos .swift -----" >> "$output_file"
echo "" >> "$output_file"

count=1

# Se buscan archivos .swift y se excluyen los que estén dentro de MyInvoiceAppTests y MyInvoiceAppUITests
while IFS= read -r -d '' file; do
  echo "codigo $count: ($file)" >> "$output_file"
  cat "$file" >> "$output_file"
  echo "" >> "$output_file"
  echo "-----" >> "$output_file"
  echo "" >> "$output_file"
  ((count++))
done < <(find . -type f -name "*.swift" ! -path "./MyInvoiceAppTests/*" ! -path "./MyInvoiceAppUITests/*" -print0)

echo "El resultado se ha guardado en $output_file"

