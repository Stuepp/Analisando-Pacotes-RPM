#!/bin/bash

# Verifica se o rpm está instalado
if ! command -v rpm &>/dev/null; then
    echo "O comando rpm não está instalado neste sistema."
    exit 1
fi

echo "Listando pacotes instalados e suas versões:"
rpm -qa --qf '%{NAME}-%{VERSION}RPM version: %{RPMVERSION}\n'
