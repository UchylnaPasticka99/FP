#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Adresář pro PID soubory (podle nového spouštěče)
PID_ADRESAR_NAZEV="PIDy"
PID_ADRESAR="${SCRIPT_DIR}/${PID_ADRESAR_NAZEV}"

# Cesty k PID souborům (podle nového spouštěče)
DETECTOR_PID_FILE="${PID_ADRESAR}/detector.pid"
MOVER_PID_FILE="${PID_ADRESAR}/photoMover.pid"
EMAIL_PID_FILE="${PID_ADRESAR}/email_provider.pid"

echo "---------------------------------------------"
echo "Pokouším se ukončit skripty..."
echo "---------------------------------------------"

# Funkce pro ukončení procesu a smazání PID souboru
kill_and_cleanup() {
    local process_name=$1
    local pid_file=$2

    echo ""
    if [ -f "${pid_file}" ]; then
        PID_TO_KILL=$(cat "${pid_file}")
        if ps -p "${PID_TO_KILL}" > /dev/null; then # Zkontroluje, zda proces s daným PID stále běží
            echo "Ukončuji ${process_name} (PID: ${PID_TO_KILL})..."
            kill "${PID_TO_KILL}" # Pošle SIGTERM (standardní signál pro ukončení)
            # Můžete přidat krátkou pauzu a pak SIGKILL, pokud SIGTERM nestačí
            # sleep 1 # Krátká pauza, aby se proces stihl ukončit
            # if ps -p "${PID_TO_KILL}" > /dev/null; then
            #   echo "Proces ${process_name} (PID: ${PID_TO_KILL}) stále běží po SIGTERM, posílám SIGKILL..."
            #   kill -9 "${PID_TO_KILL}"
            # fi
            rm "${pid_file}"
            echo "PID soubor ${pid_file} smazán."
        else
            echo "Proces ${process_name} (PID: ${PID_TO_KILL} z ${pid_file}) již neběží."
            rm "${pid_file}"
            echo "PID soubor ${pid_file} smazán (proces již neběžel)."
        fi
    else
        echo "Soubor ${pid_file} nenalezen. Proces ${process_name} pravděpodobně neběží nebo nebyl spuštěn tímto způsobem."
    fi
}

# Ukončení jednotlivých procesů
# Názvy procesů upraveny pro konzistenci s názvy skriptů a PID souborů
kill_and_cleanup "detektor.py" "${DETECTOR_PID_FILE}"
kill_and_cleanup "photoMover.py" "${MOVER_PID_FILE}"
kill_and_cleanup "email_provider.py" "${EMAIL_PID_FILE}"

echo ""
echo "---------------------------------------------"
echo "Proces ukončování dokončen."
# Poznámka: Tento skript nemaže adresář PIDy. Pokud je to žádoucí, přidejte:
# if [ -d "${PID_ADRESAR}" ] && [ -z "$(ls -A "${PID_ADRESAR}")" ]; then
#     echo "Adresář ${PID_ADRESAR} je prázdný, mažu ho..."
#     rmdir "${PID_ADRESAR}"
# elif [ -d "${PID_ADRESAR}" ]; then
#     echo "Adresář ${PID_ADRESAR} není prázdný, nemažu ho."
# fi
echo "---------------------------------------------"