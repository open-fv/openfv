# Hello-world *-opt tool: proves the pinned CIRCT links and runs (P0.3 accept).
add_llvm_executable(rtl-lowering-opt rtl-lowering-opt.cpp)
llvm_update_compile_flags(rtl-lowering-opt)
target_link_libraries(rtl-lowering-opt PRIVATE
  MLIROptLib
  MLIRIR
  MLIRSupport
  CIRCTHW
  CIRCTComb
  CIRCTSeq
)
