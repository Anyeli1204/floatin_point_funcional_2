// MEM/WB Pipeline Register (sin floating point)
module MEM_WB(input clk, reset,
                 input [31:0] ALUResultM, ReadDataM, PCPlus4M,
                 input [4:0] RdM,
                 input RegWriteM,
                 input [1:0] ResultSrcM,
                 output reg [31:0] ALUResultW, ReadDataW, PCPlus4W,
                 output reg [4:0] RdW,
                 output reg RegWriteW,
                 output reg [1:0] ResultSrcW);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ALUResultW <= 0;
      ReadDataW <= 0;
      PCPlus4W <= 0;
      RdW <= 0;
      RegWriteW <= 0;
      ResultSrcW <= 0;
    end else begin
      ALUResultW <= ALUResultM;
      ReadDataW <= ReadDataM;
      PCPlus4W <= PCPlus4M;
      RdW <= RdM;
      RegWriteW <= RegWriteM;
      ResultSrcW <= ResultSrcM;
    end
  end
endmodule
