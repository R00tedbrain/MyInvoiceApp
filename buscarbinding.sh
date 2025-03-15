#!/usr/bin/env bash

# Guardar este contenido en un archivo, por ejemplo: "buscar_bindings.sh"
# Luego darle permisos de ejecución:  chmod +x buscar_bindings.sh
# Y finalmente ejecutarlo:  ./buscar_bindings.sh

echo "==== Buscando posibles usos erróneos de Binding en ficheros .swift ===="

# Explicación:
# -r: busca recursivamente
# -n: muestra el número de línea
# -w: fuerza coincidencia de palabra (aprox.)
# -E: interpreta la expresión regular extendida
# --include='*.swift': solo busca en ficheros .swift
# . : ruta actual

grep -rEnw --include='*.swift' \
    -e '\$budgets' \
    -e '\$bdg' \
    -e 'Binding<Budget' \
    -e 'Binding<\[Budget' \
    -e 'BudgetsView\(' \
    .

echo "==== Fin de la búsqueda ===="

