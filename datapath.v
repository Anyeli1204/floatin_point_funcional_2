  // TODO: Verificar que todas las señales de control estén correctamente conectadas
  // FIXME: Revisar la lógica de forwarding para casos edge
  // NOTE: Este módulo implementa un pipeline de 5 etapas


module datapath(
  input  clk, reset,
  input  RegWriteD,  
  input  [1:0]  ResultSrcD,
  input  MemWriteD,
  input  JumpD,  
  input  BranchD,
  input  [2:0]  ALUControlD,
  input  ALUSrcD,
  input  [2:0]  ImmSrcD, 
  input  [31:0] InstrF,
  input  [31:0] ReadDataM, // Proviene de fuera del módulo datapath, es decir, si dmem lee datos de memoria, produce ReadData
  //ReadData, se conecta a ReadDataM del datapath
  //ReadDataM, entra al registro MemWB como ReadDataM

  output ZeroE,
  output MemWriteM,
  output [31:0] PCF,
  output [31:0] InstrD,
  output [31:0] ALUResultM, WriteDataM
);


  localparam WIDTH = 32;

  wire RegWriteE, RegWriteM, RegWriteW;
  wire [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
  wire MemWriteE;
  wire JumpE;
  wire BranchE;
  wire [2:0] ALUControlE;
  wire ALUSrcE;
  wire ZeroE;

  // Señales internas de cada etapa del pipeline
  // Fetch
  wire [31:0] PCPlus4F, PCNextF; //PCNextF es siguiente instruccion

  // Decode
  wire [31:0] PCD, PCPlus4D; 
  wire [31:0] RD1D, RD2D, ImmExtD;

  // Execute
  wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  wire [31:0] SrcBE, ALUResultE, WriteDataE;
  wire [31:0] PCTargetE;  
  wire [4:0] Rs1E, Rs2E, RdE;

  // Memory
  wire [31:0] PCPlus4M;
  wire [31:0] ALUResultM, WriteDataM;
  wire [4:0] RdM;

  // Writeback
  wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
  wire [31:0] ResultW;
  wire [4:0] RdW;

  // Señales de forwarding (adelantamiento de datos)
  wire [1:0] ForwardAE, ForwardBE;
  wire [31:0] SrcAE_forwarded;
  
  // Señales de stall y flush
  wire StallF, StallD, FlushD, FlushE;
  
  // Señal de control de salto
  wire PCSrcE;  // Decisión de salto en EX (se calcula después de ALU)

  // ===== ETAPA FETCH =====
  // Registro del PC con enable para stalling
  flopr #(WIDTH) pcreg(
    .clk(clk),
    .reset(reset),
    .StallF(StallF),      // Detener cuando StallF = 1, aqui esta diferente al otro codigo creom revisar como esta maneja la logica del stall
    .d(PCNextF),
    .q(PCF)
  );

  adder pcadd4(
    .a(PCF),
    .b(32'd4),
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

  // Registro IF/ID con soporte de stalling y flushing
  IF_ID ifid(
    .clk(clk),
    .reset(reset),
    .stallD(StallD),    // Detener desde hazard unit
    .flushD(FlushD),    // Limpiar desde hazard unit (control hazards)
    .InstrF(InstrF),
    .PCF(PCF),
    .PCPlus4F(PCPlus4F),
    .InstrD(InstrD),
    .PCD(PCD),
    .PCPlus4D(PCPlus4D)
  );

  // ===== ETAPA DECODE =====
  // Banco de registros
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
    .ALUControlE(ALUControlE)
  );

// ===== EXECUTE =====
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
    .PCSrcE(PCSrcE),
    // Salidas
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),  // Temporal, se actualizar? despu?s
    .FlushE(FlushE),   // Temporal, se actualizar? despu?s
  );

  // Mux para forwarding en SrcA
  // ForwardAE: 00 = RD1E, 01 = ResultW, 10 = ALUResultM
  mux3 #(WIDTH) forwardAmux(
    .d0(RD1E),           // Sin forwarding
    .d1(ResultW),        // Forward desde WB
    .d2(ALUResultM),     // Forward desde MEM
    .s(ForwardAE),
    .y(SrcAE_forwarded)
  );

  // Mux para forwarding en SrcB (antes del mux de immediate)
  mux3 #(WIDTH) forwardBmux(
    .d0(RD2E),           // Sin forwarding
    .d1(ResultW),        // Forward desde WB
    .d2(ALUResultM),     // Forward desde MEM
    .s(ForwardBE),
    .y(WriteDataE)
  );

  mux2 #(WIDTH) srcbmux(
    .d0(WriteDataE),     // Valor del registro (o forwardeado)
    .d1(ImmExtE),          // Immediate
    .s(ALUSrcE),
    .y(SrcBE)
  );

  // Unidad Aritmético-Lógica
  alu alu(
    .a(SrcAE_forwarded),
    .b(SrcBE),
    .alucontrol(ALUControlE),
    .result(ALUResultE),
    .zero(ZeroE)
  );

  adder pcaddbranch(
    .a(PCE),
    .b(ImmExtE),
    .y(PCTargetE)
  );

  // Calcular PCSrc en EX (después de ALU, cuando ZeroE está disponible)
  // PCSrcE = 1 cuando:
  //   - Branch tomado: BranchE && ZeroE
  //   - Jump incondicional: JumpE
  // Nota: Al inicio, BranchE y JumpE son 0 (desde ID_EX reset), así que PCSrcE = 0
  assign PCSrcE = (BranchE && ZeroE) || JumpE;

  // EX/MEM 
  EX_MEM exmem(
    // Inputs (señales de control y datos desde EX stage)
    .clk(clk),
    .reset(reset),
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .ResultSrcE(ResultSrcE),
    .ALUResultE(ALUResultE),
    .WriteDataE(WriteDataE),
    .PCPlus4E(PCPlus4E),
    .RdE(RdE),
    // Outputs (señales de control y datos hacia MEM stage)
    .RegWriteM(RegWriteM),
    .MemWriteM(MemWriteM),
    .ResultSrcM(ResultSrcM),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM)
  );

  // ===== MEMORY =====
  // Acceso a memoria se realiza en el m?dulo superior
  // Nota: PCSrc ahora se calcula en EX, no en MEM

  // MEM/WB 
  MEM_WB memwb(
    .clk(clk),
    .reset(reset),
    .ALUResultM(ALUResultM),
    .ReadDataM(ReadDataM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PCPlus4W(PCPlus4W),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
  );

  // ===== ETAPA WRITEBACK =====
  // Mux para seleccionar el resultado final
  mux3 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .s(ResultSrcW),
    .y(ResultW)
  );

  // ZeroE es combinacional: se activa directamente cuando ALUResultE == 0
  // No necesita registrarse porque Zero es una señal combinacional de la ALU
  // Se usa en EX para la decisión de branch: PCSrcE = (BranchE && ZeroE) || JumpE

endmodule
