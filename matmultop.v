module matmultop (
    input clk,
    input reset
);

    localparam ADDR_A = 32'd0;      
    localparam ADDR_B = 32'd32;    
    localparam ADDR_C = 32'd80;

    matmul uut_matmul (
        .clk    (clk),
        .reset  (reset),
        .addr_a (ADDR_A),
        .addr_b (ADDR_B),
        .addr_c (ADDR_C)
    );

endmodule
