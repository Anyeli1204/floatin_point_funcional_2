// Unidad de detección de hazards con forwarding, stalling y flushing
module hazard_unit(
  input clk, reset,  // Reloj y reset para contador de latencia
  // Entradas desde la etapa Decode (ID)
  input [4:0] Rs1D, Rs2D,
  
  // Entradas desde la etapa Execute (EX)
  input [4:0] Rs1E, Rs2E, RdE,
  input [1:0] ResultSrcE,  // Para detectar lw/flw (ResultSrcE[0] = 1)
  input PCSrcE,            // Para detectar saltos tomados
  input FPRegWriteE,      // Para detectar flw (FPRegWriteE = 1 cuando es flw)
  input RegWriteE,        // Para detectar lw (RegWriteE = 1 cuando es lw)
  // Entradas para manejo de latencia FP
  input isFPE,            // 1 si es instrucción FP en EX
  input [3:0] FPLatencyE, // Latencia de la operación FP en EX
  // Nota: isFPD y FPLatencyD se mantienen para compatibilidad con el datapath,
  // pero no se usan en la lógica de stall (solo se usa isFPE y FPLatencyE)
  input isFPD,            // 1 si es instrucción FP en ID (Decode) - no usado aquí
  input [3:0] FPLatencyD,  // Latencia de la operación FP en ID - no usado aquí
  
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

  // ===== FP LATENCY HAZARD DETECTION =====
  // Contador de latencia para operaciones FP con latencia > 1
  // Se inicializa cuando una operación FP entra a EX con latencia > 1
  // Se decrementa cada ciclo hasta llegar a 0
  reg [3:0] latencyCounter;
  reg [3:0] latencyCounter_next;
  
  // Lógica del contador de latencia
  always @(*) begin
    if (reset) begin
      latencyCounter_next = 4'b0;
    end else if (latencyCounter > 4'b0) begin
      // Si el contador está activo, decrementar
      latencyCounter_next = latencyCounter - 4'b0001;
    end else if (isFPE && (FPLatencyE > 4'b0001)) begin
      // Si hay una operación FP en EX con latencia > 1, inicializar contador
      latencyCounter_next = FPLatencyE - 4'b0001;  // (latencia - 1) ciclos de stall
    end else begin
      // Mantener en 0
      latencyCounter_next = 4'b0;
    end
  end
  
  // Registro del contador
  always @(posedge clk) begin
    if (reset) begin
      latencyCounter <= 4'b0;
    end else begin
      latencyCounter <= latencyCounter_next;
    end
  end
  
  // ===== CONTROL HAZARD HANDLING =====
  // Cuando se toma un salto (beq, bne, jal, jalr), las instrucciones
  // que ya están en IF y ID son incorrectas y deben descartarse
  
  // Reglas de propagación:
  // 1. Load-use hazard:
  //    - StallF = 1: No avanzar PC
  //    - StallD = 1: Mantener instrucción en ID
  //    - FlushE = 1: Insertar NOP en EX
  //
  // 2. FP Latency hazard (latencia > 1):
  //    - StallF = 1: No avanzar PC
  //    - StallD = 1: Mantener instrucción en ID
  //    - FlushE = 0: Mantener operación FP en EX
  //
  // 3. Control hazard (salto tomado):
  //    - FlushD = 1: Descartar instrucción en ID
  //    - FlushE = 1: Descartar instrucción en EX
  //    - StallF = 0: PC avanza al target del salto
  //    - StallD = 0: ID acepta nueva instrucción
  
  // ===== STALL Y FLUSH - C�?LCULO DIRECTO =====
  // Stall cuando hay load-use hazard (lw/flw en EX con dependencia RAW) 
  // O cuando el contador de latencia FP está activo
  // Load-use: ResultSrcE[0] = 1 (load) y hay dependencia RAW con ID
  // IMPORTANTE: lw escribe en registro entero, flw escribe en registro FP
  // Solo hacer stall si hay dependencia real del mismo tipo
  // lw en EX solo causa stall si instrucción en ID es entera y necesita el dato
  // flw en EX puede causar stall si instrucción en ID necesita el registro FP
  assign StallF = (ResultSrcE[0] && 
                   ((RegWriteE && !FPRegWriteE && ((Rs1D == RdE) || (Rs2D == RdE))) ||  // lw (entero) con dependencia entera
                    (FPRegWriteE && ((Rs1D == RdE) || (Rs2D == RdE)))) &&  // flw (FP) con dependencia
                   (RdE != 5'b0)) ||  // Load-use hazard
                  (latencyCounter > 4'b0);  // Latencia FP activa
  
  assign StallD = (ResultSrcE[0] && 
                   ((RegWriteE && !FPRegWriteE && ((Rs1D == RdE) || (Rs2D == RdE))) ||  // lw (entero) con dependencia entera
                    (FPRegWriteE && ((Rs1D == RdE) || (Rs2D == RdE)))) &&  // flw (FP) con dependencia
                   (RdE != 5'b0)) ||  // Load-use hazard
                  (latencyCounter > 4'b0);  // Latencia FP activa
  
  // Flush cuando hay salto tomado O load-use hazard (insertar burbuja en EX)
  // NO hacer flush para latencia FP (mantener operación FP en EX)
  assign FlushD = PCSrcE;
  assign FlushE = (ResultSrcE[0] && 
                   ((RegWriteE && !FPRegWriteE && ((Rs1D == RdE) || (Rs2D == RdE))) ||  // lw (entero) con dependencia entera
                    (FPRegWriteE && ((Rs1D == RdE) || (Rs2D == RdE)))) &&  // flw (FP) con dependencia
                   (RdE != 5'b0)) ||  // Load-use hazard (insertar NOP en EX)
                  PCSrcE;  // Salto tomado

endmodule
