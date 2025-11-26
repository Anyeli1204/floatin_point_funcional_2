// Floating-Point Register File (32 registros de 32 bits para punto flotante)
// NOTA: En RISC-V, f0 NO está hardwired a 0 (a diferencia de x0 en enteros)
// f0 es un registro normal que puede contener cualquier valor FP
module fregfile(
  input  clk,
  input  we3,              // Write enable
  input  [4:0] a1, a2, a3, // Read addresses (fs1, fs2) y Write address (fd)
  input  [31:0] wd3,       // Write data
  output [31:0] rd1, rd2   // Read data
);

  reg [31:0] frf[31:0];  // 32 registros flotantes
  integer i;

  // Inicializar todos los registros con 0.0 (IEEE 754)
  initial begin
    for (i = 0; i < 32; i = i + 1)
      frf[i] = 32'h00000000;  // +0.0 en IEEE 754
  end

  // Escritura en flanco positivo del reloj
  always @(posedge clk) begin
    if (we3) frf[a3] <= wd3;
  end

  // Lectura combinacional con bypass interno
  // Si se lee el mismo registro que se está escribiendo, devolver wd3
  assign rd1 = (we3 && (a1 == a3)) ? wd3 : frf[a1];
  assign rd2 = (we3 && (a2 == a3)) ? wd3 : frf[a2];

endmodule
