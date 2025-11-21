// Hazard Unit con Forwarding Logic, Load-Use Stall Detection y Control Hazards
module hazard_unit(
  // Entradas desde Decode (ID)
  input [4:0] Rs1D, Rs2D,
  
  // Entradas desde Execute (EX)
  input [4:0] Rs1E, Rs2E, RdE,
  input [1:0] ResultSrcE,  // Para detectar lw (ResultSrcE[0] = 1)
  input PCSrcE,            // Para detectar saltos tomados
  
  // Entradas desde Memory (MEM)
  input [4:0] RdM,
  input RegWriteM,
  
  // Entradas desde Writeback (WB)
  input [4:0] RdW,
  input RegWriteW,
  
  // Salidas de control de forwarding
  output [1:0] ForwardAE,
  output [1:0] ForwardBE,
  
  // Salidas de control de stalling y flushing
  output StallF,   // Stall Fetch stage
  output StallD,   // Stall Decode stage
  output FlushD,   // Flush Decode stage (control hazards)
  output FlushE,   // Flush Execute stage (data hazards y control hazards)
  output lwStall   // Load-use hazard detectado (para uso externo)
);

  // ===== FORWARDING LOGIC =====
  // Forwarding para SrcA (Rs1E)
  // Prioridad: EX/MEM > MEM/WB > Normal
  assign ForwardAE = 
    // Forwarding desde EX/MEM (m�s reciente, mayor prioridad)
    ((Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0)) ? 2'b10 :
    // Forwarding desde MEM/WB
    ((Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0)) ? 2'b01 :
    // Sin forwarding, usar valor del register file
    2'b00;

  // Forwarding para SrcB (Rs2E)
  // Prioridad: EX/MEM > MEM/WB > Normal
  assign ForwardBE = 
    // Forwarding desde EX/MEM (m�s reciente, mayor prioridad)
    ((Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0)) ? 2'b10 :
    // Forwarding desde MEM/WB
    ((Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0)) ? 2'b01 :
    // Sin forwarding, usar valor del register file
    2'b00;

  // ===== LOAD-USE HAZARD DETECTION =====
  // Detectar si la instrucci�n en EX es un lw (load word)
  // ResultSrcE[0] = 1 indica que es una instrucci�n lw
  wire lwStall;
  
  assign lwStall = ResultSrcE[0] &&  // La instrucci�n en EX es lw
                   ((Rs1D == RdE) || (Rs2D == RdE)) &&  // Dependencia RAW
                   (RdE != 5'b0);  // No hacer stall para x0
  
  // ===== CONTROL HAZARD HANDLING =====
  // Cuando se toma un salto (beq, bne, jal, jalr), las instrucciones
  // que ya est�n en IF y ID son incorrectas y deben descartarse
  
  // Reglas de propagaci�n:
  // 1. Load-use hazard:
  //    - StallF = 1: No avanzar PC
  //    - StallD = 1: Mantener instrucci�n en ID
  //    - FlushE = 1: Insertar NOP en EX
  //
  // 2. Control hazard (salto tomado):
  //    - FlushD = 1: Descartar instrucci�n en ID
  //    - FlushE = 1: Descartar instrucci�n en EX
  //    - StallF = 0: PC avanza al target del salto
  //    - StallD = 0: ID acepta nueva instrucci�n
  
  assign StallF = lwStall;           // Solo stall en load-use
  assign StallD = lwStall;           // Solo stall en load-use
  assign FlushD = PCSrcE;            // Flush ID cuando hay salto tomado
  assign FlushE = lwStall | PCSrcE;  // Flush EX en load-use o salto tomado

endmodule
