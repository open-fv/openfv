// SPDX-License-Identifier: Apache-2.0
// Intentionally broken SystemVerilog — parse error fixture for P0.7 tests.
// The semicolon after the module port list is missing; slang will report
// a parse error with a source location.
module broken (
    input  logic clk
    output logic q    // missing comma before this line AND missing semicolon
endmodule
