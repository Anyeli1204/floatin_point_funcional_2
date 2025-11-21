// IF/ID Pipeline Register con Stall y Flush (sin floating point)
module IF_ID(input clk, reset,
                input stallD,  // Señal de stall
                input flushD,  // Señal de flush (para control hazards)
                input [31:0] InstrF, PCF, PCPlus4F,
                output reg [31:0] InstrD, PCD, PCPlus4D);

  always @(posedge clk) begin
    if (reset || flushD) begin  // Reset o Flush = insertar NOP
      InstrD <= 32'h00000013;  // NOP (addi x0, x0, 0)
      PCD <= 0;
      PCPlus4D <= 0;
    end else if (!stallD) begin  // Solo avanzar si no hay stall
      InstrD <= InstrF;
      PCD <= PCF;
      PCPlus4D <= PCPlus4F;
    end
    // Si stallD = 1, mantener valores actuales (no hacer nada)
  end
endmodule
