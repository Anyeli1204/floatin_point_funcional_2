module dmem(input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);
  
  reg [31:0] RAM[63:0]; 
  integer i;

  initial begin
    // Inicializar memoria vacía
    for (i = 0; i < 64; i = i + 1)
      RAM[i] = 32'h00000000;

    // ============================
    //   ZONA DE ENTEROS [0..15]
    // ============================
    // Estos los usa tu código entero con lw/sw
    RAM[0] = 32'd10;  // valor para lw x15, 0(x0)
    RAM[1] = 32'd3;   // puedes usarlo si luego amplías el test
    RAM[2] = 32'd0;   // será pisado por sw x5, 8(x0)
    RAM[3] = 32'd5;   // opcional, por si luego pruebas algo más
    // RAM[4..15] quedan en 0

    // ============================
    //   ZONA FLOATING POINT [16..27]
    // ============================
    // IEEE-754 Single Precision (32 bits)
    RAM[16] = 32'h3f800000;  // 1.0
    RAM[17] = 32'h40000000;  // 2.0
    RAM[18] = 32'h40400000;  // 3.0
    RAM[19] = 32'h40800000;  // 4.0
    RAM[20] = 32'h3f800000;  // 1.0
    RAM[21] = 32'h3f400000;  // 0.75
    RAM[22] = 32'h40800000;  // 4.0
    RAM[23] = 32'h00000000;  // 0.0
    RAM[24] = 32'hbf800000;  // -1.0
    RAM[25] = 32'h7fc00000;  // NaN (quiet NaN)
    RAM[26] = 32'h7f800000;  // +Infinity
    RAM[27] = 32'h40a00000;  // 5.0
    // RAM[28..63] quedan en 0
  end

  assign rd = RAM[a[31:2]]; // word aligned

  always @(posedge clk) begin 
    if (we) RAM[a[31:2]] <= wd; 
  end
endmodule
