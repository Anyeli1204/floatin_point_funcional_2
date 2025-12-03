module fpdec(
  input  [6:0] op,
  input  [2:0] funct3,
  input  [6:0] funct7,
  input  [1:0] ALUOp,             // Señal ALUOp para distinguir aritméticas de load/store
  output       isFP,              // 1 si es instrucción FP
  output       isMatmul,          // 1 si es instrucción matmul
  output [2:0] FALUControl         // Control para FALU: 000=fadd, 001=fsub, 010=fmul, 011=fdiv, 100=matmul
);

  // SOLO detectar operaciones aritméticas FP (ALUOp = 11)
  // flw/fsw (ALUOp = 00) NO se detectan aquí, se manejan en maindec y usan ALU normal
  // Asegurar que las comparaciones siempre tengan valores definidos
  wire op_match = (op == 7'b1010011);
  wire funct7_match = (funct7 == 7'b0100000);
  wire funct3_match = (funct3 == 3'b000);
  wire aluop_match = (ALUOp == 2'b11);
  
  wire isFPArithOp = op_match && aluop_match;
  
  // Detectar matmul: op=1010011, funct7=0100000, funct3=000, ALUOp=11
  // Asegurar que siempre tenga un valor definido (0 o 1, nunca X o Z)
  wire isMatmulOp = op_match && funct7_match && funct3_match && aluop_match;
  
  // isFP = 1 solo para operaciones aritméticas FP (fadd, fsub, fmul, fdiv)
  // matmul NO es FP aritmética, es una operación especial
  // flw/fsw NO generan isFP = 1, usan ALU entera normalmente
  assign isFP = isFPArithOp && !isMatmulOp;  // FP pero no matmul
  // Asegurar que isMatmul siempre tenga un valor definido (0 o 1, nunca X o Z)
  assign isMatmul = isMatmulOp ? 1'b1 : 1'b0;
  
  // Decodificar FALUControl según funct7 completo
  // SOLO para operaciones aritméticas FP (ALUOp = 11)
  // funct7 = 0x00 → FADD.S → FALUControl = 000
  // funct7 = 0x04 → FSUB.S → FALUControl = 001
  // funct7 = 0x08 → FMUL.S → FALUControl = 010
  // funct7 = 0x0C → FDIV.S → FALUControl = 011
  reg [2:0] FALUControl_reg;
  assign FALUControl = FALUControl_reg;
  
  always @(*) begin
    // Prioridad: matmul primero, luego FP aritmética
    if (isMatmulOp) begin
      // matmul: FALUControl = 100
      FALUControl_reg = 3'b100;
    end else if (isFPArithOp) begin  // Operación aritmética FP
      case (funct7)
        7'b0000000: FALUControl_reg = 3'b000; // fadd.s (funct7 = 0x00)
        7'b0000100: FALUControl_reg = 3'b001; // fsub.s (funct7 = 0x04)
        7'b0001000: FALUControl_reg = 3'b010; // fmul.s (funct7 = 0x08)
        7'b0001100: FALUControl_reg = 3'b011; // fdiv.s (funct7 = 0x0C)
        default:    FALUControl_reg = 3'b000; // Por defecto fadd
      endcase
    end else begin
      // Para flw/fsw (ALUOp = 00) o no-FP, FALUControl no se usa
      // IMPORTANTE: Usar un valor que no corresponda a ninguna operación válida
      // 3'b100, 3'b101, 3'b110, 3'b111 no se usan en nuestro diseño
      FALUControl_reg = 3'b111;  // Valor don't care (no se usa, evita confusión con fadd=000)
    end
  end
  

endmodule


