`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Módulo de manejo de casos especiales IEEE 754 Half-Precision
// Incluye detección de NaN, Inf, denormales, y generación de resultados especiales
//////////////////////////////////////////////////////////////////////////////////

// ============== DETECCIÓN DE CASOS ESPECIALES EN OPERANDOS ==============
module fp16_classifier #(parameter MBS=9, parameter EBS=4, parameter BS=15)(
  input [BS:0] val,
  output is_zero,
  output is_denorm,
  output is_normal,
  output is_inf,
  output is_nan,
  output sign
);
  wire [EBS:0] exp = val[BS-1: BS-EBS-1];
  wire [MBS:0] man = val[MBS:0];
  
  assign sign = val[BS];
  // {EBS+1{1'b1}} <- Cadena de EBS+1 bits de 1's
  // {MBS+1{1'b0}} <- Cadena de MBS+1 bits de 0's
  
  // Zero: exp=0, man=0
  assign is_zero = (exp == {EBS+1{1'b0}}) && (man == {MBS+1{1'b0}});
  
  // Denormal: exp=0, man≠0
  assign is_denorm = (exp == {EBS+1{1'b0}}) && (man != {MBS+1{1'b0}});
  
  // Normal: 0 < exp < 31
  assign is_normal = (exp != {EBS+1{1'b0}}) && (exp != {EBS+1{1'b1}});
  
  // Infinity: exp=31, man=0
  assign is_inf = (exp == {EBS+1{1'b1}}) && (man == {MBS+1{1'b0}});
  
  // NaN: exp=31, man≠0
  assign is_nan = (exp == {EBS+1{1'b1}}) && (man != {MBS+1{1'b0}});
endmodule

// ============== GENERADOR DE VALORES ESPECIALES ==============
module fp16_special_values #(parameter MBS=9, parameter EBS=4, parameter BS=15) (
  sign_in,
  pos_zero,
  neg_zero,
  pos_inf,
  neg_inf,
  qnan,        // Quiet NaN (señalización silenciosa)
  snan,        // Signaling NaN (señalización activa)
  signed_inf,  // Infinity con signo variable
  signed_zero  // Zero con signo variable
);
  input sign_in;
  output [BS:0] pos_zero, neg_zero, pos_inf, neg_inf, qnan, snan, signed_inf, signed_zero;
  wire is_half = (BS == 15);
  // Valores hardcodeados IEEE 754
  assign pos_zero = is_half ? 16'h0000 : 32'h00000000;  // +0.0
  assign neg_zero = is_half ? 16'h8000 : 32'h80000000;  // -0.0
  assign pos_inf  = is_half ? 16'h7C00 : 32'h7F800000;  // +Infinity
  assign neg_inf  = is_half ? 16'hFC00 : 32'hFF800000;  // -Infinity
  assign qnan     = is_half ? 16'h7E00 : 32'h7FC00000;  // Quiet NaN (canonical)
  assign snan     = is_half ? 16'h7D00 : 32'h7F800001;  // Signaling NaN
  
  // Con signo parametrizable
  assign signed_inf  = sign_in ? neg_inf : pos_inf;
  assign signed_zero = sign_in ? neg_zero : pos_zero;
endmodule

// ============== MANEJO DE CASOS ESPECIALES POR OPERACIÓN ==============
module fp16_special_case_handler #(parameter MBS=9, parameter EBS=4, parameter BS=15)(
  input [BS:0] a,
  input [BS:0] b,
  input [1:0] op,  // 00=ADD, 01=SUB, 10=MUL, 11=DIV
  
  output is_special_case,
  output [BS:0] special_result,
  output invalid_op,
  output div_by_zero
);
  // Clasificar operandos
  wire a_zero, a_denorm, a_normal, a_inf, a_nan, a_sign;
  wire b_zero, b_denorm, b_normal, b_inf, b_nan, b_sign;
  
  fp16_classifier #(.MBS(MBS), .EBS(EBS), .BS(BS))
  class_a(a, a_zero, a_denorm, a_normal, a_inf, a_nan, a_sign);
  fp16_classifier #(.MBS(MBS), .EBS(EBS), .BS(BS))
  class_b(b, b_zero, b_denorm, b_normal, b_inf, b_nan, b_sign);
  
  // Valores especiales
  wire [BS:0] pos_zero, neg_zero, pos_inf, neg_inf, qnan, snan;
  wire [BS:0] signed_inf_a, signed_zero_a;
  
  fp16_special_values #(.MBS(MBS), .EBS(EBS), .BS(BS)) 
  special(
    a_sign, pos_zero, neg_zero, pos_inf, neg_inf, qnan, snan,
    signed_inf_a, signed_zero_a
  );
  
  // Calcular signo del resultado (fuera del always)
  wire result_sign = a_sign ^ b_sign;
  
  // ==================== DETECCIÓN DE CASOS ESPECIALES ====================
  
  reg is_special;
  reg [BS:0] result;
  reg invalid;
  reg div_zero;
  
  always @(*) begin
    is_special = 1'b0;
    result = {BS+1{1'b0}};
    invalid = 1'b0;
    div_zero = 1'b0;
    
    // ====== CASO 1: Operandos NaN ======
    if (a_nan || b_nan) begin
      is_special = 1'b1;
      result = qnan;
      invalid = 1'b1;
    end
    
    // ====== CASO 2: SUMA/RESTA ======
    else if (op == 2'b00 || op == 2'b01) begin
      // Inf + Inf (signos iguales) = Inf
      // Inf - Inf (signos iguales) = NaN (INVALID)
      if (a_inf && b_inf) begin
        is_special = 1'b1;
        if ((op == 2'b00 && a_sign == b_sign) ||
            (op == 2'b01 && a_sign != b_sign)) begin
          result = signed_inf_a;
        end else begin
          result = qnan;
          invalid = 1'b1;
        end
      end
      // Inf + x = Inf
      else if (a_inf) begin
        is_special = 1'b1;
        result = a;
      end
      else if (b_inf) begin
        is_special = 1'b1;
        result = (op == 2'b00) ? b : {~b[BS], b[BS-1:0]};
      end
      // 0 + 0 = +0 (excepto -0 + -0 = -0)
      else if (a_zero && b_zero) begin
        is_special = 1'b1;
        result = (a_sign && b_sign) ? neg_zero : pos_zero;
      end
      // ? NUEVO: Denormal + 0 = Denormal
      else if (a_denorm && b_zero) begin
        is_special = 1'b1;
        result = a;
      end
      else if (a_zero && b_denorm) begin
        is_special = 1'b1;
        result = (op == 2'b00) ? b : {~b[BS], b[BS-1:0]};
      end
    end
    
    // ====== CASO 3: MULTIPLICACIÓN ======
    else if (op == 2'b10) begin
      // Inf × 0 = NaN (INVALID)
      if ((a_inf && b_zero) || (a_zero && b_inf)) begin
        is_special = 1'b1;
        result = qnan;
        invalid = 1'b1;
      end
      // Inf × x = ±Inf (x≠0)
      else if (a_inf || b_inf) begin
        is_special = 1'b1;
        result = result_sign ? neg_inf : pos_inf;
      end
      // 0 × x = ±0
      else if (a_zero || b_zero) begin
        is_special = 1'b1;
        result = result_sign ? neg_zero : pos_zero;
      end
    end
    
    // ====== CASO 4: DIVISIÓN ======
    else if (op == 2'b11) begin
      // 0 / 0 = NaN (INVALID)
      if (a_zero && b_zero) begin
        is_special = 1'b1;
        result = result_sign ? neg_zero : pos_zero;
        invalid = 1'b1;
      end
      // Inf / Inf = NaN (INVALID)
      else if (a_inf && b_inf) begin
        is_special = 1'b1;
        result = qnan;
        invalid = 1'b1;
      end
      // x / 0 = ±Inf (DIVIDE BY ZERO, x≠0)
      else if (b_zero && !a_zero) begin
        is_special = 1'b1;
        result = result_sign ? neg_inf : pos_inf;
        div_zero = 1'b1;
      end
      // Inf / x = ±Inf (x≠Inf)
      else if (a_inf && !b_inf) begin
        is_special = 1'b1;
        result = result_sign ? neg_inf : pos_inf;
      end
      // x / Inf = ±0
      else if (b_inf && !a_inf) begin
        is_special = 1'b1;
        result = result_sign ? neg_zero : pos_zero;
      end
      // 0 / x = ±0 (x≠0)
      else if (a_zero && !b_zero) begin
        is_special = 1'b1;
        result = result_sign ? neg_zero : pos_zero;
      end
    end
  end
  
  assign is_special_case = is_special;
  assign special_result = result;
  assign invalid_op = invalid;
  assign div_by_zero = div_zero;
  
endmodule

// ============== FLAGS IEEE 754 COMPLETOS ==============
module fp16_flags #(parameter MBS=9, parameter EBS=4, parameter BS=15) (
  result, a, b, op,
  core_overflow, core_underflow, core_inexact,
  special_invalid, special_div_zero,
  overflow, underflow, inexact, invalid, div_by_zero
);
  input [BS:0] result, a, b;
  input [1:0] op;
  input core_overflow, core_underflow, core_inexact;
  input special_invalid, special_div_zero;
  wire is_pos_inf;
  wire is_neg_inf;
  is_inf_detector #(.MBS(MBS), .EBS(EBS), .BS(BS))
  inf_det(
    .value(result),
    .is_posInf(is_pos_inf),
    .is_negInf(is_neg_inf)
  );
  output overflow, underflow, inexact, invalid, div_by_zero;

  wire [EBS:0] exp_result = result[BS-1:BS-EBS-1];
  wire [MBS:0] man_result = result[MBS:0];
  
  // Clasificar resultado
  wire res_inf = (exp_result == {EBS+1{1'b1}}) && (man_result == {MBS+1{1'b0}});
  wire res_nan = (exp_result == {EBS+1{1'b1}}) && (man_result != {MBS+1{1'b0}});
  wire res_denorm = (exp_result == {EBS+1{1'b0}}) && (man_result != {MBS+1{1'b0}});
  
  // OVERFLOW: resultado es infinito (no NaN)
  assign overflow = res_inf || core_overflow || is_pos_inf;
  
  // UNDERFLOW: resultado es denormal o flushed a cero con inexactitud
  assign underflow = res_denorm || core_underflow || is_neg_inf;
  
  // INEXACT: redondeo cambió el resultado
  assign inexact = core_inexact || underflow;
  
  // INVALID: operación no válida (NaN generado)
  assign invalid = res_nan || special_invalid;
  
  // DIVIDE BY ZERO: división por cero (genera infinito)
  assign div_by_zero = special_div_zero;
  
endmodule


