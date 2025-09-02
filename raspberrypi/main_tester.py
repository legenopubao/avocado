#라즈베리 파이 Ai 학습 코드 . AI 벌레 감지 코드.
import cv2
import numpy as np
import time
import os
import sys
from ultralytics import YOLO
import paho.mqtt.client as mqtt

# ---------------- CONFIG ----------------
MODEL_PATH = "yolo11s_ncnn_model"  # change to your .pt path
USB_INDEX = 0  # usb0
CONF_THRESH = 0.5
BUG_THRESHOLD = 1
# ----------------------------------------

# ---------MQTT Info-----------------------
BROKER = "broker.hivemq.com"   # same as ESP
PORT = 1883
USERNAME = ""  
PASSWORD = ""
CLIENT_ID = "raspi_0001"
#------------------------------------------

#Client info
client = mqtt.Client(client_id=CLIENT_ID, protocol=mqtt.MQTTv311)
client.username_pw_set(USERNAME, PASSWORD) #Current MQTT broker doesnt use unique ID (might change later)
client.connect(BROKER, PORT, 60)

# Check model file exists
if not os.path.exists(MODEL_PATH):
    print("ERROR: Model path not found.")
    sys.exit(0)

# Load YOLO model
model = YOLO(MODEL_PATH, task='detect')
labels = model.names

# Open webcam
cap = cv2.VideoCapture(USB_INDEX)
if not cap.isOpened():
    print("ERROR: Could not open webcam.")
    sys.exit(0)

avg_frame_rate = 0
frame_rate_buffer = []
fps_avg_len = 50

cap.set(3, 640)  # reduce resolution
cap.set(4, 480)




while True:
    t_start = time.perf_counter()
    ret, frame = cap.read()
    if not ret:
        print("ERROR: Webcam frame not available.")
        break

    # Run inference
    results = model(frame, verbose=False)
    detections = results[0].boxes

    # Count objects (bugs)
    bug_count = 0
    for det in detections:
        conf = det.conf.item()
        if conf >= CONF_THRESH:
            bug_count += 1
            # Draw bounding box
            x1, y1, x2, y2 = map(int, det.xyxy.cpu().numpy().squeeze())
            classidx = int(det.cls.item())
            classname = labels[classidx]
            label = f"{classname}: {int(conf*100)}%"
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 255), 2)
            cv2.putText(frame, label, (x1, y1 - 5),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 2)

    # Show bug count
    cv2.putText(frame, f"Bug count: {bug_count}",
                (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 255), 2)

    # Check threshold
    if bug_count >= BUG_THRESHOLD:
        cv2.putText(frame, "ACTIVATED",
                    (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 0, 255), 3)
        client.publish("s_window/pump", "ON")
        print(f"Sent bugs={bug_count}, Pump ON")
        time.sleep(5)

    # FPS calculation
    t_stop = time.perf_counter()
    fps = 1.0 / (t_stop - t_start)
    frame_rate_buffer.append(fps)
    if len(frame_rate_buffer) > fps_avg_len:
        frame_rate_buffer.pop(0)
    avg_frame_rate = np.mean(frame_rate_buffer)

    cv2.putText(frame, f"FPS: {avg_frame_rate:.2f}",
                (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    # Show window
    cv2.imshow("Bug Detection", frame)

    # Quit with q
    key = cv2.waitKey(5) & 0xFF
    if key == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()