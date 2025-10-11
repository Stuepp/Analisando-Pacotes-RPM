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

declare -a package_versions

declare -a alg_hash_e_tamanhos_usados

# --- Funções ---

chave_usada_para_assinar_pacote(){
    local TOTAL_DE_PACOTES_ASSINADOS=0

    for pacote in $REPO_PATH; do
        # Buscando o key id do pacote
        local sig_line=$(rpm -qi "$pacote" | grep Signature)
        
        # Para não repetir o for com grep Signatura, pegar o alg de hash já aqui
        local alg_hash_e_tamanho=$(echo "$sig_line" | grep -oE 'SHA[0-9]+')

        if (( ${#alg_hash_e_tamanhos_usados[@]} )); then
            for hash_tam in "${alg_hash_e_tamanhos_usados[@]}"; do
                local dif=0
                if [[ "$alg_hash_e_tamanho" == "$hash_tam" ]]; then
                    dif=1
                    break
                    #alg_hash_e_tamanhos_usados+=("$alg_hash_e_tamanho")
                fi
            done
            if [[ $dif -eq 0 ]]; then
                alg_hash_e_tamanhos_usados+=("$alg_hash_e_tamanho")
            fi
        else
            alg_hash_e_tamanhos_usados+=($alg_hash_e_tamanho)
        fi
        
        # Passa para o próximo pacote caso o atual não esteja assinado
        if echo "$sig_line" | grep -q "(none)" || [[ -z "$sig_line" ]]; then
            continue
        fi

        ((TOTAL_DE_PACOTES_ASSINADOS++))

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

    echo
    echo "Total de pacotes assinados: $TOTAL_DE_PACOTES_ASSINADOS"
    local total_de_pacotes=$(ls $REPO_PATH | wc -l)
    local nao_assinados=$(($total_de_pacotes-$TOTAL_DE_PACOTES_ASSINADOS))
    echo "Total de pacotes não assinados: $nao_assinados"
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
    echo "\t Verificando agora chaves utilizadas pelos pacotes"
    for k in ${list_key_ids_used}; do
        echo "Chave sendo verificada:"
        rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep "$k"
        echo
        local build_date=$(rpm -qi $k | grep "Build Date")
        echo "$build_date"
        echo
        rpm -qi "$k" | gpg
        # para chaves intaladas precisa-se buscar a chave de verdade (aqui se está olhando um pacote da chave) para poder extrair se tiver
        # data de expiração, e assim calcular tempo de vida
    done

    echo
    echo " Algoritmo de hash e tamanho utilizados"
    for pv in "${alg_hash_e_tamanhos_usados[@]}"; do
        echo "$pv"
    done
}

verifica_versao_RPM_do_pacote(){
    local -a pacotes_com_erro=()

    local total_de_pacote=$(ls $REPO_PATH | wc -l)
    echo "total_de_pacote= $total_de_pacote"
    local n_pacotes=0
    local start_time=$(date +%s)

    for pacote in $REPO_PATH; do
        ((n_pacotes++))
        local versao=$(file "$pacote" | grep -o 'RPM v[0-9.]\+')
        #echo "Pacote: $(basename "$pacote") -- Versão RPM: $versao"
        #echo "$versao"
        if [[ -z "$versao" ]]; then
            pacotes_com_erro+=("$pacote")
            continue
        fi


        if (( ${#package_versions[@]} )); then
            for position in "${!package_versions[@]}"; do
                IFS=',' read -r ver contador <<< "${package_versions[position]}"
                if [[ "$ver" != "$versao" ]]; then
                    local tuple="$versao,1"
                    package_versions+=("$tuple")
                else
                    ((contador++))
                    local tuple="$versao,$contador"
                    package_versions[position]="$tuple"
                fi
            done
        else
            local tuple="$versao,1"
            package_versions+=("$tuple")
            #echo "added ${package_versions[-1]}"
        fi
        #

        # Barra de progresso
        local now=$(date +%s)
        local elapsed=$((now - start_time))

        # Evita a divisão por zero e resultados vazios
        if (( n_pacotes > 0 )); then
            local avg_time_per_file=$(echo "scale=4; $elapsed / $n_pacotes" | bc)
        else
            local avg_time_per_file=0
        fi

        local est_total_time=$(echo "scale=4; $avg_time_per_file * $total_de_pacote" | bc)
        local est_remaining=$(echo "$est_total_time - $elapsed" | bc)

        # se o bc retornar vazio ou negativo, força para 0
        if [[ -z "$set_remaining" || $(echo "$est_remaining < 0" | bc) -eq 1 ]]; then
            est_remaining=0
        fi

        # Garante que temos um valor inteiro válido
        local est_remaining_int=${est_remaining%.*}
        [[ -z "$est_remaining_int" ]] && est_remaining_int=0

        # cálculo da porcentagem
        if (( total_de_pacote > 0 )); then
            local percent=$(echo "scale=2; ($n_pacotes / $total_de_pacote) * 100" | bc)
        else
            local percent=0
        fi

        # cálculo da barra
        local filled=$(( (bar_lenght * n_pacotes) / total_de_pacote ))
        local empty=$((bar_length - filled))
        local progress_bar
        progress_bar=$(printf "%0.s#" $(seq 1 $filled))
        progress_bar=$(printf "%0.s#-" $(seq 1 $empty))

        # Formata o tempo restante (horas:min:seg)
        local hours=$((est_remaining_int / 3600))
        local minute=$(( (est_remaining_int % 3600) / 60 ))
        local seconds=$(( est_remaining_int % 60 ))

        # Exibe a barra de progresso
        printf "\r[%s] %s%% | %d/%d | Tempo restante: %0d:%02d:%02d" \
            "$progress_bar" "$percent" "$n_pacotes" "$total_de_pacote" \
            "$hours" "$minute" "$seconds"

        #
    
    done

    echo "Versões de pacotes enontradas:"
    for pv in "${package_versions[@]}"; do
        IFS=',' read -r -a tuple_elements <<< "$pv"
        echo "${tuple_elements[0]}; quantidade:${tuple_elements[1]}"
    done

    # Exibe os pacotes/arquivos problemáticos
    if (( ${#pacotes_com_erro[@]} )); then
        echo -e "\n -------"
        echo "Pacotes problemáticos encontrados: ${#pacotes_com_erro[@]}"
        echo "------"
        for arq in "${pacotes_com_erro[@]}"; do
            echo "$arq"
        done
    else
        echo -e "\nNenhum pacote problemático encontrado"
    fi
}

# --- Main ---
echo 
echo "Conferindo as chaves usadas para assinar pacotes:"

chave_usada_para_assinar_pacote

echo "-----------------------------------"
echo "Conferindo algoritmos criptográficos usados e tamanhos de chave utilizados:"

algoritmos_criptograficos_usados_e_tamanhos_de_chave

echo "-----------------------------------"
echo "Verificando versão RPM dos pacotes:"
verifica_versao_RPM_do_pacote