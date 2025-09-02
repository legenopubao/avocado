#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef AIR_QUALITY_POST_URL
#define AIR_QUALITY_POST_URL "http://YOUR_SERVER_HOST:PORT/air-quality"
#endif

// Flutter/백엔드에서 ESP 명령을 가져오는 엔드포인트 (GET)
// 예: http://YOUR_SERVER_HOST:PORT/esp/command?device_id=esp0001
#ifndef AIR_COMMAND_PULL_URL
#define AIR_COMMAND_PULL_URL "http://YOUR_SERVER_HOST:PORT/esp/command?device_id=esp0001"
#endif

// POST 이후 GET 폴링 자동 수행 여부
#ifndef AIR_POLL_AFTER_POST
#define AIR_POLL_AFTER_POST 1
#endif

// temperature, humidity, pm25, pm10, bug 값을 서버로 POST 전송
esp_err_t send_air_quality_data(float temperature,
                                float humidity,
                                int pm25,
                                int pm10,
                                bool bug);

// 명령 폴링: 서버에서 JSON 명령을 GET으로 수신 후 처리
// 기대 JSON 예시: {"command":"PUMP_ON"} 또는 {"command":"WINDOW_OPEN"}
// 처리 결과를 로그로 남기며, 인식 불가 시 ESP_OK로 반환하되 경고 로그 출력
esp_err_t poll_command_and_handle(void);

#ifdef __cplusplus
}
#endif