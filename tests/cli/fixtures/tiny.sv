// SPDX-License-Identifier: Apache-2.0
// Minimal SystemVerilog module — parse/elaboration fixture for P0.7 tests.
// Written clean-room; no external source consulted.
module tiny (
    input  logic clk,
    input  logic rst_n,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule
