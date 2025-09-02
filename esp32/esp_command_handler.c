#include <string.h>
#include "esp_log.h"
#include "esp_http_pull.h"  // esp_handle_command weak 심볼을 오버라이드

static const char *TAG_CMD = "CMD";

// esp32.c에 정의된 함수/변수들을 extern으로 참조(esp32.c는 수정하지 않음)
extern void open_window(void);
extern void close_window(void);
extern void activatePump(void);

extern int is_window;     // 0=닫힘, 1=열림
extern char pump;         // "ON" 또는 "OFF"의 첫 글자만 참조할 수 있으므로 주의

// 약한 기본 구현을 대체하여 실제 하드웨어 동작 수행
void esp_handle_command(const char *command)
{
	if (command == NULL) {
		ESP_LOGW(TAG_CMD, "NULL command");
		return;
	}

	ESP_LOGI(TAG_CMD, "Handle command: %s", command);

	if (strcmp(command, "WINDOW_OPEN") == 0) {
		open_window();
		return;
	}
	if (strcmp(command, "WINDOW_CLOSE") == 0) {
		close_window();
		return;
	}
	if (strcmp(command, "PUMP_ON") == 0) {
		activatePump();
		return;
	}
	if (strcmp(command, "PUMP_OFF") == 0) {
		// esp32.c에 펌프 OFF 구현이 별도로 없으므로 로그만 표시
		ESP_LOGI(TAG_CMD, "Pump OFF requested (no-op; implement if needed)");
		return;
	}

	ESP_LOGW(TAG_CMD, "Unknown command: %s", command);
}