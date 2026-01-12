`timescale 1ns/1ps
module top_lmul (
    input  wire        clk,
    input  wire        rstn,
    input  wire [15:0] i_a,
    input  wire [15:0] i_b,
    output wire [15:0] o_p
);

    // Instantiate lmul_bf16
    lmul_bf16 #(
        .E_BITS(8),
        .M_BITS(7),
        .EM_BITS(15),
        .BITW(16)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        // Removed handshake signals
        .i_a(i_a),
        .i_b(i_b),
        .o_p(o_p)
    );

endmodule
