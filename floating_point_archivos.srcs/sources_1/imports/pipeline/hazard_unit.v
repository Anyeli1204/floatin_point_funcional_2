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
  // También necesitamos isFPD y FPLatencyD para detectar cuando entra una nueva operación
  input isFPD,            // 1 si es instrucción FP en ID (Decode)
  input [3:0] FPLatencyD,  // Latencia de la operación FP en ID
  
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

  // ===== LOAD-USE HAZARD DETECTION =====
  // Detectar si la instrucción en EX es un lw (load word) o flw (load FP)
  // ResultSrcE[0] = 1 indica que es una instrucción load (lw o flw)
  // RegWriteE = 1 para lw, FPRegWriteE = 1 para flw
  wire lwStall;      // Stall para lw (dependencia con registros enteros)
  wire flwStall;     // Stall para flw (dependencia con registros FP)
  wire loadUseStall; // Stall total (lw o flw)
  
  // Stall para lw: depende de registros enteros
  assign lwStall = ResultSrcE[0] && RegWriteE &&  // La instrucción en EX es lw
                   ((Rs1D == RdE) || (Rs2D == RdE)) &&  // Dependencia RAW con enteros
                   (RdE != 5'b0);  // No hacer stall para x0
  
  // Stall para flw: depende de registros FP
  // Nota: flw también usa las mismas direcciones Rs1D/Rs2D, pero escribe en FP
  assign flwStall = ResultSrcE[0] && FPRegWriteE &&  // La instrucción en EX es flw
                    ((Rs1D == RdE) || (Rs2D == RdE)) &&  // Dependencia RAW (mismas direcciones)
                    (RdE != 5'b0);  // No hacer stall para f0 (aunque f0 no está hardwired)
  
  // Stall total: si hay dependencia con lw o flw
  assign loadUseStall = lwStall || flwStall;

  // ===== FP LATENCY HAZARD DETECTION =====
  // Contador de latencia para operaciones FP
  // Se inicializa con (latencia - 1) cuando entra una nueva operación FP
  // Se decrementa cada ciclo hasta llegar a 0
  reg [3:0] latencyCounter;
  reg [3:0] latencyCounter_next;
  reg [3:0] capturedLatency;  // Capturar latencia cuando isFPE se activa
  wire fpLatencyStall;  // Stall por latencia FP
  
  // Capturar la latencia cuando isFPE se activa (transición 0->1)
  reg isFPE_prev;
  always @(posedge clk) begin
    if (reset) begin
      isFPE_prev <= 1'b0;
      capturedLatency <= 4'b0;
    end else begin
      isFPE_prev <= isFPE;
      // Capturar latencia cuando isFPE se activa por primera vez
      if (isFPE && !isFPE_prev) begin
        // Preferir FPLatencyE, sino usar FPLatencyD
        capturedLatency <= (FPLatencyE > 4'b0) ? FPLatencyE : FPLatencyD;
      end
    end
  end
  
  // Lógica combinacional para el siguiente estado del contador
  always @(*) begin
    // Si el contador > 0, siempre decrementar (prioridad más alta)
    if (latencyCounter > 4'b0) begin
      latencyCounter_next = latencyCounter - 4'b0001;
    end
    // Si hay una operación FP (isFPE o isFPD) con latencia > 1 y contador en 0, inicializar
    // Usar capturedLatency si está disponible, sino usar FPLatencyE o FPLatencyD
    else if ((isFPE || isFPD) && (latencyCounter == 4'b0) && ((capturedLatency > 4'b0001) || (FPLatencyE > 4'b0001) || (FPLatencyD > 4'b0001))) begin
      // Prioridad: capturedLatency > FPLatencyE > FPLatencyD
      if (capturedLatency > 4'b0001) begin
        latencyCounter_next = capturedLatency - 4'b0001;
      end else if (FPLatencyE > 4'b0001) begin
        latencyCounter_next = FPLatencyE - 4'b0001;  // (latencia - 1) ciclos adicionales
      end else begin
        latencyCounter_next = FPLatencyD - 4'b0001;  // Fallback usando FPLatencyD
      end
    end
    // Si no hay operación FP o latencia <= 1, mantener contador en 0
    else begin
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
  
  // Stall cuando el contador > 0 (operación FP en progreso)
  assign fpLatencyStall = (latencyCounter > 4'b0);

  // ===== CONTROL HAZARD HANDLING =====
  // Cuando se toma un salto (beq, bne, jal, jalr), las instrucciones
  // que ya están en IF y ID son incorrectas y deben descartarse
  
  // Reglas de propagación:
  // 1. Load-use hazard:
  //    - StallF = 1: No avanzar PC
  //    - StallD = 1: Mantener instrucción en ID
  //    - FlushE = 1: Insertar NOP en EX
  //
  // 2. Control hazard (salto tomado):
  //    - FlushD = 1: Descartar instrucción en ID
  //    - FlushE = 1: Descartar instrucción en EX
  //    - StallF = 0: PC avanza al target del salto
  //    - StallD = 0: ID acepta nueva instrucción
  
  // Stall total: load-use hazards O latencia FP
  wire totalStall = loadUseStall || fpLatencyStall;
  
  // IMPORTANTE: Para latencia FP, NO hacemos flush de EX
  // Queremos mantener la operación FP en EX mientras el contador cuenta
  // Solo hacemos flush de EX para load-use (insertar burbuja) y saltos
  assign StallF = totalStall;           // Detener en load-use o latencia FP
  assign StallD = totalStall;           // Detener en load-use o latencia FP
  assign FlushD = PCSrcE;            // Limpiar ID cuando hay salto tomado
  assign FlushE = loadUseStall | PCSrcE;  // Limpiar EX solo en load-use o salto tomado (NO en latencia FP)

endmodule
