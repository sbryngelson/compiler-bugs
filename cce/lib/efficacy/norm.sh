#!/bin/bash
sed -e 's/![0-9][0-9]*//g' -e '/^![0-9]/d' -e '/^!llvm/d' -e '/^;/d' \
    -e '/ModuleID\|source_filename/d' \
    -e 's/"file [^,]*,/"file F,/g' \
    -e 's/%r[0-9][0-9]*/%r/g' -e 's/%\([0-9][0-9]*\)/%N/g' \
    -e 's/_t[0-9][0-9]*//g' "$1" \
  | tr -s ' \t' ' ' | sed 's/^ //;s/ $//' | grep -vE '^$'
