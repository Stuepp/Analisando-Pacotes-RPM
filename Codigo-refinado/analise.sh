#!/bin/bash

# --- Variáveis ---

REPO_PATH="/home/stuepp/Documents/ufpr-repo-fedora/*.rpm"

RPM_KEYS_DIR="/etc/pki/rpm-gpg"

declare -a list_key_ids_used

declare -A ALGO_MAP=(
    [1]="RSA"
    [17]="DSA"
    [19]="ECDSA"
)

# --- Funções ---

chave_usada_para_assinar_pacote(){
    for pacote in $REPO_PATH; do
        # Buscando o key id do pacote
        local sig_line=$(rpm -qi "$pacote" | grep Signature)
        # Passa para o próximo pacote caso o atual não esteja assinado
        if echo "$sig_line" | grep -q "(none)" || [[ -z "$sig_line" ]]; then
            continue
        fi

        local key_id=$(echo "$sig_line" | awk '{print $NF}')
        local short_key_id=${key_id: -8}
        # Pegando a chave usada para assinar o pacote através do key id, com seus últimos 8 digitos
        local key_used=$(rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep "$short_key_id")
        # Confere se a chave utilizada faz parte das chaves listadas pelo sistema...
        if [[ -n "$key_used" ]]; then
            # Confere se a lista é vazia ou não
            if (( ${#list_key_ids_used[@]} )); then
                # como a lista não está vazia deve verificar se a nova chave encontrada
                # é diferente das chaves já registradas
                for k in ${list_key_ids_used}; do
                    if [ "${k}" != "$key_used" ]; then 
                        list_key_ids_used+=($key_used)
                    fi
                done
            else # caso vazia
                list_key_ids_used+=($key_used)
        fi
        else
            # Caso seja uma chave não listada, adicionar unknown - desconhecida
            list_key_ids_used+=("desconhecida")
        fi
        
    done
    echo "Chaves usadas para assinar os pacotes:"
    for k in ${list_key_ids_used}; do
        rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep "$k"
    done
}

algoritmos_criptograficos_usados_e_tamanhos_de_chave(){
    # Para o Fedora apenas nos interessa a chave de sua versão atual
    # Pois apenas ela é efetivamente usada

    # Para mudar a analise e verificar todas as chaves do fedora, basta alterar para ser um for do dir
    # Isso faz com que se possa ver o histórico das chaves e sua evolução / mudanças

    echo "\t Chave do dir /etc/pki/rpm-gpg"

    local fedora_in_use_key=$(ls "$RPM_KEYS_DIR" | head -1)
    # Expoẽ qual chave está sendo analizada
    echo "Chave sendo verificada: $fedora_in_use_key"
    # Busca as informaçãoes da chave e com awwk filtra para as informações de interesse
    local key_info=$(gpg --show-keys --with-colons "$RPM_KEYS_DIR/$fedora_in_use_key" 2>/dev/null | awk -F: '$1 == "pub" {print $3 ":" $4 ":" $6 ":" $7}')
    # Guarda as informações em variaveis separadas
    local size_bits algo_id creation_ts expiration_ts
    IFS=':' read -r size_bits algo_id creation_ts expiration_ts <<< "$key_info"

    # Converte os timestamps do Unix para datas legíveis
    local creation_date=$(date -d "@$creation_ts" '+%Y-%m-%d')
    local expiration_date
    local lifespan
    if [[ -n "$expiration_ts" ]]; then
        expiration_date=$(date -d "@$expiration_ts" '+%Y-%m-%d')

        # Calcula a vida útil aproximada em dias
        lifespan=$(( (expiration_ts - creation_ts) / 86400 ))
    else
        expiration_date="Não tem"
        lifespan="Indefinido"
    fi

    

    local algo_name=${ALGO_MAP[$algo_id]:-"Desconhecido($algo_id)"}
    echo "Algoritimo utilizado: $algo_name -- Tamanho: $size_bits -- Data de criação: $creation_date -- Data de expiração: $expiration_date -- Tempo de vida: $lifespan"

    echo
    echo "\t Verificandoa agora chaves utilizadas pelos pacotes"
    for k in ${list_key_ids_used}; do
        echo "Chave sendo verificada:"
        rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep "$k"
        rpm -qi "$k" | gpg
        # Falta conferir data de expiração e tempo de vida, mesmo que na prática (no caso do Fedora) seja a mesma chave
    done
}

# --- Main ---
echo 
echo "Conferindo as chaves usadas para assinar pacotes:"

chave_usada_para_assinar_pacote

echo 
echo "Conferindo algoritmos criptográficos usados e tamanhos de chave utilizados:"

algoritmos_criptograficos_usados_e_tamanhos_de_chave