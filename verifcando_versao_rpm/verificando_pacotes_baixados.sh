#!/bin/bash
# verificar_rpms.sh
# Script para verificar pacotes RPM de teste

# Funlções
analisar_pacotes_locais(){
    for pacote in "$RPM_DIR/*.rpm"; do
        echo "----------------------------------------"
        local saida=$(file $pacote | awk -F: '{ match($2, /RPM v[0-9.]+/, a); print $1 ": " a[0] }')
        echo "$saida"
        echo
    done
}

#####

RPM_DIR="/home/stuepp/Documents/RPM-TEST-PACKS"

echo "Iniciando busca para descobrir a versão dos pacotes baixados em $RPM_DIR."
echo "=================================================================="


if [ -d "$RPM_DIR" ]; then
    shopt -s nullglob
    analisar_pacotes_locais
    shopt -u nullglob
else
    echo -e "\n2. Análise de pacotes locais pulada: diretório '$RPM_DIR' não encontrado."
fi
