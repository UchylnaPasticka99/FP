import os
import shutil
from datetime import datetime
import time # Import pro time.sleep()

# --- Konfigurace pro kopírovací skript ---

# 1. Základní složka, kde detektor (detektor.py) ukládá své denní složky.
#    MUSÍ ODPOVÍDAT `BASE_IMAGE_SAVE_PATH` z vašeho `detektor.py` (nebo `configurak.py`).
SOURCE_DETECTOR_BASE_PATH = "longterm_motion_captures"

# 2. Cílová PLOCHÁ složka, kam se budou kopírovat všechny soubory.
#    Žádné podsložky s datem zde nebudou vytvářeny.
TARGET_SYNC_FLAT_PATH = "all_synced_captures_flat"

# 3. Název souboru, který bude uchovávat záznamy o již zkopírovaných souborech.
#    Bude vytvořen v adresáři, odkud je tento skript spuštěn.
COPIED_FILES_LOG = "once_copied.txt"

# 4. Interval v sekundách, po kterém se bude funkce kopírování opakovat.
LOOP_INTERVAL_SECONDS = 5
# --- Konec Konfigurace ---

def get_todays_date_string():
    """Vrátí dnešní datum jako řetězec ve formátu YYYY-MM-DD."""
    return datetime.now().strftime("%Y-%m-%d")

def load_copied_log(log_file_path):
    """
    Načte záznamy o již zkopírovaných souborech z logovacího souboru.
    Vrací množinu (set) absolutních cest k souborům.
    """
    copied_set = set()
    if os.path.exists(log_file_path):
        try:
            with open(log_file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    copied_set.add(line.strip())
        except IOError as e:
            print(f"Chyba při čtení log souboru '{log_file_path}': {e}")
    return copied_set

def append_to_copied_log(log_file_path, abs_file_path):
    """
    Přidá absolutní cestu zkopírovaného souboru do logovacího souboru.
    """
    try:
        with open(log_file_path, 'a', encoding='utf-8') as f:
            f.write(abs_file_path + "\n")
    except IOError as e:
        print(f"Chyba při zápisu do log souboru '{log_file_path}': {e}")

def perform_sync_operation():
    """
    Provede jednu operaci synchronizace dnešní složky s detekovanými snímky
    do jedné ploché cílové složky.
    """
    print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Spouštění synchronizační operace...")

    already_copied_files = load_copied_log(COPIED_FILES_LOG)
    # Není třeba vypisovat počet načtených záznamů při každém běhu smyčky, pokud to není žádoucí.
    # print(f"Nalezeno {len(already_copied_files)} záznamů o již zkopírovaných souborech v '{COPIED_FILES_LOG}'.")

    todays_date_str = get_todays_date_string() # Získává se v každé iteraci pro případ, že skript běží přes půlnoc
    todays_source_folder = os.path.join(SOURCE_DETECTOR_BASE_PATH, todays_date_str)

    if not os.path.isdir(todays_source_folder):
        print(f"Dnešní zdrojová složka '{os.path.abspath(todays_source_folder)}' nebyla nalezena. Není co kopírovat.")
        return 0 # Vrátíme počet zkopírovaných souborů v této iteraci

    # Není třeba vypisovat zdrojovou složku v každé iteraci, pokud to není nutné
    # print(f"Zdrojová složka pro dnešek (z detektoru): '{os.path.abspath(todays_source_folder)}'")

    # Vytvoření cílové ploché složky, pokud neexistuje - stačí jednou, ale neškodí to
    try:
        os.makedirs(TARGET_SYNC_FLAT_PATH, exist_ok=True)
    except OSError as e:
        print(f"Chyba při vytváření/ověřování cílové ploché složky '{TARGET_SYNC_FLAT_PATH}': {e}")
        return 0

    copied_count_this_run = 0
    skipped_count_this_run = 0 # Resetujeme pro každou iteraci

    try:
        for item_name in os.listdir(todays_source_folder):
            source_item_path = os.path.join(todays_source_folder, item_name)

            if os.path.isfile(source_item_path):
                abs_source_item_path = os.path.abspath(source_item_path)

                if abs_source_item_path in already_copied_files:
                    skipped_count_this_run += 1
                    continue

                target_filename_with_prefix = f"{todays_date_str}_{item_name}"
                target_item_path = os.path.join(TARGET_SYNC_FLAT_PATH, target_filename_with_prefix)

                try:
                    print(f"Kopíruji: '{source_item_path}' -> '{target_item_path}'")
                    shutil.copy2(source_item_path, target_item_path)
                    
                    append_to_copied_log(COPIED_FILES_LOG, abs_source_item_path)
                    already_copied_files.add(abs_source_item_path)
                    copied_count_this_run += 1
                except shutil.Error as e:
                    print(f"CHYBA při kopírování souboru '{source_item_path}': {e}")
                except IOError as e:
                    print(f"CHYBA I/O při kopírování souboru '{source_item_path}': {e}")
            
    except OSError as e:
        print(f"Chyba při čtení obsahu zdrojové složky '{todays_source_folder}': {e}")
        return 0 # Nebylo nic zkopírováno kvůli chybě

    if copied_count_this_run > 0 or skipped_count_this_run > 0:
        print(f"Dokončena operace: {copied_count_this_run} nových souborů zkopírováno, {skipped_count_this_run} přeskočeno.")
    # Pokud nic nebylo zkopírováno ani přeskočeno (složka byla prázdná nebo všechny soubory nové), nevypisujeme nic.

    return copied_count_this_run

if __name__ == "__main__":
    # Vytvoření cílové složky a logu na začátku, pokud neexistují
    try:
        os.makedirs(TARGET_SYNC_FLAT_PATH, exist_ok=True)
        print(f"Cílová plochá složka pro synchronizaci: '{os.path.abspath(TARGET_SYNC_FLAT_PATH)}'")
        # Vytvoření prázdného log souboru, pokud neexistuje, aby se předešlo chybě při prvním čtení
        if not os.path.exists(COPIED_FILES_LOG):
            with open(COPIED_FILES_LOG, 'w', encoding='utf-8') as f:
                pass # Jen vytvoří soubor
            print(f"Vytvořen log soubor: '{os.path.abspath(COPIED_FILES_LOG)}'")
    except OSError as e:
        print(f"Kritická chyba při inicializaci cílové složky nebo logu: {e}")
        exit(1) # Ukončíme skript, pokud základní nastavení selže

    print(f"Skript bude opakovat synchronizaci každých {LOOP_INTERVAL_SECONDS} sekund.")
    print("Pro ukončení stiskněte Ctrl+C.")
    
    try:
        while True:
            perform_sync_operation()
            print(f"Čekání {LOOP_INTERVAL_SECONDS} sekund před další synchronizací...")
            time.sleep(LOOP_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("\nSkript byl ukončen uživatelem (Ctrl+C).")
    except Exception as e:
        print(f"\nNeočekávaná chyba, skript končí: {e}")
    finally:
        print("Ukončování programu.")