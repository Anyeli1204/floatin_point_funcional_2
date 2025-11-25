// ID/EX Pipeline Register con Flush (sin floating point)
module ID_EX(input clk, reset,
                input FlushE,  // Señal de flush (insertar burbuja)
                input [31:0] RD1D, RD2D, PCD,
                input [4:0] Rs1D, Rs2D, RdD,
                input [31:0] ImmExtD, PCPlus4D,
                input RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD,
                input [1:0] ResultSrcD,
                input [2:0] ALUControlD,
                output reg [31:0] RD1E, RD2E, PCE,
                output reg [4:0] Rs1E, Rs2E, RdE,
                output reg [31:0] ImmExtE, PCPlus4E,
                output reg RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE,
                output reg [1:0] ResultSrcE,
                output reg [2:0] ALUControlE);

  always @(posedge clk) begin
    if (reset || FlushE) begin  // Reset o Flush = insertar NOP
      RD1E <= 0;
      RD2E <= 0;
      PCE <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      ImmExtE <= 0;
      PCPlus4E <= 0;
      RegWriteE <= 0;  // IMPORTANTE: Deshabilitar escritura
      MemWriteE <= 0;  // IMPORTANTE: Deshabilitar escritura a memoria
      JumpE <= 0;
      BranchE <= 0;
      ALUSrcE <= 0;
      ResultSrcE <= 0;
      ALUControlE <= 0;
    end else begin
      RD1E <= RD1D;
      RD2E <= RD2D;
      PCE <= PCD;
      Rs1E <= Rs1D;
      Rs2E <= Rs2D;
      RdE <= RdD;
      ImmExtE <= ImmExtD;
      PCPlus4E <= PCPlus4D;
      RegWriteE <= RegWriteD;
      MemWriteE <= MemWriteD;
      JumpE <= JumpD;
      BranchE <= BranchD;
      ALUSrcE <= ALUSrcD;
      ResultSrcE <= ResultSrcD;
      ALUControlE <= ALUControlD;
    end
  end
endmodule
