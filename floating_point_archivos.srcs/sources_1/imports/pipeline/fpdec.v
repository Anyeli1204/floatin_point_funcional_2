module fpdec(
  input  [6:0] op,
  input  [2:0] funct3,
  input  [6:0] funct7,
  input  [1:0] ALUOp,             // Señal ALUOp para distinguir aritméticas de load/store
  output       isFP,              // 1 si es instrucción FP
  output [2:0] FALUControl         // Control para FALU: 000=fadd, 001=fsub, 010=fmul, 011=fdiv
);

  // SOLO detectar operaciones aritméticas FP (ALUOp = 11)
  // flw/fsw (ALUOp = 00) NO se detectan aquí, se manejan en maindec y usan ALU normal
  wire isFPArithOp = (op == 7'b1010011) && (ALUOp == 2'b11);
  
  // isFP = 1 solo para operaciones aritméticas FP (fadd, fsub, fmul, fdiv)
  // flw/fsw NO generan isFP = 1, usan ALU entera normalmente
  assign isFP = isFPArithOp;
  
  // Decodificar FALUControl según funct7 completo
  // SOLO para operaciones aritméticas FP (ALUOp = 11)
  // funct7 = 0x00 → FADD.S → FALUControl = 000
  // funct7 = 0x04 → FSUB.S → FALUControl = 001
  // funct7 = 0x08 → FMUL.S → FALUControl = 010
  // funct7 = 0x0C → FDIV.S → FALUControl = 011
  reg [2:0] FALUControl_reg;
  assign FALUControl = FALUControl_reg;
  
  always @(*) begin
    // Solo generar FALUControl válido si es operación aritmética FP (ALUOp = 11)
    if (isFPArithOp) begin  // Operación aritmética FP
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


