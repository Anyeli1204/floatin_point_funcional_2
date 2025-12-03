// MEM/WB Pipeline Register (con soporte para floating point)
module MEM_WB(input clk, reset,
                 input [31:0] ALUResultM, ReadDataM, PCPlus4M,
                 input [4:0] RdM,
                 input RegWriteM,
                 input [1:0] ResultSrcM,
                 // Señales FP
                 input FPRegWriteM,
                 input [31:0] FALUResultM,  // Resultado ALU FP desde MEM
                 // Señales vectoriales
                 input isMatmulM,
                 input VRegWriteM,
                 input [31:0] InstrM,  // Instrucción para debugging
                 output reg [31:0] ALUResultW, ReadDataW, PCPlus4W,
                 output reg [4:0] RdW,
                 output reg RegWriteW,
                 output reg [1:0] ResultSrcW,
                 // Salidas FP
                 output reg FPRegWriteW,
                 output reg [31:0] FALUResultW,  // Resultado ALU FP hacia WB
                 // Salidas vectoriales
                 output reg isMatmulW,
                 output reg VRegWriteW,
                 output reg [31:0] InstrW  // Instrucción para debugging
);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ALUResultW <= 0;
      ReadDataW <= 0;
      PCPlus4W <= 0;
      RdW <= 0;
      RegWriteW <= 0;
      ResultSrcW <= 0;
      FPRegWriteW <= 0;
      FALUResultW <= 0;
      isMatmulW <= 0;
      VRegWriteW <= 0;
      InstrW <= 32'h00000013;  // NOP para debugging
    end else begin
      ALUResultW <= ALUResultM;
      ReadDataW <= ReadDataM;
      PCPlus4W <= PCPlus4M;
      RdW <= RdM;
      RegWriteW <= RegWriteM;
      ResultSrcW <= ResultSrcM;
      FPRegWriteW <= FPRegWriteM;
      FALUResultW <= FALUResultM;
      isMatmulW <= isMatmulM;
      VRegWriteW <= VRegWriteM;
      InstrW <= InstrM;  // Propagación de instrucción
    end
  end
endmodule
