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
  input  [31:0] ReadDataM, // Proviene de fuera del m�dulo datapath, es decir, si dmem lee datos de memoria, produce ReadData
  // Se�ales FP desde controller
  input  isFPD,              // 1 si es instrucci�n FP
  input  [2:0] FALUControlD, // Control FALU (3 bits)
  input  [3:0] FPLatencyD,   // Latencia FP (4 bits: ADD/SUB=1, MUL=4, DIV=12)
  input  FPRegWriteD,        // Escritura en register file FP
  input  FPMemWriteD,         // Escritura en memoria FP
  //ReadData, se conecta a ReadDataM del datapath
  //ReadDataM, entra al registro MemWB como ReadDataM

  output ZeroE,
  output MemWriteM,
  output [31:0] PCF,
  output [31:0] InstrD,
  output [31:0] ALUResultM, WriteDataM,
  // Salidas FP
  output FPMemWriteM,        // Escritura en memoria FP
  output [31:0] FWriteDataM  // Dato a escribir en memoria FP
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

  // Se�ales de control flotantes
  wire FPRegWriteE, FPRegWriteM, FPRegWriteW;  // Escritura en register file FP
  wire FPMemWriteE, FPMemWriteM;               // Escritura en memoria FP
  
  // Escritura en banco entero solo si NO es instruccion FP
  wire RegWriteIntW = RegWriteW & ~FPRegWriteW;

  // Se�ales internas de cada etapa del pipeline
  // Fetch
  wire [31:0] PCPlus4F, PCNextF; //PCNextF es siguiente instruccion

  // Decode
  wire [31:0] PCD, PCPlus4D; 
  wire [31:0] RD1D, RD2D, ImmExtD;
  wire [31:0] FRD1D, FRD2D;  // Lecturas del FP register file

  // Execute
  wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  wire [31:0] SrcBE, ALUResultE, WriteDataE;
  wire [31:0] PCTargetE;  
  wire [4:0] Rs1E, Rs2E, RdE;
  wire [31:0] InstrE;  // Instrucción en EX para debugging
  // Se�ales FP en EX
  wire isFPE;                // 1 si es instrucci�n FP
  wire [2:0] FALUControlE;   // Control FALU en EX
  wire [3:0] FPLatencyE;     // Latencia FP en EX
  wire [31:0] FRD1E, FRD2E;  // Datos FP en EX
  wire [31:0] FALUResultE, FWriteDataE;
  wire [31:0] ALUResultE_muxed;  // Resultado ALU (entero o FP seg�n isFPE)
  wire [31:0] WriteDataE_muxed;  // Dato a escribir (entero o FP seg�n FPMemWriteE)
  // Memory
  wire [31:0] PCPlus4M;
  wire [31:0] ALUResultM, WriteDataM;
  wire [31:0] FALUResultM, FWriteDataM;  // Se�ales FP separadas
  wire [4:0] RdM;
  wire [31:0] InstrM;  // Instrucción en MEM para debugging

  // Writeback
  wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
  wire [31:0] ResultW, FALUResultW;  // Resultado ALU FP en WB
  wire [31:0] FResultW;  // Resultado final FP (FALU o memoria)
  wire [4:0] RdW;
  wire [31:0] InstrW;  // Instrucción en WB para debugging

  // Se�ales de forwarding (adelantamiento de datos)
  wire [1:0] ForwardAE, ForwardBE;
  wire [1:0] ForwardAFE, ForwardBFE;  // Forwarding para FP
  wire [31:0] SrcAE_forwarded;
  wire [31:0] FRD1E_forwarded, FRD2E_forwarded;  // Forwarding para FP
  
  // Se�ales de stall y flush
  wire StallF, StallD, FlushD, FlushE;
  
  // Se�al de control de salto
  wire PCSrcE;  // Decisi�n de salto en EX (se calcula despu�s de ALU)

  // ===== ETAPA FETCH =====
  // Registro del PC con enable para stalling
  flopr #(WIDTH) pcreg(
    .clk(clk),
    .reset(reset),
    .StallF(StallF),      // Detener cuando StallF = 1
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
  // Banco de registros enteros
  // Solo escribir si es instrucción entera (no FP)
  regfile rf(
    .clk(clk),
    .we3(RegWriteIntW),  // Escritura solo para instrucciones enteras
    .a1(InstrD[19:15]),
    .a2(InstrD[24:20]),
    .a3(RdW),
    .wd3(ResultW),
    .rd1(RD1D),
    .rd2(RD2D)
  );

  fregfile frf(
    .clk(clk),
    .we3(FPRegWriteW),        // Escritura desde WB
    .a1(InstrD[19:15]),       // fs1
    .a2(InstrD[24:20]),       // fs2
    .a3(RdW),                 // fd
    .wd3(FResultW),           // Dato a escribir (desde FALU o memoria)
    .rd1(FRD1D),              // Salida fs1
    .rd2(FRD2D)               // Salida fs2
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
    .InstrD(InstrD),  // Instrucción para debugging
    .RegWriteD(RegWriteD),
    .MemWriteD(MemWriteD),
    .JumpD(JumpD),
    .BranchD(BranchD),
    .ALUSrcD(ALUSrcD),
    .ResultSrcD(ResultSrcD),
    .ALUControlD(ALUControlD),
    // Se�ales FP
    .isFPD(isFPD),
    .FPRegWriteD(FPRegWriteD),
    .FPMemWriteD(FPMemWriteD),
    .FALUControlD(FALUControlD),
    .FPLatencyD(FPLatencyD),  // Latencia FP
    .FRD1D(FRD1D),
    .FRD2D(FRD2D),

    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdE(RdE),
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    .InstrE(InstrE),  // Instrucción para debugging
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .BranchE(BranchE),
    .ALUSrcE(ALUSrcE),
    .ResultSrcE(ResultSrcE),
    .ALUControlE(ALUControlE),
    // Salidas FP
    .isFPE(isFPE),
    .FPRegWriteE(FPRegWriteE),
    .FPMemWriteE(FPMemWriteE),
    .FALUControlE(FALUControlE),
    .FPLatencyE(FPLatencyE),  // Latencia FP en EX
    .FRD1E(FRD1E),
    .FRD2E(FRD2E)
    
  );

// ===== EXECUTE =====
  hazard_unit hu(
    .clk(clk),
    .reset(reset),
    // Entradas para forwarding enteros
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    // Entradas para forwarding FP
    .FPRegWriteM(FPRegWriteM),
    .FPRegWriteW(FPRegWriteW),
    // Entradas para stalling (load-use)
    .Rs1D(InstrD[19:15]),
    .Rs2D(InstrD[24:20]),
    .RdE(RdE),
    .ResultSrcE(ResultSrcE),
    .FPRegWriteE(FPRegWriteE),  // Para detectar flw en EX
    .RegWriteE(RegWriteE),      // Para detectar lw en EX
    // Entradas para manejo de latencia FP
    .isFPE(isFPE),              // 1 si es instrucción FP en EX
    .FPLatencyE(FPLatencyE),     // Latencia de la operación FP en EX
    .isFPD(isFPD),              // 1 si es instrucción FP en ID
    .FPLatencyD(FPLatencyD),     // Latencia de la operación FP en ID
    // Entradas para flushing (control hazards) - temporal
    .PCSrcE(PCSrcE),
    // Salidas forwarding enteros
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    // Salidas forwarding FP
    .ForwardAFE(ForwardAFE),
    .ForwardBFE(ForwardBFE),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),  // Temporal, se actualizar? despu?s
    .FlushE(FlushE)  // Temporal, se actualizar? despu?s
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

  // Unidad Aritm�tico-L�gica Entera
  alu alu(
    .a(SrcAE_forwarded),
    .b(SrcBE),
    .alucontrol(ALUControlE),
    .result(ALUResultE),
    .zero(ZeroE)
  );

  // Mux para forwarding en FRD1E (FP)
  // ForwardAFE: 00 = FRD1E, 01 = FResultW, 10 = FALUResultM
  mux3 #(WIDTH) forwardAFEmux(
    .d0(FRD1E),           // Sin forwarding
    .d1(FResultW),        // Forward desde WB
    .d2(FALUResultM),     // Forward desde MEM
    .s(ForwardAFE),
    .y(FRD1E_forwarded)
  );

  // Mux para forwarding en FRD2E (FP)
  // ForwardBFE: 00 = FRD2E, 01 = FResultW, 10 = FALUResultM
  mux3 #(WIDTH) forwardBFEmux(
    .d0(FRD2E),           // Sin forwarding
    .d1(FResultW),        // Forward desde WB
    .d2(FALUResultM),     // Forward desde MEM
    .s(ForwardBFE),
    .y(FRD2E_forwarded)
  );

  // Unidad Aritm�tico-L�gica Floating Point
  alu_fp #(.system(32)) fp_alu(
    .a(FRD1E_forwarded),        // Operando 1 desde register file FP (con forwarding)
    .b(FRD2E_forwarded),        // Operando 2 desde register file FP (con forwarding)
    .FALUControl(FALUControlE), // Control FALU (3 bits): 000=fadd, 001=fsub, 010=fmul, 011=fdiv
    .y(FALUResultE),            // Resultado de la operaci�n FP
    .ALUFlags()                 // Flags FP (se pueden usar m�s adelante si es necesario)
  );

  // Para fsw, usar FRD2E_forwarded como dato a escribir
  assign FWriteDataE = FRD2E_forwarded;

  // Mux para seleccionar entre ALU entera y FP seg�n isFPE
  mux2 #(WIDTH) alu_result_mux(
    .d0(ALUResultE),      // Resultado ALU entera
    .d1(FALUResultE),    // Resultado ALU FP
    .s(isFPE),           // Selecci�n: 0=entero, 1=FP
    .y(ALUResultE_muxed)
  );

  // Mux para seleccionar entre WriteData entero y FP seg�n FPMemWriteE
  mux2 #(WIDTH) write_data_mux(
    .d0(WriteDataE),     // Dato entero
    .d1(FWriteDataE),   // Dato FP (FRD2E)
    .s(FPMemWriteE),    // Selecci�n: 0=entero, 1=FP
    .y(WriteDataE_muxed)
  );

  adder pcaddbranch(
    .a(PCE),
    .b(ImmExtE),
    .y(PCTargetE)
  );


  // Calcular PCSrc en EX (despu�s de ALU, cuando ZeroE est� disponible)
  // PCSrcE = 1 cuando:
  //   - Branch tomado: BranchE && ZeroE
  //   - Jump incondicional: JumpE
  // Nota: Al inicio, BranchE y JumpE son 0 (desde ID_EX reset), as� que PCSrcE = 0
  assign PCSrcE = (BranchE && ZeroE) || JumpE;

  // EX/MEM 
  EX_MEM exmem(
    // Inputs (se�ales de control y datos desde EX stage)
    .clk(clk),
    .reset(reset),
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .ResultSrcE(ResultSrcE),
    // Se�ales FP
    .FPRegWriteE(FPRegWriteE),
    .FPMemWriteE(FPMemWriteE),
    .ALUResultE(ALUResultE_muxed),  // Resultado muxed (entero o FP)
    .WriteDataE(WriteDataE_muxed),   // Dato muxed (entero o FP)
    // Se�ales FP separadas
    .FALUResultE(FALUResultE),
    .FWriteDataE(FWriteDataE),
    .PCPlus4E(PCPlus4E),
    .RdE(RdE),
    .InstrE(InstrE),  // Instrucción para debugging
    // Outputs (se�ales de control y datos hacia MEM stage)
    .RegWriteM(RegWriteM),
    .MemWriteM(MemWriteM),
    .ResultSrcM(ResultSrcM),
    // Salidas FP
    .FPRegWriteM(FPRegWriteM),
    .FPMemWriteM(FPMemWriteM),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    // Salidas FP separadas
    .FALUResultM(FALUResultM),
    .FWriteDataM(FWriteDataM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),
    .InstrM(InstrM)  // Instrucción para debugging
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
    // Se�ales FP
    .FPRegWriteM(FPRegWriteM),
    .FALUResultM(FALUResultM),
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PCPlus4W(PCPlus4W),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW),
    // Salidas FP
    .FPRegWriteW(FPRegWriteW),
    .FALUResultW(FALUResultW),
    .InstrW(InstrW)  // Instrucción para debugging
  );

  // ===== ETAPA WRITEBACK =====
  // Mux para resultado entero
  mux3 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .s(ResultSrcW),
    .y(ResultW)
  );

  // Mux para resultado flotante
  // Si es FP, el resultado viene de la FALU o memoria (flw)
  // ResultSrc: 00=FALU, 01=ReadData (solo 2 opciones para FP)
  mux2 #(WIDTH) fresultmux(
    .d0(FALUResultW),    // Resultado de FALU (fadd, fsub, fmul, fdiv) - ResultSrc[0]=0
    .d1(ReadDataW),      // Resultado de memoria (flw) - ResultSrc[0]=1
    .s(ResultSrcW[0]),   // ResultSrc[0]=1 para load, 0 para operaciones FP
    .y(FResultW)
  );

  // ZeroE es combinacional: se activa directamente cuando ALUResultE == 0
  // No necesita registrarse porque Zero es una se�al combinacional de la ALU
  // Se usa en EX para la decisi�n de branch: PCSrcE = (BranchE && ZeroE) || JumpE

endmodule
