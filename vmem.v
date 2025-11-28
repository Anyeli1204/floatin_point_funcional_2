module vmem(
    input clk, we,
    input[31:0] addr_a, addr_b, addr_c, wd,
    output [31:0] rv_a, rv_b
    );

    reg [31:0] VEC_RAM[1023:0];
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            VEC_RAM[i] = 32'd0;
        end
        $readmemh("data_vec.txt", VEC_RAM);
    end

    assign rv_a = VEC_RAM[addr_a[31:2]]; // word aligned
    assign rv_b = VEC_RAM[addr_b[31:2]]; // word aligned

    wire [31:0] rv_c = VEC_RAM[addr_c[31:2]]; // word aligned
    wire [31:0] sum = rv_c + wd;

    always @(posedge clk) begin
        if(we) VEC_RAM[addr_c[31:2]] <= sum;
    end

endmodule