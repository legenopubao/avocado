#라즈베리 파이 Ai 학습 코드 . AI 벌레 감지 코드.
import cv2
import numpy as np
import time
import os
import sys
from ultralytics import YOLO
import paho.mqtt.client as mqtt

# ---------------- CONFIG ----------------
MODEL_PATH = "yolo11s_ncnn_model"  
USB_INDEX = 0
CONF_THRESH = 0.5
BUG_THRESHOLD = 0
INFERENCE_INTERVAL = 0   # seconds between YOLO inferences
FPS_LIMIT = 30           # cap display at 30 FPS
# ----------------------------------------

# ---------MQTT Info-----------------------
BROKER = "broker.hivemq.com"
PORT = 1883
USERNAME = ""  
PASSWORD = ""
CLIENT_ID = "raspi_pump"
TOPIC = "s_window/pump"
#------------------------------------------

# MQTT setup
client = mqtt.Client(client_id=CLIENT_ID, protocol=mqtt.MQTTv311)
client.username_pw_set(USERNAME, PASSWORD)
client.connect(BROKER, PORT, 60)

# Check model file
if not os.path.exists(MODEL_PATH):
    print("ERROR: Model path not found.")
    sys.exit(0)

# Load YOLO model
model = YOLO(MODEL_PATH, task="detect")
labels = model.names

# Open webcam
cap = cv2.VideoCapture(USB_INDEX)
if not cap.isOpened():
    print("ERROR: Could not open webcam.")
    sys.exit(0)

# Try wider resolution
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

# FPS tracking (stable, update every 1 sec)
last_fps_time = time.time()
frames_counted = 0
display_fps = 0

# Inference timing
last_inference = 0
bug_count = 0
last_detections = []  # store last detections for stable drawing

#MQTT Interval
MQTT_INTERVAL = 5  # seconds between sending MQTT messages
last_mqtt = 0


while True:
    loop_start = time.perf_counter()
    current_time = time.time()

    # Grab frame
    ret, frame = cap.read()
    if not ret:
        print("ERROR: Webcam frame not available.")
        break

    # ---------- YOLO Inference ----------
    if current_time - last_inference >= INFERENCE_INTERVAL:
        results = model(frame, verbose=False)
        detections = results[0].boxes

        bug_count = 0
        last_detections = []

        for det in detections:
            conf = det.conf.item()
            if conf >= CONF_THRESH:
                bug_count += 1
                x1, y1, x2, y2 = map(int, det.xyxy.cpu().numpy().squeeze())
                classidx = int(det.cls.item())
                classname = labels[classidx]
                label = f"{classname}: {int(conf*100)}%"
                last_detections.append((x1, y1, x2, y2, label))

        last_inference = current_time

    # ---------- MQTT Publish (throttled) ----------
    if current_time - last_mqtt >= MQTT_INTERVAL:
        if bug_count >= BUG_THRESHOLD:
            client.publish(TOPIC, "ON")
            print(f"[MQTT] Sent Pump ON")
        else:
            client.publish(TOPIC, "OFF")
            print(f"[MQTT] Sent Pump OFF")
        last_mqtt = current_time

    # ---------- Draw detections ----------
    for (x1, y1, x2, y2, label) in last_detections:
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 255), 2)
        cv2.putText(frame, label, (x1, y1 - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 2)

    # Display bug count
    cv2.putText(frame, f"Bug count: {bug_count}",
                (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 255), 2)

    # ---------- FPS calculation ----------
    frames_counted += 1
    if current_time - last_fps_time >= 1.0:
        display_fps = frames_counted / (current_time - last_fps_time)
        frames_counted = 0
        last_fps_time = current_time

    cv2.putText(frame, f"FPS: {display_fps:.2f}",
                (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    # Show camera feed
    cv2.imshow("Bug Detection", frame)

    # Quit with 'q'
    key = cv2.waitKey(1) & 0xFF
    if key == ord("q"):
        break

    # ---------- Cap FPS ----------
    elapsed = time.perf_counter() - loop_start
    frame_time = 1.0 / FPS_LIMIT
    if elapsed < frame_time:
        time.sleep(frame_time - elapsed)

cap.release()
cv2.destroyAllWindows()
