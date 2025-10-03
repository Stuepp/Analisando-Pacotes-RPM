#!/bin/bash

# --- Variáveis ---

REPO_PATH="/home/stuepp/Documents/ufpr-repo-fedora/*.rpm"

declare -a list_key_ids_used

# --- Funções ---

chave_usada_para_assinar_pacote(){
    for pacote in $REPO_PATH; do
        # Buscando o key id do pacote
        local sig_line=$(rpm -qi "$pacote" | grep Signature)
        local key_id=$(echo "$sig_line" | awk '{print $NF}')
        local short_key_id=${key_id: -8}
        # Pegando a chave usada para assinar o pacote através do key id, com seus últimos 8 digitos
        local key_used=$(rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep "$short_key_id")
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
    done
    echo "Chaves usadas para assinar os pacotes:"
    for k in ${list_key_ids_used}; do
        rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep "$k"
    done
}

# --- Main ---
echo -e "\n"

chave_usada_para_assinar_pacote