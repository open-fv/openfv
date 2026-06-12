# Building openfv from scratch

This is the **P0.3** from-scratch recipe: a fresh Ubuntu LTS machine, followed
verbatim, ends with the pinned CIRCT installed and all three CIRCT-dependent
repos (`rtl-lowering`, `sva-frontend`, `btor2-emit`) building and running their
hello-world `*-opt` tools.

All upstream SHAs come from one place — [`../versions.txt`](../versions.txt).
Nothing below hard-codes a SHA; the scripts read that file. Bumping a pin is a
single-file edit there (see the bump procedure in `versions.txt`).

> **Status / scope note.** At the time this was written, the three CIRCT repos
> did not yet exist as submodules (task **P0.1** had not run). Their build files
> are staged under [`../build-templates/`](../build-templates/); once P0.1
> creates the submodules, copy each `build-templates/<repo>/` into the matching
> repo root. The commands below assume that layout (flagship as the parent of
> each submodule). Until then, you can still exercise the per-repo build by
> pointing `-S` at `build-templates/<repo>` and passing
> `-DOPENFV_FLAGSHIP_DIR=$(pwd)`.

---

## 0. What gets built, and why only once

CIRCT (with the slang Verilog frontend) is the heavy dependency — a from-cold
build is on the order of an hour. We build it **once** into a shared install
prefix and have every repo `find_package` against it. The three repos do **not**
each rebuild CIRCT. This is what keeps warm CI builds inside the P0.4 budget.

```
versions.txt  ──►  scripts/bootstrap-circt.sh  ──►  $OPENFV_DEPS_PREFIX  ──►  each repo's cmake
 (the pin)          (build CIRCT+LLVM+slang once)    (CIRCT/MLIR install)      (find_package + link)
```

---

## 1. System packages (Ubuntu 22.04 / 24.04 LTS)

```sh
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  ninja-build \
  ccache \
  git \
  python3 python3-pip \
  zlib1g-dev libzstd-dev \
  lld
```

Requirements the above satisfies, for the record:

- **CMake ≥ 3.20** (22.04 ships 3.22, 24.04 ships 3.28 — both fine).
- **A C++20 compiler.** slang requires C++20; Ubuntu 22.04's `g++-11` and
  24.04's `g++-13` both qualify. If your default `g++` is older, install a newer
  one and pass `-DCMAKE_CXX_COMPILER=g++-13` to the bootstrap configure step.
- **ccache**, **ninja**, **git**, **python3** (LLVM/MLIR build + lit tests).
- **zlib/zstd** (LLVM compression deps), **lld** (faster linking; optional but
  recommended for the LLVM link step).

---

## 2. Clone the flagship (with submodules, once they exist)

```sh
git clone https://github.com/openfv/openfv.git
cd openfv
git submodule update --init --recursive   # no-op until P0.1 adds submodules
```

---

## 3. Build the pinned CIRCT once

```sh
# Optional: choose where the dependency install lives (default: ./.openfv-deps/install)
export OPENFV_DEPS_PREFIX="$PWD/.openfv-deps/install"

scripts/bootstrap-circt.sh --jobs "$(nproc)"
```

What the script does (all driven by `versions.txt`):

1. Clones `llvm/circt` at `CIRCT_SHA` and inits its `llvm` submodule, then
   **asserts** that submodule equals `LLVM_SHA` (LLVM is a *derived* pin — if it
   mismatches, the script stops and tells you to fix `versions.txt`).
2. Configures an LLVM+MLIR+CIRCT build with:
   `-DCIRCT_SLANG_FRONTEND_ENABLED=ON -DCIRCT_SLANG_BUILD_FROM_SOURCE=ON`
   so CIRCT fetches and statically links slang `SLANG_TAG` itself (gives us
   `circt-verilog`, needed by P0.7), and `-DLLVM_CCACHE_BUILD=ON` when ccache is
   present.
3. Installs into `$OPENFV_DEPS_PREFIX` and writes
   `share/openfv/circt-pin.txt` recording the CIRCT SHA it built — the per-repo
   CMake later verifies the install matches the pin.

Re-running is cheap: ccache makes an unchanged-pin rebuild fast, and changing
`versions.txt` then re-running rebuilds against the new pin.

### ccache

The CIRCT build uses ccache via `-DLLVM_CCACHE_BUILD=ON`; each repo's own
compilation uses ccache as the compiler launcher (wired by
`cmake/OpenfvCIRCT.cmake`). To give it a generous cache and see hit rates:

```sh
ccache --max-size=20G
ccache --show-stats
```

---

## 4. Build the three CIRCT-dependent repos

With `OPENFV_DEPS_PREFIX` exported (step 3), each repo is a normal CMake build:

```sh
for repo in rtl-lowering sva-frontend btor2-emit; do
  cmake -G Ninja -S "$repo" -B "$repo/build"      # finds pinned CIRCT + ccache
  cmake --build "$repo/build" -j "$(nproc)"
done
```


---

## 5. Hello-world check (P0.3 acceptance)

Each repo produces a `*-opt` tool linked against the pinned CIRCT:

```sh
rtl-lowering/build/tools/rtl-lowering-opt/rtl-lowering-opt --help   # prints usage, exits 0
echo 'hw.module @top() {hw.output}' \
  | rtl-lowering/build/tools/rtl-lowering-opt/rtl-lowering-opt      # round-trips HW IR
```

The same for `sva-frontend/build/tools/sva-frontend-opt/sva-frontend-opt` and
`btor2-emit/build/tools/btor2-emit-opt/btor2-emit-opt`. All three link the
*same* CIRCT install, so the pin is identical everywhere — which is the point
of `versions.txt`.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `openfv: installed CIRCT (X) != pin (Y)` at configure | The install is stale relative to `versions.txt`. Re-run `scripts/bootstrap-circt.sh`. |
| `no pin stamp at .../share/openfv/circt-pin.txt` (warning) | CIRCT wasn't installed by `bootstrap-circt.sh`. Re-run it, or set `-DOPENFV_DEPS_PREFIX` to the right prefix. |
| Build dies mid-way on a memory-limited host (e.g. WSL: compiles `Killed`, or the whole WSL VM crashes with `Wsl/Service/E_UNEXPECTED`) | The big LLVM/MLIR translation units need ~1–2 GB *each*. Lower `--jobs` (8 on a 16 GB host), keep `OPENFV_LINK_JOBS=2`, and consider containing the build: `systemd-run --user --scope -p MemoryMax=10G -p OOMPolicy=continue -- scripts/bootstrap-circt.sh --jobs 8`, then re-run to sweep up any OOM-killed stragglers (ninja/ccache make retries cheap). On WSL also set a Windows-side `.wslconfig` with an explicit `memory=` cap and `autoMemoryReclaim=gradual`. |
| `Could not find a package configuration file provided by "MLIR"/"CIRCT"` | `OPENFV_DEPS_PREFIX` not set/exported, or bootstrap didn't finish. |
| LLVM submodule SHA mismatch (bootstrap aborts) | `LLVM_SHA` in `versions.txt` is out of sync with `CIRCT_SHA`. Re-derive it (command is documented in `versions.txt`) and update the file. |
| C++20 errors building slang | Default compiler too old; install `g++-13`/`clang` and pass `-DCMAKE_CXX_COMPILER=...` to the bootstrap configure. |

### Escalation (per P0.3)

If building the pinned CIRCT **requires local patches** to compile, **do not
carry patches silently.** Stop and flag it for an upstream-first decision
(P0.3 *Escalate if*): either bump `CIRCT_SHA`/`LLVM_SHA` to a commit that builds
clean, or open the upstream fix. A patched, unpinnable CIRCT defeats the
reproducibility this task exists to guarantee.
