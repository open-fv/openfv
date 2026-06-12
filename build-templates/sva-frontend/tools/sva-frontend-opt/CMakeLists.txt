# Hello-world *-opt tool: proves the pinned CIRCT links and runs (P0.3 accept).
add_llvm_executable(sva-frontend-opt sva-frontend-opt.cpp)
llvm_update_compile_flags(sva-frontend-opt)
target_link_libraries(sva-frontend-opt PRIVATE
  MLIROptLib
  MLIRIR
  MLIRSupport
  CIRCTHW
  CIRCTComb
  CIRCTSeq
)
