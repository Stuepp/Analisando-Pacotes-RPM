#!/bin/sh
# a linha acima declara o bin que executará o script

clear
# a linha acima executa um comando shell que limpa a tela

rpm -qa > rpm_packs_list.txt

packs="./rpm_packs_list.txt"

while IFS= read -r line; do
  rpm -qi "$line" | grep Signature
done < $packs