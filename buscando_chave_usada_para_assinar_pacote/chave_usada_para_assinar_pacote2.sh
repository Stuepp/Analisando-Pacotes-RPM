#!/bin/bash

# ---
# VERSÃO DE DIAGNÓSTICO:
# 1. Corrige a função 'analisar_pacotes_instalados' para usar 'rpm -qi'.
# 2. Adiciona saídas de DEBUG na função 'analisar_pacotes_locais'.
# ---

declare -gA KEY_INDEX

#
# Função para indexar chaves do banco de dados RPM (sem alterações).
#
indexar_chaves_do_banco_de_dados_rpm() {
    echo "1. Indexando chaves GPG do banco de dados RPM..."
    while read -r key_id_curto summary_info; do
        KEY_INDEX["$key_id_curto"]="$summary_info"
    done < <(rpm -q gpg-pubkey --qf '%{VERSION}\t%{SUMMARY}\n')
    echo "   -> Índice com ${#KEY_INDEX[@]} chaves criado a partir do banco de dados."
}


#
# >>> FUNÇÃO COM DEBUG <<<
# Analisa os pacotes locais e imprime a saída de 'rpm -K' para depuração.
#
analisar_pacotes_locais() {
    echo -e "\n2. Analisando pacotes RPM em: $RPM_DIR"
    
    for pacote in "$RPM_DIR"/*.rpm; do
        echo "-----------------------------------------------"
        echo "Analisando: $(basename "$pacote")"

        local output
        output=$(rpm -K "$pacote" 2>&1)

        # --- INÍCIO DO BLOCO DE DEBUG ---
        echo "--- DEBUG RAW OUTPUT ---"
        echo "$output"
        echo "--- END DEBUG ---"
        # --- FIM DO BLOCO DE DEBUG ---

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
                echo "   -> Chave Encontrada: $arquivo_chave"
            else
                echo "   -> Chave: NÃO ENCONTRADA no banco de dados RPM."
            fi
        fi
        ((files_found_local++))
    done
}


#
# >>> FUNÇÃO CORRIGIDA <<<
# Reimplementada para usar 'rpm -qi | grep', que é mais lento, mas funciona no seu sistema.
#
analisar_pacotes_instalados() {
    echo -e "\n3. Analisando pacotes instalados no sistema (rpm -qa)..."
    echo "(Este processo pode ser lento, por favor aguarde.)"

    local lista_pacotes
    lista_pacotes=$(rpm -qa)
    
    local total_pacotes
    total_pacotes=$(echo "$lista_pacotes" | wc -l)
    
    local pacote_atual=0
    local total_com_chave_encontrada=0
    local total_com_chave_faltante=0
    local total_assinados=0

    while read -r nome_pacote; do
        ((pacote_atual++))
        echo -ne "\033[KAnalisando $pacote_atual de $total_pacotes - $nome_pacote\r"

        local sig_info_line
        sig_info_line=$(rpm -qi "$nome_pacote" 2>/dev/null | grep "Signature")

        if echo "$sig_info_line" | grep -q "(none)" || [[ -z "$sig_info_line" ]]; then
            continue
        fi
        
        ((total_assinados++))
        local key_id_longo
        key_id_longo=$(echo "$sig_info_line" | awk '{print $NF}')
        local key_id_curto=${key_id_longo: -8}
        local info_chave=${KEY_INDEX[$key_id_curto]}

        if [[ -n "$info_chave" ]]; then
            ((total_com_chave_encontrada++))
        else
            ((total_com_chave_faltante++))
        fi
    done <<< "$lista_pacotes"
    
    echo -ne "\033[K" # Limpa a linha de progresso
    echo "-----------------------------------------------"
    echo "   -> Análise de pacotes instalados concluída."
    echo "   -> $total_com_chave_encontrada de $total_assinados pacotes assinados possuem chaves conhecidas."
    if [[ $total_com_chave_faltante -gt 0 ]]; then
        echo "   -> $total_com_chave_faltante pacotes foram assinados por chaves não encontradas no banco de dados."
    fi
}


# =========== PROGRAMA PRINCIPAL =============

RPM_DIR="/home/stuepp/Documents/RPM-TEST-PACKS"
files_found_local=0

echo "Iniciando busca para descobrir a chave usada para assinar pacotes."
echo "=================================================================="

indexar_chaves_do_banco_de_dados_rpm

if [ -d "$RPM_DIR" ]; then
    shopt -s nullglob
    analisar_pacotes_locais
    shopt -u nullglob
else
    echo -e "\n2. Análise de pacotes locais pulada: diretório '$RPM_DIR' não encontrado."
fi

analisar_pacotes_instalados

echo "=================================================================="
if [ "$files_found_local" -gt 0 ]; then
    echo "Verificação de arquivos locais concluída. Total de $files_found_local pacotes analisados."
fi
echo "Script finalizado."