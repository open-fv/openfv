# Hello-world *-opt tool: proves the pinned CIRCT links and runs (P0.3 accept).
add_llvm_executable(btor2-emit-opt btor2-emit-opt.cpp)
llvm_update_compile_flags(btor2-emit-opt)
target_link_libraries(btor2-emit-opt PRIVATE
  MLIROptLib
  MLIRIR
  MLIRSupport
  CIRCTHW
  CIRCTComb
  CIRCTSeq
)
