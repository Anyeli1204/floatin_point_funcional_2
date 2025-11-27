// RISC-V Pipelined Processor con soporte FP
module riscvpipeline(input  clk, reset,
                      output [31:0] PCF,
                      input  [31:0] InstrF,
                      output MemWriteM,
                      output [31:0] ALUResultM, WriteDataM,
                      input  [31:0] ReadDataM,
                      // Salidas FP
                      output FPMemWriteM,        // Escritura en memoria FP
                      output [31:0] FWriteDataM  // Dato a escribir en memoria FP
);

  // Internal pipeline control signals
  wire [1:0]  ResultSrcD;
  wire ALUSrcD;
  wire RegWriteD;
  wire MemWriteD;
  wire JumpD;
  wire BranchD;
  wire [2:0] ImmSrcD;  // 3 bits para soportar lui
  wire [2:0] ALUControlD;
  wire ZeroE;
  wire [31:0] InstrD;
  wire PCSrcM_unused;  // Not used in pipeline version (PCSrc se calcula en EX)
  
  // Señales FP desde controller
  wire isFPD;
  wire [2:0] FALUControlD;
  wire FPRegWriteD;
  wire FPMemWriteD;
  wire [3:0] FPLatency;      // Latencia FP desde controller
  wire [3:0] FPLatencyD;     // Latencia FP (conectada desde controller)

  // Controller instantiation (con soporte FP)
  controller_fp c(
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .funct7(InstrD[31:25]),  // funct7 completo para FP
    .Zero(ZeroE),
    .ResultSrc(ResultSrcD),
    .MemWrite(MemWriteD),
    .PCSrc(PCSrcM_unused),  // Calculated in datapath instead
    .ALUSrc(ALUSrcD),
    .RegWrite(RegWriteD),
    .Jump(JumpD),
    .Branch(BranchD),
    .ImmSrc(ImmSrcD),
    .ALUControl(ALUControlD),
    // Señales FP
    .isFP(isFPD),
    .FPLatency(FPLatency),      // Salida del controller
    .FALUControl(FALUControlD),
    .FPRegWrite(FPRegWriteD),
    .FPMemWrite(FPMemWriteD)
  );
  
  // Conectar FPLatency del controller a FPLatencyD explícitamente
  assign FPLatencyD = FPLatency;

  // Datapath instantiation (con soporte floating point)
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
    // Señales FP
    .isFPD(isFPD),
    .FALUControlD(FALUControlD),
    .FPLatencyD(FPLatencyD),  // Latencia FP para manejo de stalls
    .FPRegWriteD(FPRegWriteD),
    .FPMemWriteD(FPMemWriteD),
    .ZeroE(ZeroE),
    .PCF(PCF),
    .InstrF(InstrF),
    .InstrD(InstrD),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .ReadDataM(ReadDataM),
    .MemWriteM(MemWriteM),
    // Salidas FP
    .FPMemWriteM(FPMemWriteM),
    .FWriteDataM(FWriteDataM)
  );

endmodule

