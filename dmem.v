module dmem(input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);
  
  reg [31:0] RAM[63:0]; 
  integer i;

  initial begin
    // Inicializar memoria vacía 
    for (i = 0; i < 64; i = i + 1)
      RAM[i] = 32'h00000000;
  end

  assign rd = RAM[a[31:2]]; // word aligned

  always @(posedge clk) begin 
    if (we) RAM[a[31:2]] <= wd; 
  end
endmodule