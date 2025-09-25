#!/bin/bash

# Garante que o script pare se algum comando falhar
#set -e

# Itera sobre cada linha da saída do comando 'rpm -qa'
# O uso de 'while read -r' é mais seguro para nomes de pacotes com espaços ou caracteres especiais.
rpm -qa | sort | while read -r package; do
    
    echo "========================================================================"
    echo "PROCESSANDO PACOTE ORIGINAL: $package"
    echo "------------------------------------------------------------------------"

    # Executa 'rpm -qi' no pacote e procura pela linha "Source RPM"
    # grep: Filtra a linha que começa com "Source RPM"
    # awk -F ':' '{print $2}': Divide a linha pelo ':' e pega a segunda parte (o nome do arquivo)
    # xargs: Remove espaços em branco no início e no fim do nome do arquivo
    source_rpm=$(rpm -qi "$package" | grep '^Source RPM' | awk -F ':' '{print $2}' | xargs)

    # Verifica se a variável 'source_rpm' não está vazia
    if [ -n "$source_rpm" ]; then
        echo "Source RPM encontrado: $source_rpm"
        echo "Buscando informações do Source RPM..."
        echo ""

        # Executa 'rpm -qi' no Source RPM encontrado para obter a saída final
        rpm -qi "$source_rpm"

    else
        echo "Nenhum Source RPM foi encontrado para o pacote $package."
    fi

    # Adiciona uma linha em branco para separar as entradas
    echo "" 

done

echo "========================================================================"
echo "Script concluído."