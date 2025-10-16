#!/bin/bash

keys_path="/etc/pki/rpm-gpg"

keys=$(ls "$keys_path")

declare -A ALGO_MAP=(
    [1]="RSA"
    [17]="DSA"
    [19]="ECDSA"
)

ls "$keys_path" | while IFS= read -r line; do
  echo "Chave: $line"
  
    # Busca as informaçãoes da chave e com awwk filtra para as informações de interesse
    key_info=$(gpg --show-keys --with-colons "$keys_path/$line" 2>/dev/null | awk -F: '$1 == "pub" {print $3 ":" $4 ":" $6 ":" $7}')
    # Guarda as informações em variaveis separadas
    IFS=':' read -r size_bits algo_id creation_ts expiration_ts <<< "$key_info"

    # Converte os timestamps do Unix para datas legíveis
    creation_date=$(date -d "@$creation_ts" '+%Y-%m-%d')
    if [[ -n "$expiration_ts" ]]; then
        expiration_date=$(date -d "@$expiration_ts" '+%Y-%m-%d')

        # Calcula a vida útil aproximada em dias
        lifespan=$(( (expiration_ts - creation_ts) / 86400 ))
        anos=$(( lifespan / 365 ))
        meses=$(( lifespan % 365 ))
        vida_str="~${anos} anos e ${meses} meses (${lifespan} dias)"
    else
        expiration_date="Não tem"
        vida_str="Indefinido"
    fi

    algo_name=${ALGO_MAP[$algo_id]:-"Desconhecido($algo_id)"}
    echo -e "\tAlgoritimo utilizado: $algo_name -- Tamanho: $size_bits -- Data de criação: $creation_date -- Data de expiração: $expiration_date -- Tempo de vida: $vida_str"
done


#echo "$keys"