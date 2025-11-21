// RISC-V Pipelined Processor (sin floating point)
// Estilo Bruno: controller fuera del datapath
module riscvpipeline(input  clk, reset,
                      output [31:0] PCF,
                      input  [31:0] InstrF,
                      output MemWriteM,
                      output [31:0] ALUResultM, WriteDataM,
                      input  [31:0] ReadDataM);

  // Internal pipeline control signals
  wire [1:0]  ResultSrcD;
  wire ALUSrcD;
  wire RegWriteD;
  wire MemWriteD;
  wire JumpD;
  wire BranchD;
  wire [2:0] ImmSrcD;  // 3 bits para soportar lui
  wire [2:0] ALUControlD;
  wire ZeroM;
  wire [31:0] InstrD;
  wire PCSrcM_unused;  // Not used in pipeline version (PCSrc se calcula en EX)

  // Controller instantiation (sin floating point)
  controller c(
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .Zero(ZeroM),
    .ResultSrc(ResultSrcD),
    .MemWrite(MemWriteD),
    .PCSrc(PCSrcM_unused),  // Calculated in datapath instead
    .ALUSrc(ALUSrcD),
    .RegWrite(RegWriteD),
    .Jump(JumpD),
    .Branch(BranchD),
    .ImmSrc(ImmSrcD),
    .ALUControl(ALUControlD)
  );

  // Datapath instantiation (sin floating point)
  datapath dp(
    .clk(clk),
    .reset(reset),
    .ResultSrcD(ResultSrcD),
    .ALUSrcD(ALUSrcD),
    .RegWriteD(RegWriteD),
    .MemWriteD(MemWriteD),
    .JumpD(JumpD),
    .BranchD(BranchD),
    .ImmSrcD(ImmSrcD),
    .ALUControlD(ALUControlD),
    .ZeroM(ZeroM),
    .PCF(PCF),
    .InstrF(InstrF),
    .InstrD(InstrD),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .ReadDataM(ReadDataM),
    .MemWriteM(MemWriteM)
  );

endmodule

