# Third-party notices

BakuganDOTCRecomp is an unofficial community project. Bakugan, its original
game code and assets, and related trademarks belong to their respective owners.
No license to those materials is granted by this repository.

`resources/bakugan.ico` is the existing Bakugan artwork supplied by the project
owner for the executable icons. It is not covered by the project's MIT license;
rights in that artwork remain with its respective owners.

The project uses ReXGlue, derived in part from Xenia. Their notices are retained
in `licenses/rexglue/LICENSE`. Additional license texts collected from the local
SDK source tree appear under `licenses/rexglue/thirdparty/`.

The source collection includes licenses for SDK dependencies and does not claim
that every listed dependency is linked into every build. Conversely, a list of
license texts alone is not a complete binary redistribution audit. See
`docs/DEPENDENCIES.md` for build provenance and source/relinking obligations
that must be checked before a public binary release.

The controller mapping database is supplied separately when packaging. Preserve
its embedded notices and verify its source (normally SDL_GameControllerDB).
The installer uses Inno Setup as a build tool; it is not vendored here.

Upstream projects:

- ReXGlue: https://github.com/rexglue/rexglue-sdk
- Xenia: https://github.com/xenia-project/xenia
- SDL: https://github.com/libsdl-org/SDL
- SDL_GameControllerDB: https://github.com/mdqinc/SDL_GameControllerDB

Original project additions are covered by the root LICENSE. Generated game
code is deliberately excluded from the public source export.
