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
    rpm_file=$(echo "$temp_dir/$pacote".rpm)
    
    # Exibir o nome do pacote e seu status
    if [ -f "$rpm_file" ]; then
        # Se o pacote já existir, exibe a versão do RPM
        # --- echo "Pacote '$pacote' já encontrado. Exibindo versão:" ---- #
        file "$rpm_file" | grep -o 'RPM v[0-9.]\+'
    else
        # Pular pacotes que não fazem sentido baixar
        if [[ "$pacote" =~ ^gpg-pubkey ]]; then
            echo "Ignorando pacote especial: $pacote"
            continue
        else
            # Caso contrário, adiciona o pacote à lista para ser baixado
            echo "Pacote '$pacote' não encontrado. Adicionando à lista para download."
            pacotes_para_baixar+=("$pacote")
        fi
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
        if ! dnf list available "$pacote" &>/dev/null; then
                echo "Pacote $pacote não está disponível em nenhum repositório, ignorando."
                continue
        fi
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

# Por alterar a quantidade de pacotes sendo paralelamente baixados para ficar mais raṕido
# creio eu...
# Não conferi após ter feito esse script se há uma solução mais inteligente....
# 2012 pacotes baixados de 2027
# Há pacotes que são na verdade chaves como os gpg, que o sistema lista eles como chaves
# afim de facilitar a própria vida
# outro caso é dos pacotes não mais disponiveis para baixar em repositórios por conta
# de ser "muito" antigo, estar desatualizado.....
# Por que baixar os pacotes já instalados para verificar a versão RPM deles? Pois o comando file só funciona para arquivos, pacotes baixados..
# Não vi outra solução então fui nessa linha mais força bruta mesmo...
# Antes com outra versão do script - que não está nos commits - averiqguei que os pacotes na minha versão Fedora 40, estão todos ou pelo menos sua magadora maioria
# na versão 3, RPM 3.0; - a versão anterior baixava verificava e excluia o pacote, pois eu estava com medo do espaço em disco... -
###############3
# Agora para realizar a contagem das versões dos pacotes basta, após executar esse script
# executar o seguinte comando:
# grep -o 'RPM v[0-9]\.[0-9]' saido_versao_pacotes_instalados.txt | sort | uniq -c
#  que deve resultar numa saída como:
#    2012 RPM v3.0
# O que irá confirmar ou não.. se a há distribuição, sua versão ao menos, está
# realmente tendo todos os pacotes de apenas uma versão do RPM
# mas não há nada que impeça o usuário de instalar pacotes de versões do RPM diferentes
# o que acredito seja algo mais dificil de aconter se o usuário ficar apenas brincando
# em repositórios oficiais..