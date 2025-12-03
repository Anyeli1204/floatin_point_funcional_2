module matmultop (
    input clk,
    input reset //,
    //input [31:0] ADDR_A_fp, ADDR_B_fp, ADDR_C_fp,
    //input is_matmul_op
);

    /*
    wire [31:0] ADDR_A, ADDR_B, ADDR_C;

    // --- Instancias de conversión FP → UINT ---
    fp_to_uint convA(.fp(ADDR_A_fp), .u(ADDR_A));
    fp_to_uint convB(.fp(ADDR_B_fp), .u(ADDR_B));
    fp_to_uint convC(.fp(ADDR_C_fp), .u(ADDR_C));
    */
    
    localparam ADDR_A = 32'd0;          
    localparam ADDR_B = 32'd32;    
    localparam ADDR_C = 32'd80;
    localparam is_matmul_op = 1'b1;
    

    matmul uut_matmul (
        .clk    (clk),
        .reset  (reset),
        .addr_a (ADDR_A),
        .addr_b (ADDR_B),
        .addr_c (ADDR_C),
        .is_matmul_op (is_matmul_op)
    );

endmodule