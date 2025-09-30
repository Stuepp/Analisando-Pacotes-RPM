#!/bin/bash

# Diretório temporário onde os RPMs baixados serão armazenados
temp_dir="rpm-instalados-baixados-temp"

# Criar o diretório caso não exista
mkdir -p "$temp_dir"

# Lista de pacotes a serem baixados
pacotes_para_baixar=()

# Verificar todos os pacotes instalados
echo "Verificando pacotes instalados..."

# Verifique se o comando rpm -qa está funcionando corretamente
pacotes_instalados=$(rpm -qa)
if [ -z "$pacotes_instalados" ]; then
    echo "Nenhum pacote instalado encontrado. Verifique se o comando rpm -qa está funcionando."
    exit 1
fi

# Iterar sobre os pacotes instalados
for pacote in $pacotes_instalados; do
    echo "Verificando o pacote: $pacote"
    
    # Verificar se o pacote já foi baixado
    rpm_file="$temp_dir/$(ls "$temp_dir" | grep -m 1 -E "^$pacote-[0-9].*\.rpm$")"
    
    # Exibir o nome do pacote e seu status
    if [ -f "$rpm_file" ]; then
        # Se o pacote já existir, exibe a versão do RPM
        # --- echo "Pacote '$pacote' já encontrado. Exibindo versão:" ---- #
        file "$rpm_file" | grep -o 'RPM v[0-9.]\+'
    else
        # Caso contrário, adiciona o pacote à lista para ser baixado
        echo "Pacote '$pacote' não encontrado. Adicionando à lista para download."
        pacotes_para_baixar+=("$pacote")
    fi
done

# Verificar se há pacotes para baixar
if [ ${#pacotes_para_baixar[@]} -gt 0 ]; then
    echo "Iniciando download de pacotes..."

    # Contadores para progresso
    total_pacotes=${#pacotes_para_baixar[@]}
    pacotes_baixados=0

    # Baixar pacotes de forma controlada (no máximo 2 simultâneos)
    for pacote in "${pacotes_para_baixar[@]}"; do
        # Iniciar o download em um subshell
        (
            echo "Baixando o pacote: $pacote"
            dnf download --destdir="$temp_dir" "$pacote"
            
            # Atualizar o contador de pacotes baixados
            ((pacotes_baixados++))

            # Mostrar o progresso
            echo "$pacotes_baixados de $total_pacotes pacotes foram baixados..."

        ) &  # Executa o download em segundo plano

        # Esperar até que o número de downloads em paralelo não ultrapasse 2
        while [ $(jobs -r | wc -l) -ge 2 ]; do
            sleep 0.1  # Aguarda um pouco para não sobrecarregar o sistema
        done
    done

    # Esperar todos os downloads terminarem
    wait

    echo "Todos os pacotes foram baixados."
else
    echo "Nenhum pacote para baixar."
fi

# Após o download, verificar os pacotes baixados
echo "Verificando os pacotes baixados..."

for pacote in "${pacotes_para_baixar[@]}"; do
    rpm_file="$temp_dir/$(ls "$temp_dir" | grep -m 1 -E "^$pacote-[0-9].*\.rpm$")"
    
    if [ -f "$rpm_file" ]; then
        echo "Verificando o pacote: $rpm_file"
        file "$rpm_file" | grep -o 'RPM v[0-9.]\+'
    else
        echo "Falha ao baixar ou encontrar o pacote: $pacote"
    fi
done