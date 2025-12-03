// Controlador extendido con soporte para punto flotante
module controller_fp(
  input  [6:0] op,
  input  [2:0] funct3,
  input        funct7b5,
  input  [6:0] funct7,      // Extendido para FP
  input        Zero,
  
  output [1:0] ResultSrc, 
  output MemWrite,
  output PCSrc, ALUSrc,
  output RegWrite, Jump,
  output Branch,
  output [2:0] ImmSrc,
  output [2:0] ALUControl,
  // Señales FP
  output       isFP, //
  output       isMatmul,     // 1 si es instrucción matmul
  output [3:0] FPLatency,
  output [2:0] FALUControl,  // Control para FALU (3 bits): 000=fadd, 001=fsub, 010=fmul, 011=fdiv, 100=matmul
  output       FPRegWrite,   // Escritura en register file FP (isFP && RegWrite)
  output       FPMemWrite,   // Escritura en memoria FP (isFP && MemWrite)
  output       VRegWrite     // Escritura en register file vectorial (isMatmul && RegWrite)
);
  
  wire [1:0] ALUOp; 
  
  // Decodificador principal (sin cambios)
  maindec md(
    .op(op), 
    .ResultSrc(ResultSrc), 
    .MemWrite(MemWrite), 
    .Branch(Branch),
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWrite), 
    .Jump(Jump), 
    .ImmSrc(ImmSrc), 
    .ALUOp(ALUOp)
  ); 
  
  // Decodificador ALU entera (sin cambios)
  aludec ad(
    .opb5(op[5]), 
    .funct3(funct3), 
    .funct7b5(funct7b5), 
    .ALUOp(ALUOp), 
    .ALUControl(ALUControl)
  );
  
  // Decodificador FP único (consolida todo)
  fpdec fp_d(
    .op(op),
    .funct3(funct3),
    .funct7(funct7),
    .ALUOp(ALUOp),              // ALUOp para distinguir aritméticas (11) de load/store (00)
    .isFP(isFP),
    .isMatmul(isMatmul),        // Señal para matmul
    .FALUControl(FALUControl)  // Control FALU (3 bits): 000=fadd, 001=fsub, 010=fmul, 011=fdiv, 100=matmul
  );
  
  // Calcular latencia según operación FP (usando FALUControl directamente)
  // FALUControl: 000=fadd, 001=fsub, 010=fmul, 011=fdiv
  // NOTA: La FALU es combinacional, todas las operaciones tienen 1 ciclo de latencia real
  // Las latencias mayores eran artificiales. Ahora todas son 1 ciclo.
  // Usamos 4 bits para latencia (máximo 15 ciclos)
  assign FPLatency = (isFP && (FALUControl == 3'b000 || FALUControl == 3'b001)) ? 4'b0001 :  // ADD/SUB: 1
                     (isFP && (FALUControl == 3'b010)) ? 4'b0001 :                            // MUL: 1 (combinacional)
                     (isFP && (FALUControl == 3'b011)) ? 4'b0001 :                            // DIV: 1 (combinacional)
                     4'b0000;
  
  // Señales de control FP derivadas
  // FPRegWrite: para operaciones aritméticas FP (isFP) Y para flw (load FP)
  // FPMemWrite: para fsw (store FP)
  // VRegWrite: para matmul (escritura en RF vectorial)
  wire isFLW = (op == 7'b0000111);  // flw (load word FP)
  wire isFSW = (op == 7'b0100111);  // fsw (store word FP)
  assign FPRegWrite = (isFP && RegWrite) || (isFLW && RegWrite);  // Aritméticas FP o flw
  assign FPMemWrite = isFSW && MemWrite;   // Solo fsw
  assign VRegWrite = isMatmul && RegWrite; // Solo matmul escribe en RF vectorial
  
  assign PCSrc = Branch & Zero | Jump; 
endmodule

