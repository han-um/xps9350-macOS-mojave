#!/bin/bash

# Bold / Non-bold
BOLD="\033[1m"
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[1;34m"
#echo -e "\033[0;32mCOLOR_GREEN\t\033[1;32mCOLOR_LIGHT_GREEN"
OFF="\033[m"

cd "$( dirname "${BASH_SOURCE[0]}" )"

echo "${GREEN}[DSDT]${OFF}: Compiling  DSDT / SSDT hotpatches in ./DSDT"

rm -f ../CLOVER/ACPI/patched/*.aml
for f in ./*.dsl
do
	echo "${BLUE}$(basename $f)${OFF}: Compiling to ../CLOVER/ACPI/patched"
	../tools/iasl -vr -w1 -ve -p ../CLOVER/ACPI/patched/$(basename -s .dsl $f).aml $f
done

