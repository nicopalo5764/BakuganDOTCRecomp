// See discord_rpc.h for setup steps (Discord application ID + art asset).

#include "discord_rpc.h"

#ifdef _WIN32

#include <windows.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <string>
#include <thread>

namespace discord {

namespace {

// --- Configuration ---------------------------------------------------
// TODO: replace with your own Discord application's ID (Developer Portal ->
// General Information -> "Application ID") and the art asset key you
// uploaded under Rich Presence -> Art Assets for that application.
constexpr const char* kClientId = "1548887626272997466";
constexpr const char* kLargeImageKey = "icon";
constexpr const char* kLargeImageText = "Bakugan: Defenders of the Core";
constexpr const char* kDetails = "Bakugan: Defenders of the Core";
constexpr const char* kState = "Jugando";
// -----------------------------------------------------------------------

enum class Opcode : uint32_t {
  kHandshake = 0,
  kFrame = 1,
  kClose = 2,
  kPing = 3,
  kPong = 4,
};

std::atomic<bool> g_running{false};
std::thread g_thread;
HANDLE g_pipe = INVALID_HANDLE_VALUE;

void SleepInterruptible(int total_ms) {
  using namespace std::chrono_literals;
  int waited = 0;
  while (waited < total_ms && g_running.load(std::memory_order_relaxed)) {
    std::this_thread::sleep_for(200ms);
    waited += 200;
  }
}

bool WriteFrame(Opcode op, const std::string& payload) {
  if (g_pipe == INVALID_HANDLE_VALUE) return false;
  uint32_t op_le = static_cast<uint32_t>(op);
  uint32_t len_le = static_cast<uint32_t>(payload.size());
  DWORD written = 0;
  if (!WriteFile(g_pipe, &op_le, sizeof(op_le), &written, nullptr) || written != sizeof(op_le))
    return false;
  if (!WriteFile(g_pipe, &len_le, sizeof(len_le), &written, nullptr) || written != sizeof(len_le))
    return false;
  if (!payload.empty()) {
    if (!WriteFile(g_pipe, payload.data(), (DWORD)payload.size(), &written, nullptr) ||
        written != payload.size())
      return false;
  }
  return true;
}

// Reads and discards one frame. Returns false on disconnect.
bool ReadFrameDiscard() {
  if (g_pipe == INVALID_HANDLE_VALUE) return false;
  uint32_t op_le = 0, len_le = 0;
  DWORD read = 0;
  if (!ReadFile(g_pipe, &op_le, sizeof(op_le), &read, nullptr) || read != sizeof(op_le))
    return false;
  if (!ReadFile(g_pipe, &len_le, sizeof(len_le), &read, nullptr) || read != sizeof(len_le))
    return false;
  std::string buf;
  buf.resize(len_le);
  DWORD total = 0;
  while (total < len_le) {
    DWORD chunk = 0;
    if (!ReadFile(g_pipe, buf.data() + total, len_le - total, &chunk, nullptr) || chunk == 0)
      return false;
    total += chunk;
  }
  return true;
}

bool Connect() {
  for (int i = 0; i < 10; ++i) {
    std::string name = "\\\\.\\pipe\\discord-ipc-" + std::to_string(i);
    HANDLE h = CreateFileA(name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr,
                            OPEN_EXISTING, 0, nullptr);
    if (h != INVALID_HANDLE_VALUE) {
      g_pipe = h;
      return true;
    }
  }
  return false;
}

void Disconnect() {
  if (g_pipe != INVALID_HANDLE_VALUE) {
    CloseHandle(g_pipe);
    g_pipe = INVALID_HANDLE_VALUE;
  }
}

bool DoHandshake() {
  char payload[256];
  std::snprintf(payload, sizeof(payload), "{\"v\":1,\"client_id\":\"%s\"}", kClientId);
  if (!WriteFrame(Opcode::kHandshake, payload)) return false;
  // Discord replies with a FRAME carrying a READY dispatch; just drain it.
  return ReadFrameDiscard();
}

bool SendActivity(int64_t start_epoch_seconds) {
  unsigned long pid = GetCurrentProcessId();
  char payload[1024];
  std::snprintf(payload, sizeof(payload),
      "{\"cmd\":\"SET_ACTIVITY\",\"args\":{\"pid\":%lu,\"activity\":{"
      "\"details\":\"%s\",\"state\":\"%s\","
      "\"timestamps\":{\"start\":%lld},"
      "\"assets\":{\"large_image\":\"%s\",\"large_text\":\"%s\"}"
      "}},\"nonce\":\"bakugandotc-1\"}",
      pid, kDetails, kState, (long long)start_epoch_seconds, kLargeImageKey,
      kLargeImageText);
  return WriteFrame(Opcode::kFrame, payload);
}

void ClearActivity() {
  unsigned long pid = GetCurrentProcessId();
  char payload[256];
  std::snprintf(payload, sizeof(payload),
      "{\"cmd\":\"SET_ACTIVITY\",\"args\":{\"pid\":%lu},\"nonce\":\"bakugandotc-clear\"}", pid);
  WriteFrame(Opcode::kFrame, payload);
}

void ThreadMain() {
  const int64_t start_epoch =
      std::chrono::duration_cast<std::chrono::seconds>(
          std::chrono::system_clock::now().time_since_epoch())
          .count();

  while (g_running.load(std::memory_order_relaxed)) {
    if (g_pipe == INVALID_HANDLE_VALUE) {
      if (!Connect()) {
        SleepInterruptible(15000);
        continue;
      }
      if (!DoHandshake() || !SendActivity(start_epoch)) {
        Disconnect();
        SleepInterruptible(15000);
        continue;
      }
    }

    // Idle: make sure the pipe is still alive. If Discord closed it (e.g.
    // Discord quit), drop it and let the loop above reconnect later.
    DWORD avail = 0;
    if (g_pipe != INVALID_HANDLE_VALUE &&
        PeekNamedPipe(g_pipe, nullptr, 0, nullptr, &avail, nullptr)) {
      if (avail > 0) {
        if (!ReadFrameDiscard()) Disconnect();
      }
    } else {
      Disconnect();
    }
    SleepInterruptible(5000);
  }

  if (g_pipe != INVALID_HANDLE_VALUE) {
    ClearActivity();
    Disconnect();
  }
}

}  // namespace

void Start() {
  bool expected = false;
  if (!g_running.compare_exchange_strong(expected, true)) return;
  g_thread = std::thread(ThreadMain);
}

void Stop() {
  if (!g_running.exchange(false)) return;
  if (g_thread.joinable()) g_thread.join();
}

}  // namespace discord

#else  // !_WIN32

namespace discord {
void Start() {}
void Stop() {}
}  // namespace discord

#endif
