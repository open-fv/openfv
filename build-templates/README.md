# build-templates/ — per-repo CMake builds for the CIRCT-dependent repos

These are the **P0.3** deliverables that belong in the three CIRCT-dependent
Tier-1 repos: `rtl-lowering`, `sva-frontend`, `btor2-emit`. They live here in
the flagship because, at the time P0.3 was done, **P0.1 had not yet created
those repos as submodules** (no `.gitmodules` exists). When P0.1 lands and the
repos are created, copy each `build-templates/<repo>/` tree into the root of
the matching submodule repo — unchanged. Nothing here is flagship-specific.

> **Dependency note for whoever does P0.1:** these builds expect the flagship
> checkout (which carries `versions.txt` and `cmake/`) to be the parent
> directory of the submodule, which is the layout PROJECT_PLAN.md §2 describes
> ("flagship pulls the others in as submodules"). If your layout differs, pass
> `-DOPENFV_FLAGSHIP_DIR=/path/to/openfv` at configure time.

## What each repo gets

```
<repo>/
  CMakeLists.txt              # finds pinned CIRCT (via cmake/OpenfvCIRCT.cmake), ccache
  tools/<repo>-opt/
    CMakeLists.txt
    <repo>-opt.cpp            # hello-world MLIR opt tool registering CIRCT dialects
```

## Build (after `scripts/bootstrap-circt.sh` has installed CIRCT)

```sh
export OPENFV_DEPS_PREFIX=/path/to/openfv/.openfv-deps/install
cmake -G Ninja -S <repo> -B <repo>/build
cmake --build <repo>/build
<repo>/build/bin/<repo>-opt --help        # hello-world: prints, exits 0
echo 'hw.module @top() {}' | <repo>/build/bin/<repo>-opt   # round-trips HW IR
```

See [`../docs/BUILDING.md`](../docs/BUILDING.md) for the full from-scratch recipe.

## Status of the link line

The `*-opt` tools register and link CIRCT's `HW`/`Comb`/`Seq` dialects — the
minimal set that proves the pinned CIRCT links and runs. The exact target names
are CIRCT's stable exported library targets (`CIRCTHW`, `CIRCTComb`,
`CIRCTSeq`). The first `bootstrap-circt.sh` + configure validates them against
the actual pinned install; if CIRCT renames an exported target at a future pin
bump, fix it here as part of that bump (engineering, not a semantic change).
