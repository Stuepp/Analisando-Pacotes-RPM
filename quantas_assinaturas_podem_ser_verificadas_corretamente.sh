#!/bin/bash

# ---
# Script para verificar a assinatura e integridade de todos os pacotes .rpm
# em um diretório especificado.
# Utiliza o comando 'rpm -K' (equivalente a 'rpm --checksig').
# ---

# 1. Defina o caminho para o diretório que contém os pacotes RPM.
#	Altere o valor abaixo para o seu diretório
#	Ex: RPM_DIRECTOY="home/user/Downloads/pactes_rpm"

RPM_DIR="/home/stuepp/Documents/RPM-TEST-PACKS"
#RPM_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 2. Verifica se o diretório especificado realmente exite.

if [ ! -d "$RPM_DIR" ]; then
	echo "Erro: O diretório '$RPM_DIR' não foi encontrado."
	echo "Por favor, edite o script e configure a variável RPM_DIR corretamente."
	exit 1
fi

echo "\nIniciando a verificação de pacotes em: $RPM_DIR"
echo "Inciando a verificação com --checksig"
echo "==============================================="

# 3. 'shopt -s nullglob' faz com que o loop não execute se nenhum arquivo .rpm for econtrado,
#	evitando um erro.

shopt -s nullglob
files_found=0
files_found2=0

# 4. Inicia o loop 'for' para cada arquivo que termina com .rpm no diretório.
for pacote in "$RPM_DIR"/*.rpm; do
	# Imprime o nome do pacote que está sendo verificado para melhor feedback.
	echo "--> Verificando: $(basename "$pacote")"

	# Executa o comando 'rpm -K' no pacote.
	# A opção -v (verbose) pode ser adicionada para mais detalhes: rpm -Kv "$pacote"
	rpm -K "$pacote"
	echo "----------------------------------------------"
	((files_found++))
done

echo "\nInicianod a verificação de pacotes com {SIGPGP}"
echo "=============================================="


# 4.5 Inicia outro loop 'for' para fazer a mesma verificação porém  usando '%{SIGPGP:pgpsig}'
for pacote in "$RPM_DIR"/*.rpm; do
	echo "--> Verificando: $(basename "$pacote")"
	rpm -q --qf '%{SIGPGP:pgpsig}' "$pacote"
	echo "---------------------------------------------"
	((files_found2++))
done


# Restaure o comportamento padrão do glob
shopt -u nullglob

# 5. Informa ao usuário se nenhum pacote foi encontrado.
if [ "$files_found" -eq 0 ]; then
	echo "Nenhum arquivo .rpm encontrado no diretório."
else
	echo "Verificação concluída. TOtal de $files_found pacotes analisados."
fi

exit 0
