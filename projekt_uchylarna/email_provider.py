
import os
import smtplib
import time
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.image import MIMEImage
from dotenv import load_dotenv

# ⚙️ Načtení přihlašovacích údajů z .env
load_dotenv(dotenv_path="C:/Users/AdminPRAXE/Desktop/email_provider/.env")

EMAIL_HOST = os.getenv("EMAIL_HOST", "smtp.gmail.com")
EMAIL_PORT = int(os.getenv("EMAIL_PORT", 465))
EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS", "fotopast99r@gmail.com")
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD", "vqgs lcyr zeim bnhb")
TO_EMAIL = os.getenv("TO_EMAIL", "opicipolivka123@seznam.cz")

WATCH_FOLDER = "all_synced_captures_flat"
CHECK_INTERVAL = 5  # vteřiny
SEND_INTERVAL = timedelta(minutes=5)

last_sent_time = datetime.min

def send_images_batch(image_paths):
    if not image_paths:
        return

    batch_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    msg = MIMEMultipart()
    msg['From'] = EMAIL_ADDRESS
    msg['To'] = TO_EMAIL
    msg['Subject'] = f"📸 {len(image_paths)} fotek z {batch_time}"
    msg.attach(MIMEText(f"V příloze je {len(image_paths)} fotek z {batch_time}.", 'plain'))

    try:
        for image_path in image_paths:
            with open(image_path, 'rb') as f:
                img = MIMEImage(f.read())
                img.add_header('Content-Disposition', f'attachment; filename="{os.path.basename(image_path)}"')
                msg.attach(img)

        with smtplib.SMTP_SSL(EMAIL_HOST, EMAIL_PORT) as server:
            server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            server.send_message(msg)

        print(f"[✅] Odesláno: {len(image_paths)} fotek")
        for image_path in image_paths:
            os.remove(image_path)
            print(f"[🧹] Smazáno: {image_path}")

    except Exception as e:
        print(f"[❌] Chyba při odesílání: {e}")

def monitor_folder():
    global last_sent_time
    print(f"📂 Sleduji složku: {WATCH_FOLDER}")
    os.makedirs(WATCH_FOLDER, exist_ok=True)

    while True:
        now = datetime.now()
        if now - last_sent_time >= SEND_INTERVAL:
            files = [f for f in os.listdir(WATCH_FOLDER) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            image_paths = [os.path.join(WATCH_FOLDER, f) for f in files]

            if image_paths:
                send_images_batch(image_paths)
                last_sent_time = now
            else:
                print("[ℹ️] Žádné nové fotky ke zpracování.")
        else:
            zb = (SEND_INTERVAL - (now - last_sent_time)).seconds
            print(f"[⏳] Interval neuplynul – čekám ještě {zb} sekund")

        time.sleep(CHECK_INTERVAL)

if __name__ == '__main__':
    monitor_folder()
