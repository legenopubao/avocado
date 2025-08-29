from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
import asyncio
from datetime import datetime
import random
from typing import List, Dict, Any, Optional, Union
from contextlib import asynccontextmanager
import uvicorn

# -------------------------------
# Pydantic Models
# -------------------------------
class DeviceStatus(BaseModel):
    device_id: str = "ESP32-MOCK-001"
    online: bool = True
    uptime: int = 0  # seconds
    wifi_strength: int = -45
    free_memory: int = 25000

class SensorData(BaseModel):
    temperature: float = 25.0
    humidity: float = 60.0
    pm25: float = 15.3
    bug: bool = False
    servo: int = 0

class ControlCommand(BaseModel):
    command: str  # "led_on", "led_off", "pump_on", "pump_off", "restart"
    value: Any = None

# -------------------------------
# Globals
# -------------------------------
connected_clients: List[WebSocket] = []
current_sensor_data: SensorData = SensorData()
device_status: DeviceStatus = DeviceStatus()
led_state: bool = False
pump_state: bool = False

# -------------------------------
# FastAPI App
# -------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("ESP32 Mock Server 시작됨!")
    print("HTTP API: http://localhost:8000")
    print("WebSocket: ws://localhost:8000/ws")
    print("API 문서: http://localhost:8000/docs")
    task = asyncio.create_task(simulate_sensor_data())
    try:
        yield
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

app = FastAPI(
    title="ESP32 Mock Server",
    description="ESP32와 Flutter 앱 통신 테스트용 서버",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*", "http://localhost", "http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# -------------------------------
# Helpers
# -------------------------------
def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))

def handle_control_command(command_or_payload: Union[str, Dict[str, Any]], value: Any = None) -> Dict[str, Any]:
    """
    Accepts either:
      - command_or_payload = "led_on" (and optional value arg)
      - command_or_payload = {"command": "led_on", "value": ...}
    """
    global led_state, pump_state,current_sensor_data

    if isinstance(command_or_payload, dict):
        cmd = command_or_payload.get("command")
        val = command_or_payload.get("value")
    else:
        cmd = str(command_or_payload)
        val = value

    if cmd == "led_on":
        led_state = True
        return {"success": True, "led_state": True, "message": "LED 켜짐"}
    elif cmd == "led_off":
        led_state = False
        return {"success": True, "led_state": False, "message": "LED 꺼짐"}
    elif cmd == "pump_on":
        pump_state = True
        return {"success": True, "pump_state": True, "message": "펌프 켜짐"}
    elif cmd == "pump_off":
        pump_state = False
        return {"success": True, "pump_state": False, "message": "펌프 꺼짐"}
    elif cmd == "restart":
        return {"success": True, "message": "재시작 명령 수신됨"}
    elif cmd == "bug_on":
        current_sensor_data.bug = True
        return {"success": True, "bug_state": True, "message": "벌레 감지 ON"}
    elif cmd == "bug_off":
        current_sensor_data.bug = False
        return {"success": True, "bug_state": False, "message": "벌레 감지 OFF"}
    else:
        return {"success": False, "message": f"알 수 없는 명령: {cmd}"}

async def broadcast(payload: Dict[str, Any]):
    stale: List[WebSocket] = []
    for client in connected_clients:
        try:
            # payload는 그대로 내보냄 (wrapper 없음)
            await client.send_text(json.dumps(payload))
        except Exception:
            stale.append(client)
    for s in stale:
        if s in connected_clients:
            connected_clients.remove(s)

# -------------------------------
# WebSocket
# -------------------------------
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_clients.append(websocket)
    print(f"클라이언트 연결됨. 총 연결 수: {len(connected_clients)}")

    try:
        # 상태는 타입 래핑해서 안내(그대로 유지)
        await websocket.send_text(json.dumps({
            "type": "status",
            "data": {
                **device_status.model_dump(),
                "led_state": led_state,
                "pump_state": pump_state
            }
        }))
        # 센서 데이터는 "그대로" 평평한 JSON으로 전송
        await websocket.send_text(json.dumps(current_sensor_data.model_dump()))

        while True:
            data = await websocket.receive_text()
            message = json.loads(data)

            mtype = message.get("type")
            if mtype == "control":
                response = handle_control_command(message.get("command"), message.get("value"))
                await websocket.send_text(json.dumps({
                    "type": "control_response",
                    "data": response
                }))
                # 상태 변경 브로드캐스트(타입 래핑 유지)
                await broadcast({
                    "type": "status",
                    "data": {
                        **device_status.model_dump(),
                        "led_state": led_state,
                        "pump_state": pump_state
                    }
                })

            elif mtype == "get_sensor_data":
                # 요청 시에도 "그대로" 전달
                await websocket.send_text(json.dumps(current_sensor_data.model_dump()))

            elif mtype == "get_status":
                await websocket.send_text(json.dumps({
                    "type": "status",
                    "data": {
                        **device_status.model_dump(),
                        "led_state": led_state,
                        "pump_state": pump_state
                    }
                }))

    except WebSocketDisconnect:
        if websocket in connected_clients:
            connected_clients.remove(websocket)
        print(f"클라이언트 연결 해제됨. 총 연결 수: {len(connected_clients)}")

# -------------------------------
# HTTP Endpoints
# -------------------------------
@app.get("/")
async def root():
    return {
        "message": "ESP32 Mock Server",
        "version": "1.0.0",
        "endpoints": {
            "GET /status": "장치 상태 확인",
            "GET /sensor": "센서 데이터 조회 (평평한 JSON)",
            "POST /sensor": "센서 데이터 업데이트 (평평한 JSON 바디)",
            "POST /control": "제어 명령 전송",
            "GET /ws": "WebSocket 연결"
        }
    }

@app.get("/status")
async def get_status():
    return {
        **device_status.model_dump(),
        "led_state": led_state,
        "pump_state": pump_state
    }

@app.get("/sensor")
async def get_sensor_data():
    # 평평한 JSON 그대로
    return current_sensor_data.model_dump()

@app.post("/sensor")
async def update_sensor_data(data: SensorData):
    global current_sensor_data
    # 평평한 JSON 바디 -> 모델에 그대로 반영 (timestamp 같은 필드 추가 안 함)
    current_sensor_data = data

    # WebSocket으로도 "그대로" 뿌려줌
    await broadcast(current_sensor_data.model_dump())
    return current_sensor_data.model_dump()

@app.post("/control")
async def send_control_command(command: ControlCommand):
    response = handle_control_command(command.command, command.value)
    # 상태는 기존 래핑 유지
    await broadcast({
        "type": "status",
        "data": {
            **device_status.model_dump(),
            "led_state": led_state,
            "pump_state": pump_state
        }
    })
    return response

@app.get("/data")
async def get_data():
    # 참고용 합본 엔드포인트 (Flutter가 안 쓸 수 있으니 유지만)
    return {
        "sensor_data": current_sensor_data.model_dump(),
        "device_status": device_status.model_dump(),
        "led_state": led_state,
        "pump_state": pump_state
    }

@app.get("/bugOn")
async def bug_on():
    try:
        global current_sensor_data
        current_sensor_data.bug = True
        await broadcast(current_sensor_data.model_dump())
        return {
            "ok": True,
            "msg": "벌레 감지 모드 활성화"
        }
    except Exception as e:
        return {
            "ok": False,
            "msg": f"제어 오류: {str(e)}"
        }

@app.get("/bugOff")
async def bug_off():
    try:
        global current_sensor_data
        current_sensor_data.bug = False
        await broadcast(current_sensor_data.model_dump())
        return {
            "ok": True,
            "msg": "벌레 감지 모드 비활성화"
        }
    except Exception as e:
        return {
            "ok": False,
            "msg": f"제어 오류: {str(e)}"
        }

# -------------------------------
# Sensor Simulator
# -------------------------------
async def simulate_sensor_data():
    global current_sensor_data, device_status
    while True:
        # temp/hum/pm25 키로 정확히 갱신
        temp_change = random.uniform(-0.5, 0.5)
        humi_change = random.uniform(-2, 2)
        pm25_change = random.uniform(-3, 3)

        current_sensor_data.temperature = clamp(current_sensor_data.temperature + temp_change, 15, 35)
        current_sensor_data.humidity = clamp(current_sensor_data.humidity + humi_change, 30, 80)
        current_sensor_data.pm25 = max(0.0, current_sensor_data.pm25 + pm25_change)
        # bug/servo는 필요시 외부 제어 또는 여기서 가끔 바꿔도 됨

        # 장치 상태 (업타임을 5초씩 증가)
        device_status.uptime += 5
        device_status.free_memory = max(20000, device_status.free_memory - random.randint(0, 10))
        device_status.wifi_strength = -45 + random.randint(-5, 5)

        # 센서 데이터는 "그대로" 브로드캐스트
        await broadcast(current_sensor_data.model_dump())
        # 상태는 타입 래핑 유지
        await broadcast({"type": "status", "data": device_status.model_dump()})

        await asyncio.sleep(5)

# -------------------------------
# Entrypoint
# -------------------------------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)

