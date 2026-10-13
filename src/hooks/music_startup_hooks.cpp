// Bakugan's notification manager leaves its XMP state byte uninitialized.
// On Xbox it expects XN_XMP_STATECHANGED (0x0A000001) to supply the initial
// state. ReXGlue 0.10.0 starts XMP idle but does not enqueue this notification
// when the listener is created. The heap's 0xBE fill is then treated as true
// by sub_823BE578 -> sub_823C1310 -> sub_823D94D0, muting sounds whose bank
// flags include 0x02000000 (BGM) by setting their envelope to zero/state 4.
//
// Initialize only the missing startup state, before the original initializer
// creates the listener. sub_823A44E0 remains responsible for all subsequent
// XMP notifications. Do not force voice gains or bypass the envelope logic.
#include "bakugandotc_funcs.h"
#include <rex/hook.h>

REX_HOOK_RAW(sub_823A4838) {
  REX_STORE_U8(ctx.r3.u32 + 646, 0);
  REXAPU_INFO("[BGM FIX] Initialized external Xbox music state to idle");
  __imp__sub_823A4838(ctx, base);
}
