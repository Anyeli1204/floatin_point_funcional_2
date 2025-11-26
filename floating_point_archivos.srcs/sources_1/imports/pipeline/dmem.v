module dmem(input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);
  
  reg [31:0] RAM[63:0]; 
  integer i;

  initial begin
    // Inicializar memoria vacía 
    for (i = 0; i < 64; i = i + 1)
      RAM[i] = 32'h00000000;
    
    // Inicializar algunos valores FP para pruebas
    // IEEE-754 Single Precision (32 bits)
    RAM[0] = 32'h3F800000;  // 1
    RAM[1] = 32'h40000000;  // 2.0
    RAM[2] = 32'h3FC00000;  // 0.0
    RAM[3] = 32'h3FC00000;  // 1.5
    RAM[4] = 32'h3F800000;  // 1
    RAM[5] = 32'h3F400000;  // 0.75
    RAM[6] = 32'h40800000;  // 4.0
    RAM[7] = 32'h00000000;  // 0.0
    RAM[8] = 32'hBF800000;  // -1.0
    RAM[9] = 32'h7FC00000;  // NaN (quiet NaN)
    RAM[10] = 32'h7F800000; // +Infinity
    RAM[11] = 32'h40A00000; // 5.0
  end

  assign rd = RAM[a[31:2]]; // word aligned

  always @(posedge clk) begin 
    if (we) RAM[a[31:2]] <= wd; 
  end
endmodule