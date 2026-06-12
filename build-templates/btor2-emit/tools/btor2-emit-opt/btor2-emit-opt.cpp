//===- btor2-emit-opt.cpp - openfv hello-world CIRCT opt tool -----------===//
//
// P0.3 acceptance smoke test: a minimal MLIR `*-opt` driver built against the
// pinned CIRCT (versions.txt). It registers CIRCT's HW/Comb/Seq dialects and
// runs the standard MlirOptMain loop, so `--help` exits 0 and HW IR round-trips
// through `--parse`. Real lowering passes are registered here as P1.x lands.
//
// Clean-room: written from MLIR/CIRCT public headers only; no copied code.
//
//===----------------------------------------------------------------------===//

#include "circt/Dialect/Comb/CombDialect.h"
#include "circt/Dialect/HW/HWDialect.h"
#include "circt/Dialect/Seq/SeqDialect.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  registry.insert<circt::hw::HWDialect, circt::comb::CombDialect,
                  circt::seq::SeqDialect>();
  return mlir::asMainReturnCode(mlir::MlirOptMain(
      argc, argv, "btor2-emit-opt -- openfv BTOR2-emit driver\n", registry));
}
