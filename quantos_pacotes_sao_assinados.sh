#!/bin/bash

# ---
# Script para verificar a assinatura e integridade de todos os pacotes .rpm
# em um diretório especificado.
# Utiliza o comando 'rpm -K' (equivalente a 'rpm --checksig').
# ---


# funções

conta_pacotes_teste() {
    for pacote in "$RPM_DIR"/*.rpm; do
	    local saida=$(rpm -qi "$pacote" | grep "Signature")
        if [[ "$saida" == *"(none)"* ]]; then
            ((pacotes_n_assinados++))
        else
            ((pacotes_assinados++))
        fi
	    ((files_found++))
    done
}

conta_pacotes_instalados() {
    local lista_pacotes
    lista_pacotes=$(rpm -qa --qf '%{NAME}\n')
    local total_pacotes
    total_pacotes=$(echo "$lista_pacotes" | wc -l)

    local pacote_atual=0

    # Itera sobre o nome de cada pacote
    while read -r pacote2; do
        # Atualiza e exibe o progresso
        ((pacote_atual++))
        echo -ne "Analisando $pacote_atual de $total_pacotes - $pacote2 \r"

        # Pega as informações do pacote
        local saida=$(rpm -qi "$pacote2" | grep "Signature")
        if [[ "$saida" == *"(none)"* ]]; then
            ((instalados_n_assinados++))
        else
            ((instalados_assinados++))
        fi

    done <<< "$lista_pacotes" # Alimenta a lista de pacotes para o loop
}

# rpm -Kv
verifica_condicao_do_pacote() {
    for pacote in "$RPM_DIR"/.*rpm; do
        local saida=$(rpm -Kv "$pacote")
    done
}


# =========== PARA OS PACOTES DE TESTE PRIMEIRO =============

# 1. Defina o caminho para o diretório que contém os pacotes RPM.
#	Altere o valor abaixo para o seu diretório
#	Ex: RPM_DIRECTOY="home/user/Downloads/pactes_rpm"

RPM_DIR="/home/stuepp/Documents/RPM-TEST-PACKS"

# Contadores das metricas de assinatura dos pacotes
pacotes_assinados=0
pacotes_n_assinados=0
assinatura_verificavel=0
assinatura_n_verificavel=0
# P/ pacotes instalados
instalados_assinados=0
instalados_n_assinados=0

# 2. Verifica se o diretório especificado realmente exite.

if [ ! -d "$RPM_DIR" ]; then
	echo "Erro: O diretório '$RPM_DIR' não foi encontrado."
	echo "Por favor, edite o script e configure a variável RPM_DIR corretamente."
	exit 1
fi

echo "Iniciando a contagem de assinaturas dos pacotes em: $RPM_DIR"
echo "==============================================="

# 3. 'shopt -s nullglob' faz com que o loop não execute se nenhum arquivo .rpm for econtrado,
#	evitando um erro.

shopt -s nullglob
files_found=0

# 4. Inicia o loop 'for' para cada arquivo que termina com .rpm no diretório.

conta_pacotes_teste

# 4.5 Faz a contagem dos pacotes assinados ou não, que estão instalados no sistema (rpm -qa)
conta_pacotes_instalados

# Restaure o comportamento padrão do glob
shopt -u nullglob

# 5. Informa ao usuário se nenhum pacote foi encontrado.
if [ "$files_found" -eq 0 ]; then
	echo "Nenhum arquivo .rpm encontrado no diretório."
else
	echo "Verificação concluída. Total de $files_found pacotes analisados."
    echo "Total de pacotes assinados: $pacotes_assinados."
    echo "Total de pacotes não assinados $pacotes_n_assinados"
    echo "=============================="
fi

echo -e "\n"
echo "Para pacotes INSTALADOS"
echo "Total de pacotes assinados: $instalados_assinados"
echo "Total de pacotes não assinados: $instalados_n_assinados"

exit 0


