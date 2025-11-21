module imem(input  [31:0] a,
            output [31:0] rd);
  
  reg [31:0] RAM[63:0]; 
  integer i;

  initial begin
      // Initialize all memory with NOPs
      for (i = 0; i < 64; i = i + 1)
        RAM[i] = 32'h00000013;  // NOP instruction
      
      // Cargar programa desde archivo
      $readmemh("riscvtest.txt", RAM); 
  end

  assign rd = RAM[a[31:2]]; // word aligned
endmodule