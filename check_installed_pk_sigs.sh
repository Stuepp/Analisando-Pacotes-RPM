#!/bin/sh
# clear

echo "Contando pacotes assinados e não assinados..."

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