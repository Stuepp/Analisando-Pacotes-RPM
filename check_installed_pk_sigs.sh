#!/bin/sh
# clear

echo "Contando pacotes (INSTALADDOS) assinados e não assinados..."

# %{SIGPGP:pgpsig}, ele não apenas lê a assinatura, ele tenta verificá-la.
# Se a verificação falhar por qualquer motivo (neste caso, NOKEY),
# o rpm considera o status da assinatura como inválido e, para simplificar,
# retorna o valor (none).

# Usando a tag %{SIGPGP:pgpsig} que é compatível com versões mais antigas do RPM
rpm -qa --qf '%{SIGPGP:pgpsig}\n' | awk '
  BEGIN {
    signed = 0
    unsigned = 0
  }
  {
    if ($0 == "(none)") {
      unsigned++
    } else {
      signed++
    }
  }
  END {
    print "---"
    print "Total de pacotes: " (signed + unsigned)
    print "Total de pacotes assinados: " signed
    print "Total de pacotes não assinados: " unsigned
  }
'

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