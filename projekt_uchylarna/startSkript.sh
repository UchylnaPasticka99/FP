#!/bin/bash

# Adresář, kde se nacházejí Python skripty
# Pokud je tento Bash skript ve stejném adresáři jako Python skripty, můžete toto ponechat.
# Jinak nastavte absolutní nebo relativní cestu.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Názvy vašich Python skriptů
DETECTOR_SCRIPT="detektor.py"
MOVER_SCRIPT="photoMover.py" # Upravte název, pokud je jiný (např. sync_todays_captures_to_flat_folder.py)

# Cesta k interpretu Pythonu (obvykle python3 nebo python)
PYTHON_EXECUTABLE="python3" # Může být také jen "python" na některých systémech

# Log soubory pro výstup každého skriptu (volitelné, ale doporučené)
DETECTOR_LOG="${SCRIPT_DIR}/detector.log"
MOVER_LOG="${SCRIPT_DIR}/photoMover.log"

echo "Spouštím ${DETECTOR_SCRIPT}..."
# Spustí skript na pozadí (&) a přesměruje standardní výstup a chybový výstup do log souboru.
# nohup zajistí, že proces poběží i po uzavření terminálu (pokud je to žádoucí).
nohup "${PYTHON_EXECUTABLE}" "${SCRIPT_DIR}/${DETECTOR_SCRIPT}" > "${DETECTOR_LOG}" 2>&1 &
DETECTOR_PID=$! # Uloží Process ID (PID) posledního spuštěného procesu na pozadí
echo "${DETECTOR_SCRIPT} spuštěn s PID: ${DETECTOR_PID}. Výstup v ${DETECTOR_LOG}"

echo ""
echo "Spouštím ${MOVER_SCRIPT}..."
nohup "${PYTHON_EXECUTABLE}" "${SCRIPT_DIR}/${MOVER_SCRIPT}" > "${MOVER_LOG}" 2>&1 &
MOVER_PID=$!
echo "${MOVER_SCRIPT} spuštěn s PID: ${MOVER_PID}. Výstup v ${MOVER_LOG}"

echo ""
echo "Oba skripty byly spuštěny na pozadí."
echo "Pro sledování výstupu použijte příkaz 'tail -f <nazev_log_souboru>', např.:"
echo "tail -f ${DETECTOR_LOG}"
echo "tail -f ${MOVER_LOG}"
echo ""
echo "Pro ukončení skriptů můžete použít jejich PID:"
echo "kill ${DETECTOR_PID}"
echo "kill ${MOVER_PID}"    