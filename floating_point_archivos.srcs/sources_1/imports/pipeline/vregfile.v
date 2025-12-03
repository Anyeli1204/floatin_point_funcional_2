// Vector Register File (32 registros de 32 bits para operaciones vectoriales/matriciales)
// RF independiente para el acelerador de multiplicación de matrices
// NOTA: Similar a fregfile pero para registros vectoriales (v0-v31)
module vregfile(
  input  clk,
  input  we3,              // Write enable
  input  [4:0] a1, a2, a3, // Read addresses (vs1, vs2) y Write address (vd)
  input  [4:0] a3_read,    // Read address para vd (rd en matmul)
  input  [31:0] wd3,       // Write data
  output [31:0] rd1, rd2,  // Read data (vs1, vs2)
  output [31:0] rd3        // Read data (vd)
);

  reg [31:0] vrf[31:0];  // 32 registros vectoriales (v0-v31)
  integer i;

  // Inicializar todos los registros con 0
  initial begin
    for (i = 0; i < 32; i = i + 1)
      vrf[i] = 32'h00000000;
  end

  // Escritura en flanco positivo del reloj
  always @(posedge clk) begin
    if (we3) vrf[a3] <= wd3;
  end

  // Lectura combinacional con bypass interno
  // Si se lee el mismo registro que se está escribiendo, devolver wd3
  assign rd1 = (we3 && (a1 == a3)) ? wd3 : vrf[a1];
  assign rd2 = (we3 && (a2 == a3)) ? wd3 : vrf[a2];
  assign rd3 = (we3 && (a3_read == a3)) ? wd3 : vrf[a3_read];

endmodule

