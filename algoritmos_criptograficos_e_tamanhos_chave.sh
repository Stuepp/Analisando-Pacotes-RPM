#!/bin/bash

# ---
# Script para analisar as chaves GPG do sistema RPM em /etc/pki/rpm-gpg
# e extrair informações sobre algoritmos, tamanhos de chave e datas de expiração.
# ---

# Diretório onde as chaves GPG do RPM são armazenadas
KEY_DIR="/etc/pki/rpm-gpg"

if [ ! -d "$KEY_DIR" ]; then
    echo "Erro: Diretório de chaves GPG não encontrado em '$KEY_DIR'."
    exit 1
fi

# Arrays associativos para armazenar as contagens. Requer Bash 4+.
declare -A algo_counts
declare -A size_counts
expiring_keys_count=0
expiring_keys_details="" # String para armazenar os detalhes das chaves que expiram

# Mapeamento de IDs de algoritmos para nomes legíveis (RFC 4880)
# Public-Key Algorithms
#
#      ID           Algorithm
#      --           ---------
#      1          - RSA (Encrypt or Sign) [HAC]
#      2          - RSA Encrypt-Only [HAC]
#      3          - RSA Sign-Only [HAC]
#      16         - Elgamal (Encrypt-Only) [ELGAMAL] [HAC]
#      17         - DSA (Digital Signature Algorithm) [FIPS186] [HAC]
#      18         - Reserved for Elliptic Curve
#      19         - Reserved for ECDSA
#      20         - Reserved (formerly Elgamal Encrypt or Sign)
#      21         - Reserved for Diffie-Hellman (X9.42,
#                   as defined for IETF-S/MIME)
#      100 to 110 - Private/Experimental algorithm
declare -A ALGO_MAP=(
    [1]="RSA"
    [17]="DSA"
    [19]="ECDSA"
    #[22]="EdDSA"
)

echo "Analisando chaves GPG em: $KEY_DIR..."
echo "================================================="

# Itera sobre todos os arquivos de chave no diretório
for keyfile in "$KEY_DIR"/RPM-GPG-KEY-*; do
    if [ ! -f "$keyfile" ]; then
        continue # Pula se não for um arquivo
    fi

    # Executa o gpg e analisa a saída com 'awk' para extrair os dados da chave pública ('pub')
    # Formato dos campos da linha 'pub':
    # 1:tipo(pub) 3:tamanho 4:id_algoritmo 6:data_criação 7:data_expiração
    key_info=$(gpg --show-keys --with-colons "$keyfile" 2>/dev/null | awk -F: '$1 == "pub" {print $3 ":" $4 ":" $6 ":" $7}')

    # Extrai o nome do dono da chave (uid) para exibição
    uid_info=$(gpg --show-keys --with-colons "$keyfile" 2>/dev/null | awk -F: '$1 == "uid" {print $10; exit}')


    # Se a extração falhou, pula para a próxima chave
    if [[ -z "$key_info" ]]; then
        echo "Aviso: Não foi possível analisar a chave '$keyfile'."
        continue
    fi

    # Separa os campos extraídos em variáveis individuais
    IFS=':' read -r size_bits algo_id creation_ts expiration_ts <<< "$key_info"

    # --- 1. Contabiliza os Algoritmos ---
    algo_name=${ALGO_MAP[$algo_id]:-"Desconhecido($algo_id)"}
    ((algo_counts[$algo_name]++))

    # --- 2. Contabiliza os Tamanhos de Chave ---
    ((size_counts["$size_bits bits"]++))

    # --- 3. Verifica a Expiração ---
    # Se o campo de expiração não estiver vazio, a chave expira.
    if [[ -n "$expiration_ts" ]]; then
        ((expiring_keys_count++))

        # Converte os timestamps do Unix para datas legíveis
        expiration_date=$(date -d "@$expiration_ts" '+%Y-%m-%d')
        creation_date=$(date -d "@$creation_ts" '+%Y-%m-%d')

        # Calcula a vida útil aproximada em dias
        lifespan=$(( (expiration_ts - creation_ts) / 86400 ))

        # Adiciona os detalhes à string de resultados
        expiring_keys_details+="\n- Chave: ${uid_info}\n"
        expiring_keys_details+="  -> Expira em: ${expiration_date} (Vida útil de aprox. ${lifespan} dias)\n"
    fi
done

# --- Exibição do Relatório Final ---

echo -e "\n--- Resumo da Análise ---"

echo -e "\n[ Algoritmos Criptográficos Utilizados ]"
for algo in "${!algo_counts[@]}"; do
    echo "  ${algo}: ${algo_counts[$algo]} chaves"
done

echo -e "\n[ Tamanhos das Chaves ]"
for size in "${!size_counts[@]}"; do
    echo "  ${size}: ${size_counts[$size]} chaves"
done

echo -e "\n[ Chaves com Data de Expiração ]"
echo "  Total de chaves que expiram: $expiring_keys_count"
if [[ $expiring_keys_count -gt 0 ]]; then
    echo -e "${expiring_keys_details}"
fi

echo -e "\nAnálise concluída."