// Unidad de detección de hazards con forwarding, stalling y flushing
module hazard_unit(
  // Entradas desde la etapa Decode (ID)
  input [4:0] Rs1D, Rs2D,
  
  // Entradas desde la etapa Execute (EX)
  input [4:0] Rs1E, Rs2E, RdE,
  input [1:0] ResultSrcE,  // Para detectar lw/flw (ResultSrcE[0] = 1)
  input PCSrcE,            // Para detectar saltos tomados
  
  // Entradas desde la etapa Memory (MEM)
  input [4:0] RdM,
  input RegWriteM,
  input FPRegWriteM,  // Escritura en register file FP desde MEM
  
  // Entradas desde la etapa Writeback (WB)
  input [4:0] RdW,
  input RegWriteW,
  input FPRegWriteW,  // Escritura en register file FP desde WB
  
  // Salidas de control de forwarding enteros
  output [1:0] ForwardAE,
  output [1:0] ForwardBE,
  
  // Salidas de control de forwarding FP
  output [1:0] ForwardAFE,  // Forwarding para FRD1E
  output [1:0] ForwardBFE,  // Forwarding para FRD2E
  
  // Salidas de control de stalling y flushing
  output StallF,   // Detener etapa Fetch
  output StallD,   // Detener etapa Decode
  output FlushD,   // Limpiar etapa Decode (control hazards)
  output FlushE   // Limpiar etapa Execute (data hazards y control hazards)
);

  // ===== FORWARDING LOGIC =====
  // Forwarding para SrcA (Rs1E)
  // Prioridad: EX/MEM > MEM/WB > Normal
  assign ForwardAE = 
    // Forwarding desde EX/MEM (más reciente, mayor prioridad)
    ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0)) ? 2'b10 :
    // Forwarding desde MEM/WB
    ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0)) ? 2'b01 :
    // Sin forwarding, usar valor del banco de registros
    2'b00;

  // Forwarding para SrcB (Rs2E)
  // Prioridad: EX/MEM > MEM/WB > Normal
  assign ForwardBE = 
    // Forwarding desde EX/MEM (más reciente, mayor prioridad)
    ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0)) ? 2'b10 :
    // Forwarding desde MEM/WB
    ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0)) ? 2'b01 :
    // Sin forwarding, usar valor del banco de registros
    2'b00;

  // ===== FORWARDING LOGIC PARA FP =====
  // Forwarding para FRD1E (fs1 en operaciones FP)
  // Prioridad: EX/MEM > MEM/WB > Normal
  // Nota: Usamos los mismos Rs1E/Rs2E porque las direcciones de registro son las mismas
  assign ForwardAFE = 
    // Forwarding desde EX/MEM (más reciente, mayor prioridad)
    ((Rs1E == RdM) && FPRegWriteM && (Rs1E != 5'b0)) ? 2'b10 :
    // Forwarding desde MEM/WB
    ((Rs1E == RdW) && FPRegWriteW && (Rs1E != 5'b0)) ? 2'b01 :
    // Sin forwarding, usar valor del banco de registros FP
    2'b00;

  // Forwarding para FRD2E (fs2 en operaciones FP)
  // Prioridad: EX/MEM > MEM/WB > Normal
  assign ForwardBFE = 
    // Forwarding desde EX/MEM (más reciente, mayor prioridad)
    ((Rs2E == RdM) && FPRegWriteM && (Rs2E != 5'b0)) ? 2'b10 :
    // Forwarding desde MEM/WB
    ((Rs2E == RdW) && FPRegWriteW && (Rs2E != 5'b0)) ? 2'b01 :
    // Sin forwarding, usar valor del banco de registros FP
    2'b00;

  
  // ===== CONTROL HAZARD HANDLING =====
  // Cuando se toma un salto (beq, bne, jal, jalr), las instrucciones
  // que ya están en IF y ID son incorrectas y deben descartarse
  
  // Reglas de propagación:
  // 1. Load-use hazard (lw/flw):
  //    - StallF = 1: No avanzar PC
  //    - StallD = 1: Mantener instrucción en ID
  //    - FlushE = 1: Insertar NOP en EX
  //
  // 2. Control hazard (salto tomado):
  //    - FlushD = 1: Descartar instrucción en ID
  //    - FlushE = 1: Descartar instrucción en EX
  //    - StallF = 0: PC avanza al target del salto
  //    - StallD = 0: ID acepta nueva instrucción
  
  // ===== STALL Y FLUSH - C�?LCULO DIRECTO =====
  // Stall cuando hay load-use hazard (lw/flw en EX con dependencia RAW)
  // Load-use: ResultSrcE[0] = 1 (load) y hay dependencia RAW con ID
  wire lwStall;
  assign lwStall = ResultSrcE[0] &&           // la instrucción en EX es load
                   ((Rs1D == RdE) || (Rs2D == RdE)) &&  // dependencia RAW
                   (RdE != 5'b0);             // ignorar x0
  
  assign StallF = lwStall;          // solo se stallea en load-use
  assign StallD = lwStall;
  assign FlushD = PCSrcE;           // limpiar ID si hay salto tomado
  assign FlushE = lwStall | PCSrcE; // burbuja en EX por load-use o branch

endmodule
