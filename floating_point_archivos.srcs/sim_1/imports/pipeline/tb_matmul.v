`timescale 1ns/1ps

module tb_matmul;

    reg clk;
    reg reset;

    matmultop uut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        #10;
        reset = 0;
    end

    initial begin
        $dumpfile("vector_wf.vcd");
        $dumpvars(0, tb_matmul);   
    end

endmodule
