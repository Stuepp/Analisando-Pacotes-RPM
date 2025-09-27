#!/bin/bash

# URL base do repositório
BASE_URL="https://fedora.c3sl.ufpr.br/linux/releases/42/Everything/x86_64/os/Packages/"

# --- LINHA MODIFICADA ---
# Diretório local onde os pacotes serão salvos
DEST_DIR="/home/stuepp/Documents/ufpr-repo-fedora"

# Cria o diretório de destino se ele não existir
# A opção -p garante que ele crie o caminho completo se necessário (ex: Documents)
mkdir -p "$DEST_DIR"

echo "Iniciando o download dos pacotes RPM..."
echo "URL Base: $BASE_URL"
echo "Salvando em: $DEST_DIR"
echo "========================================================================"

# 1. Obter a lista de subdiretórios (0/, 2/, a/, b/, etc.)
SUBDIRS=$(curl -sL "${BASE_URL}" | grep -oP 'href="[0-9a-z]/"' | sed 's/href="//;s/"//')

# Verifica se algum diretório foi encontrado
if [ -z "$SUBDIRS" ]; then
    echo "Erro: Nenhum subdiretório encontrado na URL base. Verifique a URL e sua conexão."
    exit 1
fi

# 2. Iterar sobre cada subdiretório
for DIR in $SUBDIRS; do
    
    DIR_URL="${BASE_URL}${DIR}"
    echo ">> Acessando o diretório: ${DIR_URL}"

    # 3. Obter a lista de arquivos .rpm dentro do subdiretório
    RPM_FILES=$(curl -sL "${DIR_URL}" | grep -oP 'href=".*\.rpm"' | sed 's/href="//;s/"//')

    if [ -z "$RPM_FILES" ]; then
        echo "   Nenhum arquivo .rpm encontrado neste diretório."
        continue
    fi

    # 4. Baixar cada arquivo .rpm
    for RPM in $RPM_FILES; do
        RPM_URL="${DIR_URL}${RPM}"
        echo "   Baixando: ${RPM}"
        
        wget -P "$DEST_DIR" -nc -q "${RPM_URL}"
        if [ $? -eq 0 ]; then
            echo "   ... Concluído."
        else
            echo "   ... Falha ao baixar ${RPM}."
        fi
    done
done

echo "========================================================================"
echo "Script concluído! Os pacotes foram salvos em '${DEST_DIR}'."