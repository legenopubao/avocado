#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#include "esp_err.h"
#include "esp_log.h"
#include "esp_http_client.h"
#include "esp_http_pull.h"

// Flutter 서버(또는 백엔드) HTTP 엔드포인트 URL을 설정하세요.
// 예: http://192.168.0.10:8080/air-quality 또는 https://your.domain/api/air
// URL 매크로는 esp_http_pull.h에서 기본값을 제공합니다.

static const char *TAG = "AIR_HTTP";

// temperature, humidity, pm25, pm10, bug 값을 JSON으로 POST 전송
esp_err_t send_air_quality_data(float temperature,
                                float humidity,
                                int pm25,
                                int pm10,
                                bool bug)
{
    // JSON 페이로드 구성
    // {"temperature": 23.5, "humidity": 40.2, "pm25": 12, "pm10": 25, "bug": false}
    char json_payload[192];
    int written = snprintf(
        json_payload,
        sizeof(json_payload),
        "{\"temperature\":%.2f,\"humidity\":%.2f,\"pm25\":%d,\"pm10\":%d,\"bug\":%s}",
        temperature,
        humidity,
        pm25,
        pm10,
        bug ? "true" : "false");

    if (written <= 0 || written >= (int)sizeof(json_payload)) {
        ESP_LOGE(TAG, "JSON 직렬화 실패 또는 버퍼 초과");
        return ESP_FAIL;
    }

    esp_http_client_config_t config = {
        .url = AIR_QUALITY_POST_URL,
        .method = HTTP_METHOD_POST,
        .timeout_ms = 5000,
    };

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        ESP_LOGE(TAG, "HTTP 클라이언트 초기화 실패");
        return ESP_FAIL;
    }

    esp_err_t err = ESP_OK;

    // 헤더 및 바디 설정
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_http_client_set_header(client, "Content-Type", "application/json"));
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_http_client_set_post_field(client, json_payload, strlen(json_payload)));

    err = esp_http_client_perform(client);
    if (err == ESP_OK) {
        int status_code = esp_http_client_get_status_code(client);
        int content_length = esp_http_client_get_content_length(client);
        ESP_LOGI(TAG, "POST 완료, status=%d, length=%d", status_code, content_length);
        if (status_code < 200 || status_code >= 300) {
            ESP_LOGW(TAG, "서버 비정상 응답 코드: %d", status_code);
            err = ESP_FAIL;
        }
    } else {
        ESP_LOGE(TAG, "HTTP 요청 실패: %s", esp_err_to_name(err));
    }

    esp_http_client_cleanup(client);
    if (err != ESP_OK) {
        return err;
    }

#if AIR_POLL_AFTER_POST
    // POST 성공 시 즉시 명령 폴링 시도
    esp_err_t poll_res = poll_command_and_handle();
    if (poll_res != ESP_OK) {
        ESP_LOGW(TAG, "Command poll after POST failed: %s", esp_err_to_name(poll_res));
    }
#endif

    return ESP_OK;
}

// 사용 예시
// esp_err_t res = send_air_quality_data(temperature, humidity, pm25, pm10, bug);
// if (res != ESP_OK) { /* 재시도 또는 오류 처리 */ }

// ========== 명령 폴링 구현(GET) ==========
// 기대 JSON: {"command":"PUMP_ON"} 등. 여기서는 문자열 비교만 수행.
// 실제 하드웨어 제어 함수는 상위(esp32.c)에서 제공된다고 가정하지 않고,
// 우선은 로그만 남기도록 기본 구현. 필요 시 약한 심볼(weak) 훅으로 연결 가능.

// 약한 훅: 상위 애플리케이션이 구현하면 해당 함수를 호출해 실제 동작
__attribute__((weak)) void esp_handle_command(const char *command) {
    // 기본 구현: 로그만 출력
    ESP_LOGI(TAG, "Received command (default handler): %s", command);
}

esp_err_t poll_command_and_handle(void)
{
    esp_http_client_config_t config = {
        .url = AIR_COMMAND_PULL_URL,
        .method = HTTP_METHOD_GET,
        .timeout_ms = 4000,
    };

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        ESP_LOGE(TAG, "HTTP client init failed (poll)");
        return ESP_FAIL;
    }

    esp_err_t err = esp_http_client_perform(client);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "HTTP GET failed: %s", esp_err_to_name(err));
        esp_http_client_cleanup(client);
        return err;
    }

    int status_code = esp_http_client_get_status_code(client);
    int content_length = esp_http_client_get_content_length(client);
    ESP_LOGI(TAG, "POLL status=%d, length=%d", status_code, content_length);

    if (status_code == 204) { // No Content
        esp_http_client_cleanup(client);
        return ESP_OK;
    }

    // 본문 읽기
    char buf[256];
    int total_read = 0;
    while (1) {
        int r = esp_http_client_read(client, buf + total_read, sizeof(buf) - 1 - total_read);
        if (r <= 0) break;
        total_read += r;
        if (total_read >= (int)sizeof(buf) - 1) break;
    }
    buf[total_read] = '\0';

    ESP_LOGI(TAG, "POLL body: %s", buf);

    // 매우 단순한 파싱: "command":"XXXX" 검색
    const char *key = "\"command\"\s*:\s*\"";
    const char *p = strstr(buf, "\"command\"");
    if (p) {
        p = strchr(p, '"'); // 첫 따옴표
        if (p) p = strchr(p + 1, '"'); // key 끝 따옴표
        if (p) {
            p = strchr(p + 1, '"'); // 값 시작 따옴표
            if (p) {
                const char *start = p + 1;
                const char *end = strchr(start, '"');
                if (end && end > start) {
                    char cmd[64];
                    size_t n = (size_t)(end - start);
                    if (n >= sizeof(cmd)) n = sizeof(cmd) - 1;
                    memcpy(cmd, start, n);
                    cmd[n] = '\0';
                    esp_handle_command(cmd);
                }
            }
        }
    } else {
        ESP_LOGW(TAG, "No 'command' field in response");
    }

    esp_http_client_cleanup(client);
    return ESP_OK;
}
