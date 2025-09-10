#!/bin/bash

# Script para extrair informações de TODOS os pacotes RPM instalados e salvá-las em um arquivo CSV.
#
# Uso: ./rpm-all-to-csv.sh
#
# O script irá consultar todos os pacotes com 'rpm -qa' e processá-los um a um.
# O resultado será salvo em um arquivo chamado 'rpm_all_info.csv'.

# Define o nome do arquivo de saída
OUTPUT_FILE="rpm_all_info.csv"

echo "Iniciando a extração de dados de todos os pacotes RPM instalados..."
echo "Isso pode levar alguns minutos, dependendo da quantidade de pacotes."

# Define o cabeçalho do CSV com as colunas solicitadas
HEADERS="Name,Version,Release,Architecture,Install Date,Group,Size,License,Signature,Source RPM,Build Date,Build Host,Packager,Vendor,URL,Summary,Description"

# Escreve o cabeçalho no arquivo, sobrescrevendo o conteúdo anterior
echo "$HEADERS" > "$OUTPUT_FILE"

# Obtém a lista de todos os pacotes instalados
ALL_PACKAGES=$(rpm -qa)
TOTAL_PACKAGES=$(echo "$ALL_PACKAGES" | wc -l)
CURRENT_PACKAGE=0

# Itera sobre cada nome de pacote retornado por 'rpm -qa'
for pkg_name in $ALL_PACKAGES; do
    # Atualiza o contador e exibe o progresso
    CURRENT_PACKAGE=$((CURRENT_PACKAGE + 1))
    echo "Processando [$CURRENT_PACKAGE/$TOTAL_PACKAGES]: $pkg_name"

    # Executa 'rpm -qi' e canaliza a saída para o awk para processamento
    # O resultado é uma única linha CSV, que é adicionada ao arquivo de saída
    rpm -qi "$pkg_name" | awk -v headers="$HEADERS" '
    # Função para formatar uma célula CSV, colocando entre aspas e escapando aspas internas.
    function csv_quote(value) {
        gsub(/"/, "\"\"", value);
        return "\"" value "\"";
    }

    # Bloco BEGIN, executado antes de processar qualquer linha do pacote atual
    BEGIN {
        # Inicializa um array para armazenar as informações do pacote
        delete info;
        in_description = 0;
    }

    # Bloco principal, executado para cada linha da entrada
    {
        # Verifica se é uma linha chave-valor (contém um ":")
        if (match($0, / *:/)) {
            in_description = 0; # Sai do modo de descrição se estivermos nele

            # Extrai a chave e o valor
            key = substr($0, 1, RSTART - 1);
            value = substr($0, RSTART + RLENGTH);

            # Remove espaços em branco no início/fim
            gsub(/^ *| *$/, "", key);
            gsub(/^ *| *$/, "", value);

            # Se a chave for "Description", ativa o modo de captura de descrição
            if (key == "Description") {
                in_description = 1;
            } else {
                # Armazena o par chave-valor em um array associativo
                info[key] = value;
            }
        } else if (in_description) {
            # Se estivermos no modo de descrição, anexa a linha inteira (preservando a formatação)
            # ao valor da descrição, separando por quebras de linha.
            info["Description"] = info["Description"] (info["Description"] ? "\n" : "") $0;
        }
    }

    # Bloco END, executado após todas as linhas de um pacote serem processadas
    END {
        # Divide o cabeçalho em um array para garantir a ordem correta das colunas
        split(headers, ordered_keys, ",");
        
        line = "";
        # Itera sobre as chaves na ordem correta
        for (i = 1; i <= length(ordered_keys); i++) {
            key = ordered_keys[i];
            # Constrói a linha CSV, formatando cada célula
            # Usa um valor vazio se a chave não for encontrada para o pacote (ex: "Bug URL")
            line = line (i > 1 ? "," : "") csv_quote(info[key]);
        }
        # Imprime a linha CSV completa para o pacote atual
        print line;
    }
    ' >> "$OUTPUT_FILE" # Anexa a linha processada ao arquivo CSV
done

echo "" # Adiciona uma linha em branco para separar a saída
echo "Processo concluído!"
echo "As informações de todos os $TOTAL_PACKAGES pacotes foram salvas em '$OUTPUT_FILE'."
