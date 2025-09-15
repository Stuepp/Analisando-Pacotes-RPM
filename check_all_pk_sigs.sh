#!/bin/bash
# clear

echo "Iniciando auditoria completa (Modo de Máxima Compatibilidade v2)..."
echo "Este processo será mais lento, por favor aguarde."

# Inicializa os contadores
verifiable=0
unverifiable=0
unsigned=0
current_package=0

# Pega o total de pacotes para a barra de progresso
package_list=$(rpm -qa --qf '%{NAME}\n')
total_packages=$(echo "$package_list" | wc -l)

# Itera sobre cada nome de pacote
while read -r package; do
  # Atualiza e exibe o progresso
  current_package=$((current_package + 1))
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
      # Não contém "Key ID", então a chave está ausente. É não verificável.
      ((unverifiable++))
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
echo "  - Com assinatura verificável: $verifiable"
echo "  - Com assinatura não verificável (chave ausente): $unverifiable"
echo "  - Sem assinatura: $unsigned"

##################33