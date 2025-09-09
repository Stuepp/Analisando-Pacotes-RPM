#!/bin/sh
# a linha acima declara o bin que executará o script

clear
# a linha acima executa um comando shell que limpa a tela

rpm -qa > rpm_packs_list.txt
#packs=$(rpm -qa)
# lista todos os pacotes instalados no sistema

packs="./rpm_packs_list.txt"

num_packs=0
non_sig=0
yes_sig=0

while IFS= read -r line; do
   ## take some action on $line
  #rpm -qi "$line"
  #rpm -qi "$line" | grep Signature | grep none
  if rpm -qi "$line" | grep Signature | grep none; then
    yes_sig=$((yes_sig+1))
  else
    #non_sig=$(expr $non_sig + 1)
    non_sig=$((non_sig+1))
  fi
  #num_packs=$(expr $num_packs + 1)
  num_packs=$((num_packs+1))
done < $packs

echo "Total de pacotes: $num_packs"
echo "Total de pacotes não assinados: $non_sig"
echo "Total de pacotes assinados: $yes_sig"