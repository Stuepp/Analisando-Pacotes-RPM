#!/bin/bash
# clear

echo "Iniciando auditoria completa (Modo de Máxima Compatibilidade v2)..."
echo "Este processo será mais lento, por favor aguarde."

# Inicializa os contadores
verifiable=0
checksig_verifiable=0
unverifiable=0
unsigned=0
current_package=0

# Pega o total de pacotes para a barra de progresso
package_list=$(rpm -qa --qf '%{NAME}\n')
total_packages=$(echo "$package_list" | wc -l)

# Itera sobre cada nome de pacote
while read -r package; do
  # Atualiza e exibe o progresso
  ((current_package++))
  echo -ne "Analisando: $current_package de $total_packages - $package \r"

  # Pega as informações do pacote UMA VEZ para otimizar
  package_info=$(rpm -qi "$package")

  # PASSO 1: O pacote tem uma assinatura REAL?
  # Usamos `grep -v` para excluir a linha "Signature: (none)" e `grep` para
  # encontrar qualquer outra linha "Signature".
  if echo "$package_info" | grep -q '^Signature' && ! echo "$package_info" | grep -q -x 'Signature   : (none)'; then
    # Se sim, ele é assinado. Agora, vamos diferenciar entre verificável ou não.

    # PASSO 2: A verificação da assinatura com a chave presente funciona?
    sig_check_output=$(rpm -q --qf '%{SIGPGP:pgpsig}' "$package")
    if [[ "$sig_check_output" == *"Key ID"* ]]; then
      # Contém "Key ID", então a chave está no chaveiro. É verificável.
      ((verifiable++))
    else
      sig_check_output=$(rpm --checksig "$package")
      if [[ "$sig_check_output" ==  *"NOT OK"* ]]; then
        # Não contém "Key ID", então a chave está ausente. É não verificável.
        ((unverifiable++))
      else
        ((checksig_verifiable++))
      fi
    fi
  else
    # Se a linha Signature não existe ou é exatamente "(none)",
    # então o pacote é genuinamente não assinado.
    ((unsigned++))
  fi
done <<< "$package_list" # Alimenta a lista de pacotes para o loop

# Limpa a linha de progresso
echo -e "\n"

# Imprime o resultado final
echo "---"
echo "Resultado da Auditoria de Assinaturas:"
echo "Total de pacotes: $total_packages"
echo "  - Com assinatura verificável ({SIGPGP:pgpsig}): $verifiable"
echo "  - Com assinatura verificável (--checksig): $checksig_verifiable"
echo "  - Com assinatura não verificável (chave ausente): $unverifiable"
echo "  - Sem assinatura: $unsigned"

##################

echo "Contando pacotes (BAIXADOS) assinados e não assinados..."

DIR_REPO="/home/stuepp/Documents/ufpr-repo-fedora"

# Verifica se o diretório existe
if [ ! -d "$DIR_REPO" ]; then
  echo "Erro: O diretório '$DIR_REPO' não foi encontrado."
  exit 1
fi

# Verifica se existem arquivos .rpm no diretório
# O 'shopt -s nullglob' e 'shopt -u nullglob' evitam erros se não houver arquivos .rpm
shopt -s nullglob
pacotes_rpm=("$DIR_REPO"/*.rpm)
shopt -u nullglob

# A tag %{SIGPGP} (sem o :pgpsig no final) é perfeita para isso.
# Ela simplesmente verifica se o cabeçalho de assinatura PGP existe.

# %{SIGNER}. Esta tag busca a informação de quem assinou o pacote.
# Para pacotes não assinados, ela retornará (none).
# Para pacotes assinados (mesmo que a chave seja desconhecida),
# ela deve retornar a informação da chave. -> tag muito recente, não funciona com pacotes antigos...

if [ ${#pacotes_rpm[@]} -eq 0 ]; then
  echo "Nenhum arquivo .rpm encontrado em $DIR_REPO"
  exit 0
fi

signed=0
unsigned=0
total=0

 for pacote in "${pacotes_rpm[@]}"; do
  info=$(rpm -qip "$pacote")

  if echo "$info" | grep -q '^Signature\s*: \(none)\'; then
    unsigned=$((unsigned+1))
  else
    signed=$((signed+1))
  fi
  total=$((total+1))
 done

 echo "##################################################"
echo "### RESUMO DA CONTAGEM ###"
echo "##################################################"
echo ""
echo "Total de pacotes analisados: " $total
echo "Total de pacotes assinados: " $signed
echo "Total de pacotes não assinados: " $unsigned


# tive que usar sem o awk, pois estava contando eles como não assiandos
# usando as tag GPGPGP, GPGGPG, SIGNER
# acredito estar relacionado com os warning