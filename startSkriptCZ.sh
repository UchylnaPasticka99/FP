#!/bin/bash

# Získání adresáře, ve kterém se skript nachází
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Adresář pro PID soubory
PID_ADRESAR_NAZEV="PIDy"
PID_ADRESAR="${SCRIPT_DIR}/${PID_ADRESAR_NAZEV}"

# --- Konfigurace logování ---
# Základní název adresáře pro logy aktuálního běhu
AKTUALNI_LOG_ADRESAR_ZAKLAD="lastLog"
# Plná cesta k adresáři pro aktuální logy
AKTUALNI_LOG_CESTA="${SCRIPT_DIR}/${AKTUALNI_LOG_ADRESAR_ZAKLAD}"

# Hlavní adresář pro archivované logy
HLAVNI_ARCHIV_LOGU_ADRESAR_NAZEV="logArchive"
HLAVNI_ARCHIV_LOGU_CESTA="${SCRIPT_DIR}/${HLAVNI_ARCHIV_LOGU_ADRESAR_NAZEV}"
# --------------------------

# Názvy vašich Python skriptů
DETECTOR_SKRIPT_NAZEV="detektor.py"
MOVER_SKRIPT_NAZEV="photoMover.py"
EMAIL_SKRIPT_NAZEV="email_provider.py"

# Spustitelný soubor Pythonu (použijte -u pro výstup bez bufferování)
PYTHON_EXECUTABLE="python3 -u"

# Log soubory (cesty budou definovány po vytvoření AKTUALNI_LOG_CESTA)
DETECTOR_LOG_SOUBOR="${AKTUALNI_LOG_CESTA}/detector.log"
MOVER_LOG_SOUBOR="${AKTUALNI_LOG_CESTA}/photoMover.log"
EMAIL_LOG_SOUBOR="${AKTUALNI_LOG_CESTA}/email_provider.log"

# PID soubory - nyní v PID_ADRESAR
DETECTOR_PID_SOUBOR_CESTA="${PID_ADRESAR}/detector.pid"
MOVER_PID_SOUBOR_CESTA="${PID_ADRESAR}/photoMover.pid"
EMAIL_PID_SOUBOR_CESTA="${PID_ADRESAR}/email_provider.pid"

# Proměnná pro uložení PID procesu tail
TAIL_PROCES_PID=""

# Pole cest k PID souborům pro snazší iteraci
PID_SOUBORY_CESTY=("$DETECTOR_PID_SOUBOR_CESTA" "$MOVER_PID_SOUBOR_CESTA" "$EMAIL_PID_SOUBOR_CESTA")

# Funkce pro úklid a ukončení všech procesů
uklid_a_ukonceni() {
    echo "" # Nový řádek po případném ^C v terminálu
    echo "Zachycen signál. Ukončuji všechny běžící procesy a provádím úklid..."

    if [ -n "$TAIL_PROCES_PID" ] && kill -0 "$TAIL_PROCES_PID" 2>/dev/null; then
        echo "Ukončuji proces tail (PID: $TAIL_PROCES_PID)..."
        kill "$TAIL_PROCES_PID"; wait "$TAIL_PROCES_PID" 2>/dev/null
    fi

    echo "Ukončuji Python procesy..."
    for pid_soubor_cesta in "${PID_SOUBORY_CESTY[@]}"; do
        if [ -f "$pid_soubor_cesta" ]; then
            pid_k_ukonceni=$(cat "$pid_soubor_cesta")
            if [ -n "$pid_k_ukonceni" ] && kill -0 "$pid_k_ukonceni" 2>/dev/null; then
                echo "  Posílám SIGTERM procesu s PID $pid_k_ukonceni (z $pid_soubor_cesta)..."
                kill "$pid_k_ukonceni"
            fi
        fi
    done

    if [ -d "$PID_ADRESAR" ]; then
        echo "Mažu adresář PID: ${PID_ADRESAR}..."
        rm -rf "${PID_ADRESAR}"
    fi

    echo "Aktuální logy jsou uloženy v: ${AKTUALNI_LOG_CESTA}"
    echo "Všechny procesy by měly být ukončeny a úklid dokončen."
    exit 0
}

trap 'uklid_a_ukonceni' INT TERM EXIT

echo "---------------------------------------------"
echo "Příprava adresářů pro logování a PID soubory..."

# Vytvoření hlavního adresáře pro archivaci logů, pokud neexistuje
mkdir -p "${HLAVNI_ARCHIV_LOGU_CESTA}"
if [ $? -ne 0 ]; then
    echo "CHYBA: Nepodařilo se vytvořit hlavní archivní adresář ${HLAVNI_ARCHIV_LOGU_CESTA}. Ukončuji."
    exit 1
fi

# Pokud existuje adresář pro aktuální logy z minulého běhu, archivujeme ho
if [ -d "${AKTUALNI_LOG_CESTA}" ]; then
    CASOVA_ZNACKA_ADRESARE=$(date +%Y-%m-%d_%H-%M-%S)
    # Cílový adresář pro archivaci bude uvnitř HLAVNI_ARCHIV_LOGU_CESTA
    CILOVY_ARCHIV_LOGU_ADRESAR="${HLAVNI_ARCHIV_LOGU_CESTA}/${CASOVA_ZNACKA_ADRESARE}"

    echo "Nalezen existující adresář logů '${AKTUALNI_LOG_ADRESAR_ZAKLAD}'."
    echo "Vytvářím archivní podadresář: '${CILOVY_ARCHIV_LOGU_ADRESAR}'..."
    mkdir -p "${CILOVY_ARCHIV_LOGU_ADRESAR}" # Vytvoříme cílový adresář pro přesun
    if [ $? -ne 0 ]; then
        echo "CHYBA: Nepodařilo se vytvořit cílový archivní adresář ${CILOVY_ARCHIV_LOGU_ADRESAR}. Ukončuji."
        exit 1
    fi

    echo "Přesouvám obsah z '${AKTUALNI_LOG_CESTA}' do '${CILOVY_ARCHIV_LOGU_ADRESAR}'..."
    # Přesuneme obsah, ne celou složku, abychom pak mohli AKTUALNI_LOG_CESTA snadno znovu vytvořit/vyprázdnit
    # Použijeme find pro přesun souborů a adresářů, s výjimkou . (aktuální adresář)
    # a ošetříme případ, kdy je AKTUALNI_LOG_CESTA prázdná (find by mohl selhat)
    if [ -n "$(ls -A "${AKTUALNI_LOG_CESTA}")" ]; then
        find "${AKTUALNI_LOG_CESTA}" -mindepth 1 -maxdepth 1 -exec mv -t "${CILOVY_ARCHIV_LOGU_ADRESAR}" {} +
        if [ $? -eq 0 ]; then
            echo "Obsah adresáře '${AKTUALNI_LOG_ADRESAR_ZAKLAD}' byl úspěšně archivován do '${CILOVY_ARCHIV_LOGU_ADRESAR}'."
            # Nyní můžeme smazat původní (nyní prázdný) AKTUALNI_LOG_CESTA, pokud ještě existuje
            rm -rf "${AKTUALNI_LOG_CESTA}"
        else
            echo "CHYBA: Nepodařilo se přesunout obsah z '${AKTUALNI_LOG_CESTA}'."
            echo "Prosím zkontrolujte ${AKTUALNI_LOG_CESTA} a ${CILOVY_ARCHIV_LOGU_ADRESAR} manuálně."
            # Můžeme zkusit pokračovat, ale logy nemusí být správně archivovány
        fi
    else
        echo "Adresář '${AKTUALNI_LOG_CESTA}' je prázdný, není co archivovat."
        rm -rf "${AKTUALNI_LOG_CESTA}" # Smažeme ho, aby se vytvořil nový čistý
    fi
fi

# Vytvoření (nového) adresáře pro aktuální logy
echo "Vytvářím adresář pro aktuální logy: ${AKTUALNI_LOG_CESTA}..."
mkdir -p "${AKTUALNI_LOG_CESTA}"
if [ $? -ne 0 ]; then
    echo "CHYBA: Nepodařilo se vytvořit adresář ${AKTUALNI_LOG_CESTA}. Ukončuji."
    exit 1
fi

# Vytvoření adresáře pro PID soubory
echo "Vytvářím adresář pro PID soubory: ${PID_ADRESAR}..."
mkdir -p "${PID_ADRESAR}"
if [ $? -ne 0 ]; then
    echo "CHYBA: Nepodařilo se vytvořit adresář ${PID_ADRESAR}. Ukončuji."
    exit 1
fi

# Inicializace/vyprázdnění log souborů uvnitř AKTUALNI_LOG_CESTA
echo "Inicializuji log soubory v ${AKTUALNI_LOG_CESTA}..."
> "${DETECTOR_LOG_SOUBOR}"
> "${MOVER_LOG_SOUBOR}"
> "${EMAIL_LOG_SOUBOR}"

echo "---------------------------------------------"
echo "Spouštění skriptů..."
# (zbytek skriptu zůstává stejný)
# ...
# Spuštění skriptu Detektor
echo ""
echo "Spouštím ${DETECTOR_SKRIPT_NAZEV}..."
${PYTHON_EXECUTABLE} "${SCRIPT_DIR}/${DETECTOR_SKRIPT_NAZEV}" > "${DETECTOR_LOG_SOUBOR}" 2>&1 &
echo $! > "${DETECTOR_PID_SOUBOR_CESTA}"
echo "${DETECTOR_SKRIPT_NAZEV} spuštěn s PID $(cat ${DETECTOR_PID_SOUBOR_CESTA}). Výstup v ${DETECTOR_LOG_SOUBOR}"

# Spuštění skriptu Mover
echo ""
echo "Spouštím ${MOVER_SKRIPT_NAZEV}..."
${PYTHON_EXECUTABLE} "${SCRIPT_DIR}/${MOVER_SKRIPT_NAZEV}" > "${MOVER_LOG_SOUBOR}" 2>&1 &
echo $! > "${MOVER_PID_SOUBOR_CESTA}"
echo "${MOVER_SKRIPT_NAZEV} spuštěn s PID $(cat ${MOVER_PID_SOUBOR_CESTA}). Výstup v ${MOVER_LOG_SOUBOR}"

# Spuštění skriptu Email
echo ""
echo "Spouštím ${EMAIL_SKRIPT_NAZEV}..."
${PYTHON_EXECUTABLE} "${SCRIPT_DIR}/${EMAIL_SKRIPT_NAZEV}" > "${EMAIL_LOG_SOUBOR}" 2>&1 &
echo $! > "${EMAIL_PID_SOUBOR_CESTA}"
echo "${EMAIL_SKRIPT_NAZEV} spuštěn s PID $(cat ${EMAIL_PID_SOUBOR_CESTA}). Výstup v ${EMAIL_LOG_SOUBOR}"

echo ""
echo "---------------------------------------------"
echo "Všechny skripty byly spuštěny."
echo "Nyní bude spuštěno sledování všech log souborů z ${AKTUALNI_LOG_CESTA}."
echo "Stiskněte Ctrl+C pro ukončení tohoto skriptu A VŠECH JÍM SPUŠTĚNÝCH PROCESŮ."
echo "Adresář ${PID_ADRESAR} bude po ukončení smazán."
echo "Adresář ${AKTUALNI_LOG_CESTA} s aktuálními logy ZŮSTANE zachován."
echo "Předchozí logy (pokud existovaly) byly archivovány do ${HLAVNI_ARCHIV_LOGU_CESTA}/[datum_cas]."
echo "---------------------------------------------"
echo ""
echo "Sleduji logy (Stiskněte Ctrl+C pro ukončení všeho):"

tail -f "${DETECTOR_LOG_SOUBOR}" "${MOVER_LOG_SOUBOR}" "${EMAIL_LOG_SOUBOR}" &
TAIL_PROCES_PID=$!

wait "$TAIL_PROCES_PID"

echo "Proces tail (PID: $TAIL_PROCES_PID) se ukončil (nebo byl ukončen)."