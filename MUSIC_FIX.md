# Missing BGM: external Xbox music state was uninitialized

Investigation: 2026-09-17, ReXGlue 0.10.0, title 41560891.

## Root cause

The notification manager at `*(uint32_t*)0x826ACAB8` leaves byte `+646`
uninitialized. Neither its constructor (`sub_823A5258`) nor its initializer
(`sub_823A4838`) initializes this byte. `sub_823A44E0` sets it on receipt of
XMP state notification `0x0A000001`, using `notification_parameter != 0`.

The bundled runtime starts XMP idle, but `KernelState::RegisterNotifyListener`
does not send an initial XMP state notification. In the observed run, the byte
was `0xBE` (190), not zero. The startup log contains system notifications and
XMP controller notifications (`0x0A000003`), but no XMP state notification.

`sub_823BE578` reads this byte and passes it through `sub_823C1310` to
`sub_823D94D0`. For sounds marked `0x02000000` in the bank flags, a nonzero
value means external music is active. The game sets the volume envelope to
zero and state 4 (sustain), muting BGM indefinitely.

## Evidence before the fix

The read-only process probe captured the following in the title/menu session:

- Notification manager `7018E560`, external music byte = 190.
- Stereo BGM voice `400F0020`, category gain = 1, requested gain = 1.
- Attack/decay/release = 100, sustain = 1, but envelope = 0, state = 4.
- Bank gain = 0.43137258, resulting voice gain = 0.
- XMA produced nonzero PCM and advanced its input/output offsets, error = 0.
- All six final mix channels measured zero while only BGM was playing.
- `SetVolume` callers: `823E2D14` (expected initial mute when creating the
  voice), then `823D980C` (the update that should have raised its volume).

Snapshot: `out/build/win-amd64-release/logs/music-before-fix.json`.
Runtime evidence: `bakugandotc_002*.log`, `bakugandotc_003.log`,
`bakugandotc_005*.log` in the same directory. The old baseline log was copied
to `baseline-20260914.txt` before testing.

## Fix

`src/hooks/music_startup_hooks.cpp` hooks `sub_823A4838` and initializes only
byte `+646` to zero before calling the original guest initializer. This
matches ReXGlue's initial idle XMP state. Subsequent notifications still run
through the original handler; no per-frame forcing of volumes or envelope
state is involved. Generated code and the installed SDK remain untouched.

The startup line `[BGM FIX] Initialized external Xbox music state to idle`
identifies the corrected build. A successful build alone does not establish
audible playback; the post-fix playtest is tracked below.

## Validation

- Release compilation/link: passed with the installed SDK.
- XEX control flow and field initialization: verified against the user's IDA
  database through its local MCP server.
- Post-fix runtime check: passed in the user's launched build, process 10864.
  External music is now 0; stereo BGM bank flags `1E000000` have envelope 1,
  calculated gain 1 and voice gain 0.5294118 (previously 0).
  The final mix now has nonzero samples; for example at 18:22:33 in
  `bakugandotc_006*.log`, FL=0.32645264 and FR=0.31540808. The original volume
  update also performs gradual fades during transitions.
  Snapshot: `out/build/win-amd64-release/logs/music-after-fix.json`.
- User confirmed on 2026-09-17 that audio now plays correctly after the fix.
  Individual scenes were not separately enumerated in that confirmation.
- After the game exited, the normal Release executable was linked successfully
  with `BAKUGAN_MUSIC_TRACE=OFF`. It retains the same startup fix and excludes
  the additional diagnostic hooks. Selected post-fix log evidence is preserved
  in `out/build/win-amd64-release/logs/music-after-fix-trace.txt`.

`music-memory-probe.ps1 -GameProcessId <pid>` reads only the running game's
relevant guest memory (virtual base `0x100000000` for this runtime).
`src/hooks/music_trace_hooks.cpp` contains optional measurements for XMA
PCM peaks, final mix peaks, and stereo voice volume calls. Enable them with
`-DBAKUGAN_MUSIC_TRACE=ON`; normal builds default to OFF. The startup fix is
always compiled independently of that option.
