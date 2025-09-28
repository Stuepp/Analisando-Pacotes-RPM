#!/bin/bash

# ---
# Script para descobrir qual chave GPG local (em /etc/pki/rpm-gpg) foi usada
# para assinar um pacote RPM, tanto para arquivos .rpm locais quanto para
# pacotes já instalados no sistema.
# ---

# Requer Bash 4+ para arrays associativos.
declare -gA KEY_INDEX

#
# Função para ler todas as chaves em /etc/pki/rpm-gpg e criar um índice
# que mapeia o ID curto da chave (8 caracteres) ao nome do arquivo.
#
indexar_chaves_locais() {
    echo "1. Indexando chaves GPG locais..."
    local key_dir="/etc/pki/rpm-gpg"

    for f in "$key_dir"/RPM-GPG-KEY-*; do
        local key_id_longo
        key_id_longo=$(gpg --with-colons --import-options show-only --import "$f" 2>/dev/null | awk -F: '$1 == "pub" {print $5}')

        # --- LINHA CORRIGIDA ABAIXO ---
        # Removido o 'a' e adicionado o 'then' que faltava.
        if [[ -n "$key_id_longo" ]]; then
            local key_id_curto=${key_id_longo: -8}
            KEY_INDEX["$key_id_curto"]="$f"
        fi
    done
    echo "   -> Índice com ${#KEY_INDEX[@]} chaves criado."
}


#
# Função para analisar os pacotes RPM em um diretório de teste.
#
analisar_pacotes_locais() {
    echo -e "\n2. Analisando pacotes RPM em: $RPM_DIR"
    
    for pacote in "$RPM_DIR"/*.rpm; do
        echo "-----------------------------------------------"
        echo "Analisando: $(basename "$pacote")"

        local output
        output=$(rpm -K "$pacote" 2>&1)

        local key_id_pacote
        key_id_pacote=$(echo "$output" | grep -oP 'key ID \K[0-9a-fA-F]+')

        if [[ -z "$key_id_pacote" ]]; then
            if echo "$output" | grep -q "digests signatures OK"; then
                echo "   -> Status: Assinatura OK (chave já está no sistema)."
            elif echo "$output" | grep -q "(none)"; then
                 echo "   -> Status: Pacote não assinado."
            else
                 echo "   -> Status: Não foi possível determinar a assinatura."
            fi
        else
            local arquivo_chave=${KEY_INDEX[$key_id_pacote]}
            echo "   -> Key ID encontrado: $key_id_pacote"
            if [[ -n "$arquivo_chave" ]]; then
                echo "   -> Arquivo da chave: $(basename "$arquivo_chave")"
            else
                echo "   -> Arquivo da chave: NÃO ENCONTRADO no sistema (/etc/pki/rpm-gpg)."
            fi
        fi
        ((files_found_local++))
    done
}


#
# Função para analisar os pacotes instalados via 'rpm -qa'.
#
analisar_pacotes_instalados() {
    echo -e "\n3. Analisando pacotes instalados no sistema (rpm -qa)..."
    echo "(Este processo pode ser lento, por favor aguarde.)"

    local lista_pacotes
    lista_pacotes=$(rpm -qa)
    
    local total_pacotes
    total_pacotes=$(echo "$lista_pacotes" | wc -l)
    
    local pacote_atual=0
    local total_analisados=0

    while read -r nome_pacote; do
        ((pacote_atual++))
        echo -ne "\033[KAnalisando $pacote_atual de $total_pacotes - $nome_pacote\r"

        # Executa 'rpm -qi' para o pacote atual e filtra a linha da assinatura
        local sig_info_line
        sig_info_line=$(rpm -qi "$nome_pacote" 2>/dev/null | grep "Signature")

        # Se a linha da assinatura contiver "(none)", pula para o próximo
        if echo "$sig_info_line" | grep -q "(none)"; then
            continue
        fi
        
        # Se a linha estiver vazia (pacote sem linha de assinatura), pula
        if [[ -z "$sig_info_line" ]]; then
            continue
        fi

        # Extrai o último campo da linha, que é o ID longo da chave
        local key_id_longo
        key_id_longo=$(echo "$sig_info_line" | awk '{print $NF}')
        
        # Pega os últimos 8 caracteres para obter o ID curto
        local key_id_curto=${key_id_longo: -8}
        
        local arquivo_chave=${KEY_INDEX[$key_id_curto]}

        # Se o arquivo da chave não foi encontrado no nosso índice, exibe a informação
        if [[ -z "$arquivo_chave" ]]; then
            # Limpa a linha de progresso antes de imprimir o resultado
            echo -ne "\033[K"
            echo "-----------------------------------------------"
            echo "Pacote: $nome_pacote"
            echo "   -> Key ID encontrado: $key_id_curto"
            echo "   -> Arquivo da chave: NÃO ENCONTRADO no sistema (/etc/pki/rpm-gpg)."
            ((total_analisados++))
        fi
    done <<< "$lista_pacotes"
    
    # Limpa a linha final de progresso
    echo -ne "\033[K"
    echo "-----------------------------------------------"
    echo "   -> Análise de pacotes instalados concluída."
    if [[ $total_analisados -gt 0 ]]; then
        echo "   -> Total de $total_analisados pacotes com chaves não encontradas em um total de $total_pacotes pacotes."
    else
        echo "   -> Todas as chaves dos pacotes assinados foram encontradas no sistema."
    fi
}


# =========== PROGRAMA PRINCIPAL =============

RPM_DIR="/home/stuepp/Documents/RPM-TEST-PACKS"
files_found_local=0

echo "Iniciando busca para descobrir a chave usada para assinar pacotes."
echo "=================================================================="

# Passo 1: Criar o índice de chaves. Essencial para as duas análises.
indexar_chaves_locais

# Passo 2: Analisar os pacotes no diretório local.
if [ -d "$RPM_DIR" ]; then
    shopt -s nullglob
    analisar_pacotes_locais
    shopt -u nullglob
else
    echo -e "\n2. Análise de pacotes locais pulada: diretório '$RPM_DIR' não encontrado."
fi

# Passo 3: Analisar os pacotes instalados no sistema.
analisar_pacotes_instalados

echo "=================================================================="
if [ "$files_found_local" -gt 0 ]; then
    echo "Verificação de arquivos locais concluída. Total de $files_found_local pacotes analisados."
fi
echo "Script finalizado."