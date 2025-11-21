// Pipelined Datapath (sin floating point)
module datapath(
  input  clk, reset,
  // Se?ales de control (vienen del controller externo)
  input  [1:0]  ResultSrcD,
  input  ALUSrcD,
  input  RegWriteD,
  input  MemWriteD,
  input  JumpD,
  input  BranchD,
  input  [2:0]  ImmSrcD,    // 3 bits para soportar lui
  input  [2:0]  ALUControlD,

  output MemWriteM,
  output ZeroM,

  // Se?ales de Data
  input  [31:0] InstrF,
  input  [31:0] ReadDataM,
  
  output [31:0] PCF,
  output [31:0] InstrD,
  output [31:0] ALUResultM, WriteDataM
);

  localparam WIDTH = 32;

  // Internal control signals for pipeline stages
  wire [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
  wire ALUSrcE;
  wire RegWriteE, RegWriteM, RegWriteW;
  wire MemWriteE;
  wire JumpE, JumpM;
  wire BranchE, BranchM;
  wire [2:0] ALUControlE;
  wire ZeroE;

  // Se?ales internas de cada etapa del pipeline
  // Fetch
  wire [31:0] PCPlus4F, PCNextF;

  // Decode
  wire [31:0] PCD, PCPlus4D;
  wire [31:0] RD1D, RD2D, ImmExtD;

  // Execute
  wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  wire [31:0] SrcAE, SrcBE, ALUResultE, WriteDataE;
  wire [31:0] PCTargetE;  // Se calcular? en EX stage
  wire [4:0] Rs1E, Rs2E, RdE;
  wire [31:0] InstrE;  // Instrucci?n en EX stage (para debugging)

  // Memory
  wire [31:0] PCPlus4M, PCTargetM;
  wire [4:0] RdM;
  wire [31:0] InstruM;  // Instrucci?n en MEM stage (para debugging)

  // Writeback
  wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
  wire [31:0] ResultW;
  wire [4:0] RdW;

  // Forwarding signals
  wire [1:0] ForwardAE, ForwardBE;
  wire [31:0] SrcAE_forwarded, SrcBE_forwarded;
  
  // Stalling and flushing signals
  wire StallF, StallD, FlushD, FlushE;
  
  // Control hazard signals
  wire PCSrcE;  // Decisi?n de salto en EX (se calcular? despu?s de ALU)

  // ===== FETCH =====
  // PC register con enable para stalling
  flopr #(WIDTH) pcreg(
    .clk(clk),
    .reset(reset),
    .StallF(StallF),      // Stall cuando StallF = 1
    .d(PCNextF),
    .q(PCF)
  );

  adder pcadd4(
    .a(PCF),
    .b(32'd4),
    .StallF(1'b0),
    .y(PCPlus4F)
  );

  // Mux del PC - PCSrcE se calcular? despu?s de ALU
  // Al inicio, PCSrcE ser? 0 (BranchE y JumpE est?n en 0 despu?s del reset)
  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4F),
    .d1(PCTargetE),     // Salto desde EX, no desde MEM
    .s(PCSrcE),         // Decisi?n en EX (se calcular? despu?s de ALU)
    .y(PCNextF)
  );

  // IF/ID con soporte de stalling y flushing
  IF_ID ifid(
    .clk(clk),
    .reset(reset),
    .stallD(StallD),    // Stall desde hazard unit
    .flushD(FlushD),    // Flush desde hazard unit (control hazards)
    .InstrF(InstrF),
    .PCF(PCF),
    .PCPlus4F(PCPlus4F),
    .InstrD(InstrD),
    .PCD(PCD),
    .PCPlus4D(PCPlus4D)
  );

  // ===== DECODE =====
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1(InstrD[19:15]),
    .a2(InstrD[24:20]),
    .a3(RdW),
    .wd3(ResultW),
    .rd1(RD1D),
    .rd2(RD2D)
  );

  extend ext(
    .instr(InstrD[31:7]),
    .immsrc(ImmSrcD),
    .immext(ImmExtD)
  );

  // ID/EX con soporte de flush (sin se?ales FP)
  ID_EX idex(
    .clk(clk),
    .reset(reset),
    .FlushE(FlushE),    // Flush desde hazard unit
    .RD1D(RD1D),
    .RD2D(RD2D),
    .PCD(PCD),
    .Rs1D(InstrD[19:15]),
    .Rs2D(InstrD[24:20]),
    .RdD(InstrD[11:7]),
    .ImmExtD(ImmExtD),
    .PCPlus4D(PCPlus4D),
    .RegWriteD(RegWriteD),
    .MemWriteD(MemWriteD),
    .JumpD(JumpD),
    .BranchD(BranchD),
    .ALUSrcD(ALUSrcD),
    .ResultSrcD(ResultSrcD),
    .ALUControlD(ALUControlD),
    .InstrD(InstrD),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdE(RdE),
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .BranchE(BranchE),
    .ALUSrcE(ALUSrcE),
    .ResultSrcE(ResultSrcE),
    .ALUControlE(ALUControlE),
    .InstrE(InstrE)  // Instrucci?n en EX stage
  );

  // ===== EXECUTE =====
  // Hazard Unit - Forwarding y Stalling Logic (sin PCSrcE todav?a)
  // Nota: Forwarding y stalling no dependen de PCSrcE
  wire PCSrcE_temp = 1'b0;  // Temporal, se actualizar? despu?s de ALU
  wire FlushD_temp, FlushE_temp;  // Temporales, se actualizar?n despu?s
  wire lwStall;  // Load-use hazard detectado
  hazard_unit hu(
    // Entradas para forwarding
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    // Entradas para stalling (load-use)
    .Rs1D(InstrD[19:15]),
    .Rs2D(InstrD[24:20]),
    .RdE(RdE),
    .ResultSrcE(ResultSrcE),
    // Entradas para flushing (control hazards) - temporal
    .PCSrcE(PCSrcE_temp),
    // Salidas
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD_temp),  // Temporal, se actualizar? despu?s
    .FlushE(FlushE_temp),   // Temporal, se actualizar? despu?s
    .lwStall(lwStall)       // Exportar lwStall
  );

  // Mux para Forwarding en SrcA
  // ForwardAE: 00 = RD1E, 01 = ResultW, 10 = ALUResultM
  mux3 #(WIDTH) forwardAmux(
    .d0(RD1E),           // Sin forwarding
    .d1(ResultW),        // Forward desde WB
    .d2(ALUResultM),     // Forward desde MEM
    .s(ForwardAE),
    .y(SrcAE_forwarded)
  );

  // Mux para Forwarding en SrcB (antes del mux de immediate)
  // ForwardBE: 00 = RD2E, 01 = ResultW, 10 = ALUResultM
  mux3 #(WIDTH) forwardBmux(
    .d0(RD2E),           // Sin forwarding
    .d1(ResultW),        // Forward desde WB
    .d2(ALUResultM),     // Forward desde MEM
    .s(ForwardBE),
    .y(SrcBE_forwarded)
  );

  // Asignaciones para ALU
  assign SrcAE = SrcAE_forwarded;
  assign WriteDataE = SrcBE_forwarded;  // Para stores, usar valor forwardeado

  mux2 #(WIDTH) srcbmux(
    .d0(SrcBE_forwarded),  // Valor del registro (o forwardeado)
    .d1(ImmExtE),          // Immediate
    .s(ALUSrcE),
    .y(SrcBE)
  );

  // ALU entero
  alu alu(
    .a(SrcAE),
    .b(SrcBE),
    .alucontrol(ALUControlE),
    .result(ALUResultE),
    .zero(ZeroE)
  );

  adder pcaddbranch(
    .a(PCE),
    .b(ImmExtE),
    .StallF(1'b0),  // No se usa stall en branch adder
    .y(PCTargetE)
  );

  // C?lculo de PCSrc en EX (despu?s de ALU, cuando ZeroE est? disponible)
  // PCSrcE = 1 cuando:
  //   - Branch tomado: BranchE && ZeroE
  //   - Jump incondicional: JumpE
  // Nota: Al inicio, BranchE y JumpE son 0 (desde ID_EX reset), as? que PCSrcE = 0
  assign PCSrcE = (BranchE && ZeroE) || JumpE;

  // Actualizar FlushD y FlushE con el PCSrcE real (despu?s de ALU)
  assign FlushD = PCSrcE;  // Flush ID cuando hay salto tomado
  assign FlushE = lwStall | PCSrcE;  // Flush EX en load-use o salto tomado


  // EX/MEM (sin se?ales FP)
  EX_MEM exmem(
    .clk(clk),
    .reset(reset),
    .ALUResultE(ALUResultE),
    .WriteDataE(WriteDataE),
    .PCPlus4E(PCPlus4E),
    .RdE(RdE),
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .ResultSrcE(ResultSrcE),
    .InstruE(InstrE),  // Pasar instrucci?n desde EX
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .MemWriteM(MemWriteM),
    .ResultSrcM(ResultSrcM),
    .InstruM(InstruM)  // Instrucci?n en MEM stage
  );

  // ===== MEMORY =====
  // Acceso a memoria se realiza en el m?dulo superior
  // Nota: PCSrc ahora se calcula en EX, no en MEM

  // MEM/WB (sin se?ales FP)
  MEM_WB memwb(
    .clk(clk),
    .reset(reset),
    .ALUResultM(ALUResultM),
    .ReadDataM(ReadDataM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .InstruM(InstruM),  // Pasar instrucci?n desde MEM
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PCPlus4W(PCPlus4W),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
    .InstruW()  // Output no usado
  );

  // ===== WRITEBACK =====
  // Mux para resultado entero
  mux3 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .s(ResultSrcW),
    .y(ResultW)
  );

  // ZeroM output (ZeroE propagado a MEM stage)
  assign ZeroM = ZeroE;

endmodule
