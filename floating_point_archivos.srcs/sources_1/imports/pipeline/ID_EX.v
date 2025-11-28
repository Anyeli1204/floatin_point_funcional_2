// ID/EX Pipeline Register con Flush (con soporte para floating point)
module ID_EX(input clk, reset,
                input FlushE,  // Señal de flush (insertar burbuja)
                input [31:0] RD1D, RD2D, PCD,
                input [4:0] Rs1D, Rs2D, RdD,
                input [31:0] ImmExtD, PCPlus4D,
                input [31:0] InstrD,  // Instrucción para debugging
                input RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD,
                input [1:0] ResultSrcD,
                input [2:0] ALUControlD,
                // Señales FP
                input isFPD,                    // 1 si es instrucción FP
                input FPRegWriteD,              // Escritura en register file FP
                input FPMemWriteD,              // Escritura en memoria FP
                input [2:0] FALUControlD,        // Control FALU (3 bits)
                input [3:0] FPLatencyD,         // Latencia FP (4 bits)
                input [31:0] FRD1D, FRD2D, 
                     // Datos del register file FP
                output reg [31:0] RD1E, RD2E, PCE,
                output reg [4:0] Rs1E, Rs2E, RdE,
                output reg [31:0] ImmExtE, PCPlus4E,
                output reg [31:0] InstrE,  // Instrucción para debugging
                output reg RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE,
                output reg [1:0] ResultSrcE,
                output reg [2:0] ALUControlE,
                // Salidas FP
                output reg isFPE,                // 1 si es instrucción FP
                output reg FPRegWriteE,          // Escritura en register file FP
                output reg FPMemWriteE,          // Escritura en memoria FP
                output reg [2:0] FALUControlE,   // Control FALU en EX
                output reg [3:0] FPLatencyE,     // Latencia FP en EX
                output reg [31:0] FRD1E, FRD2E   // Datos FP en EX
);

  // Inicializar registros
  initial begin
    FPLatencyE = 4'b0;
    isFPE = 1'b0;
    FPRegWriteE = 1'b0;
    FPMemWriteE = 1'b0;
    FALUControlE = 3'b0;
    FRD1E = 32'b0;
    FRD2E = 32'b0;
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin  // Reset asíncrono
      RD1E <= 0;
      RD2E <= 0;
      PCE <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      ImmExtE <= 0;
      PCPlus4E <= 0;
      InstrE <= 32'h00000013;  // NOP para debugging
      RegWriteE <= 0;
      MemWriteE <= 0;
      JumpE <= 0;
      BranchE <= 0;
      ALUSrcE <= 0;
      ResultSrcE <= 0;
      ALUControlE <= 0;
      // Señales FP
      isFPE <= 0;
      FPRegWriteE <= 0;
      FPMemWriteE <= 0;
      FALUControlE <= 0;
      FPLatencyE <= 0;
      FRD1E <= 0;
      FRD2E <= 0;
    end else if (FlushE) begin  // Flush = insertar NOP
      RD1E <= 0;
      RD2E <= 0;
      PCE <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      ImmExtE <= 0;
      PCPlus4E <= 0;
      InstrE <= 32'h00000013;  // NOP para debugging
      RegWriteE <= 0;
      MemWriteE <= 0;
      JumpE <= 0;
      BranchE <= 0;
      ALUSrcE <= 0;
      ResultSrcE <= 0;
      ALUControlE <= 0;
      // Señales FP
      isFPE <= 0;
      FPRegWriteE <= 0;
      FPMemWriteE <= 0;
      FALUControlE <= 0;
      // IMPORTANTE: Si FPLatencyD tiene un valor válido (>0), mantenerlo incluso durante flush
      // Esto evita perder la latencia cuando FlushE se activa por load-use hazard
      // No dependemos de isFPD porque puede no estar activo en el momento correcto
      if (FPLatencyD > 4'b0) begin
        FPLatencyE <= FPLatencyD;  // Capturar la latencia incluso durante flush
      end else begin
        FPLatencyE <= 0;
      end
      FRD1E <= 0;
      FRD2E <= 0;
    end else begin
      RD1E <= RD1D;
      RD2E <= RD2D;
      PCE <= PCD;
      Rs1E <= Rs1D;
      Rs2E <= Rs2D;
      RdE <= RdD;
      ImmExtE <= ImmExtD;
      PCPlus4E <= PCPlus4D;
      InstrE <= InstrD;  // Propagación de instrucción
      RegWriteE <= RegWriteD;
      MemWriteE <= MemWriteD;
      JumpE <= JumpD;
      BranchE <= BranchD;
      ALUSrcE <= ALUSrcD;
      ResultSrcE <= ResultSrcD;
      ALUControlE <= ALUControlD;
      // Señales FP
      isFPE <= isFPD;
      FPRegWriteE <= FPRegWriteD;
      FPMemWriteE <= FPMemWriteD;
      FALUControlE <= FALUControlD;
      FPLatencyE <= FPLatencyD;
      FRD1E <= FRD1D;
      FRD2E <= FRD2D;
    end
  end
endmodule
