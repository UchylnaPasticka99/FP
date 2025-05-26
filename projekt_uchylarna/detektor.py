# Python program to implement
# Webcam Motion Detector with Averaged Background and Date-Specific Image Capture Folders

# importing OpenCV, time, Pandas library, collections, numpy and os
import cv2
import time # Standard time module
import pandas
from datetime import datetime
from collections import deque
import numpy as np
import os # For directory and file operations

from configurak import *




# --- Configuration ---

NUM_BACKGROUND_FRAMES = 10
GAUSSIAN_BLUR_KERNEL = (21, 21)
THRESHOLD_VALUE = 30
MIN_CONTOUR_AREA = 1000

SAVE_IMAGES = True
BASE_IMAGE_SAVE_PATH = "longterm_motion_captures" # Base folder for all captures
CAPTURE_INTERVAL_SECONDS = 5.0
# --- End Configuration ---

# Stores the last N grayscale, blurred frames for averaging
background_frames_buffer = deque(maxlen=NUM_BACKGROUND_FRAMES)
averaged_background = None

# List when any moving object appear
motion_list = [ None, None ]

# Time of movement (for CSV logging)
time_log = []

# Initializing DataFrame for CSV
df = pandas.DataFrame(columns = ["Start", "End"])

# For throttling image saves
last_image_save_time = 0.0

# --- Setup Image Saving Path for this run ---
def get_or_create_todays_capture_folder(base_path):
    """
    Creates and returns the path to a date-specific folder for saving images.
    The folder will be named with the current date (YYYY-MM-DD) inside the base_path.
    """
    current_date_str = datetime.now().strftime("%Y-%m-%d")
    todays_folder = os.path.join(base_path, current_date_str)
    os.makedirs(todays_folder, exist_ok=True)
    return todays_folder

# --- Setup Image Saving Path for this run ---
todays_capture_folder = ""
if SAVE_IMAGES:
    todays_capture_folder = get_or_create_todays_capture_folder(BASE_IMAGE_SAVE_PATH)
    print(f"Motion images for this session will be saved to: {os.path.abspath(todays_capture_folder)}")
# --- End Setup Image Saving Path ---

# Capturing video
video = cv2.VideoCapture(0)
if not video.isOpened():
    print("Error: Could not open video source.")
    exit()

print(f"Collecting initial {NUM_BACKGROUND_FRAMES} frames for background averaging...")

while True:
    check, frame = video.read()
    if not check:
        print("Error: Could not read frame or end of video.")
        break

    motion = 0
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    gray_blurred = cv2.GaussianBlur(gray, GAUSSIAN_BLUR_KERNEL, 0)
    background_frames_buffer.append(gray_blurred.astype(np.float32))

    if len(background_frames_buffer) < NUM_BACKGROUND_FRAMES:
        cv2.putText(frame, f"Collecting: {len(background_frames_buffer)}/{NUM_BACKGROUND_FRAMES}",
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.imshow("Color Frame", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
        continue

    averaged_background_float = np.mean(np.array(list(background_frames_buffer)), axis=0)
    averaged_background = averaged_background_float.astype(np.uint8)

    diff_frame = cv2.absdiff(averaged_background, gray_blurred)
    thresh_frame = cv2.threshold(diff_frame, THRESHOLD_VALUE, 255, cv2.THRESH_BINARY)[1]
    thresh_frame = cv2.dilate(thresh_frame, None, iterations = 2)

    cnts,_ = cv2.findContours(thresh_frame.copy(),
                       cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    for contour in cnts:
        if cv2.contourArea(contour) < MIN_CONTOUR_AREA:
            continue
        motion = 1
        (x, y, w, h) = cv2.boundingRect(contour)
        cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 3)

    if motion == 1 and SAVE_IMAGES and todays_capture_folder: # Check if folder path is set
        current_time_for_save = time.time()
        if current_time_for_save - last_image_save_time >= CAPTURE_INTERVAL_SECONDS:
            timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
            # Save into the date-specific folder
            filename = os.path.join(todays_capture_folder, f"motion_{timestamp_str}.jpg")
            cv2.imwrite(filename, frame)
            print(f"Motion image saved: {filename}")
            last_image_save_time = current_time_for_save

    motion_list.append(motion)
    motion_list = motion_list[-2:]

    if motion_list[-1] == 1 and motion_list[-2] == 0:
        time_log.append(datetime.now())
    if motion_list[-1] == 0 and motion_list[-2] == 1:
        time_log.append(datetime.now())

    cv2.imshow("Color Frame", frame)
    if averaged_background is not None:
        cv2.imshow("Averaged Background", averaged_background)
    cv2.imshow("Difference Frame", diff_frame)
    cv2.imshow("Threshold Frame", thresh_frame)

    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'):
        if motion == 1:
            time_log.append(datetime.now())
        break

new_rows = []
for i in range(0, len(time_log) -1 , 2):
    if i + 1 < len(time_log):
        new_rows.append({"Start": time_log[i], "End": time_log[i+1]})

if new_rows:
    df = pandas.concat([df, pandas.DataFrame(new_rows)], ignore_index=True)

if not df.empty:
    df.to_csv("Time_of_movements_avg_bg.csv", index=False)
    print("Movement log saved to Time_of_movements_avg_bg.csv")
else:
    print("No motion detected or logged for CSV.")

video.release()
cv2.destroyAllWindows()