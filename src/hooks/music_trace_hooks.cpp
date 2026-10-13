// Temporary downstream music diagnostics. Always call the original guest code.
#include "bakugandotc_funcs.h"
#include <rex/hook.h>
#include <rex/memory.h>
#include <atomic>
#include <algorithm>
#include <bit>
#include <cmath>

REX_HOOK_RAW(sub_8247EAB0) {
  const uint32_t voice = ctx.r3.u32;
  const uint32_t format = REX_LOAD_U32(voice + 56);
  const uint32_t channels = format ? REX_LOAD_U32(format) : REX_LOAD_U32(voice + 64);
  if (channels == 2) {
    REXAPU_INFO("[MUSIC TRACE] SetVolume voice={:08X} caller={:08X} volume={} r4={:08X} r5={:08X}",
      voice, uint32_t(ctx.lr), ctx.f1.f64, ctx.r4.u32, ctx.r5.u32);
  }
  __imp__sub_8247EAB0(ctx, base);
}

REX_HOOK_RAW(sub_824ADE50) {
  const uint32_t samples = ctx.r4.u32;
  __imp__sub_824ADE50(ctx, base);
  static std::atomic<unsigned> frames{0};
  if (frames.fetch_add(1) % 188 != 0) return;
  float peaks[6]{};
  for (unsigned channel = 0; channel < 6; ++channel)
    for (unsigned i = 0; i < 256; ++i)
      peaks[channel] = std::max(peaks[channel], std::abs(std::bit_cast<float>(
        REX_LOAD_U32(samples + (channel * 256 + i) * 4))));
  REXAPU_INFO("[MUSIC TRACE] final mix peaks FL={} FR={} FC={} LFE={} SL={} SR={}",
    peaks[0], peaks[1], peaks[2], peaks[3], peaks[4], peaks[5]);
}

REX_HOOK_RAW(sub_82480CB0) {
  __imp__sub_82480CB0(ctx, base);
  static std::atomic<unsigned> ticks{0};
  if (ticks.fetch_add(1) % 100 != 0) return;
  for (unsigned i = 0; i < 320; ++i) {
    const uint32_t pool = REX_LOAD_U32(0x826AFAB8 + i * 4);
    if (!pool) continue;
    const uint32_t count = REX_LOAD_U32(pool);
    const uint32_t entries = REX_LOAD_U32(pool + 8);
    for (unsigned j = 0; j < count && j < 8; ++j) {
      const uint32_t context = REX_LOAD_U32(entries + j * 96 + 64);
      if (!context) continue;
      const uint32_t w0 = REX_LOAD_U32(context);
      const uint32_t w1 = REX_LOAD_U32(context + 4);
      const uint32_t output = REX_LOAD_U32(context + 28);
      const unsigned blocks = (w0 >> 22) & 31;
      if (!output || !blocks) continue;
      const auto* pcm = REX_KERNEL_MEMORY()->TranslatePhysical<uint8_t*>(output);
      unsigned peak = 0;
      for (unsigned k = 0; k < blocks * 256; k += 2) {
        const int value = int16_t((uint16_t(pcm[k]) << 8) | pcm[k + 1]);
        peak = std::max(peak, unsigned(value < 0 ? -value : value));
      }
      REXAPU_INFO("[MUSIC TRACE] XMA ctx={:08X} stereo={} valid={} in_valid={} in_bits={} error={} out={:08X} blocks={} read={} write={} peak={}",
        context, (w1 >> 29) & 1, w1 >> 31, (w0 >> 20) & 3,
        REX_LOAD_U32(context + 8) & 0x3FFFFFF, (REX_LOAD_U32(context + 8) >> 26) & 31,
        output, blocks, REX_LOAD_U32(context + 36) & 31, w0 >> 27, peak);
    }
  }
}

REX_HOOK_RAW(sub_8247F4B0) {
  const uint32_t voice = ctx.r3.u32;
  const uint32_t format = REX_LOAD_U32(voice + 52);
  const uint32_t channels = format ? REX_LOAD_U32(format) : REX_LOAD_U32(voice + 60);
  static std::atomic<unsigned> logs{0};
  if (channels == 2 && logs.fetch_add(1) < 100) {
    const uint32_t engine = REX_LOAD_U32(voice + 48);
    REXAPU_INFO("[MUSIC TRACE] stereo gain voice={:08X} flags={:08X} gain={} category={} left={} right={}",
      voice, REX_LOAD_U32(voice + 56), std::bit_cast<float>(REX_LOAD_U32(voice + 72)),
      std::bit_cast<float>(REX_LOAD_U32(engine + 528)),
      std::bit_cast<float>(REX_LOAD_U32(ctx.r5.u32)), std::bit_cast<float>(REX_LOAD_U32(ctx.r5.u32 + 4)));
  }
  __imp__sub_8247F4B0(ctx, base);
}
