`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// MÓDULO: Division
// Entradas:
//   - Sm, Rm    : mantisas extendidas [MBS+1:0] (1 implícito + MBS bits)
//   - ExpIn     : exponente efectivo previo a redondeo
// Salidas:
//   - Fm        : fracción final [MBS:0]
//   - ExpOut    : exponente final [EBS:0]
//   - underflow : indica tininess al final (ExpOut=0 e inexact)
//   - inexact   : pérdida de precisión por guard/sticky/rest/remainder
// Parámetros auxiliares:
//   - FSIZE = MBS + 5 → ancho del paquete de redondeo (mantisa + guard + rest + sticky)
// -----------------------------------------------------------------------------
module Division #(parameter MBS=9, EBS=4, BS=15) (Sm, Rm, ExpIn, Fm, ExpOut,
  underflow, inexact);
  input [MBS+1:0] Sm, Rm;
  input [EBS:0] ExpIn;
  output wire [MBS:0] Fm;
  output wire [EBS:0] ExpOut;
  output        underflow, inexact;

  parameter FSIZE = MBS + 5;

  // ------------------------- Localizador de '1' líder -------------------------
  // first_one_div(bits): devuelve la distancia para normalizar llevando la
  // primera '1' hacia la posición de bit implícito tras la división.
  function [EBS:0] first_one_div;
    input [FSIZE+2:0] bits;
    integer idx;
    reg found;
    
    begin
      found = 0;
      first_one_div = {EBS+1{1'b0}}; 
      
      for (idx = FSIZE; idx >= 0 && !found; idx = idx - 1) begin
        if (bits[idx]) begin
          first_one_div = (FSIZE + 1 - idx);
          found = 1;
        end
      end
    end
  
  endfunction

  // 15'b0 <- 5 evaluar redondeo + 10 se puros 0's.
  // Resultado crudo: desplazamos el dividendo para obtener suficientes bits
  // fraccionarios y luego dividimos por Rm.
  wire [FSIZE + 10:0] Result = {Sm, {FSIZE+1{1'b0}}} / Rm;
  wire [FSIZE + 2: 0] Faux = Result[FSIZE+2: 0];
  // MSB del cociente extendido (Debe) y condición para normalizar por 'shift'
  wire Debe = Faux[FSIZE + 2];
  wire ShiftCondition = !Debe && !Faux[FSIZE + 1];
  // Si hace falta normalizar (producto demasiado pequeño), calculamos 'shifts'
  // con first_one_div; si ya está normalizado, no desplazamos.
  wire [EBS:0] shifts = (ShiftCondition) ? first_one_div(Faux) : {EBS+1{1'b0}};
  wire [FSIZE:0] Fm_out = (Debe) ? Faux[FSIZE+1: 1] : (Faux[FSIZE: 0] << shifts);
  wire[EBS:0] ExpOut_temp = (Debe) ? (ExpIn+1) : (ExpIn - shifts);
  // Redondeo a par (RNE) sobre paquete {mantisa_normalizada, guard, rest, sticky}
  RoundNearestEven #(.MBS(MBS), .EBS(EBS), .BS(BS), .FSIZE(FSIZE)) rounder(
    .ms(Fm_out),
    .exp(ExpOut_temp),
    .ms_round(Fm),
    .exp_round(ExpOut)
  );

  // ----------------------------- Sección de flags -----------------------------
  // "remainder" de la división (después del shift previo) y detectores auxiliares
  wire [MBS+1:0] remainder  = {Sm, {FSIZE+1{1'b0}}} % Rm;
  wire        rem_nz     = |remainder;
  // Bit perdido previo (LSB antes del corrimiento por Debe) y máscara de bajo nivel
  wire lost_pre_bit      = (Debe) ? Faux[0] : 1'b0;
  wire [FSIZE + 2:0] low_mask   = (1 << shifts) - 1;
  // Bits perdidos por el desplazamiento de normalización cuando no hubo Debe
  wire        lost_shift_bits = (!Debe && (shifts!=0)) ? (|(Faux & low_mask)) : 1'b0;
  // guard y "cola" de bits tras la mantisa para evaluar redondeo/inexactitud
  wire guard_bit    = Fm_out[4];
  wire tail_bits_nz = |Fm_out[3:0];
  // inexact: cualquier evidencia de bits perdidos o residuo ≠ 0
  assign inexact   = guard_bit | tail_bits_nz | lost_pre_bit | lost_shift_bits | rem_nz;
  // underflow: tininess al final (exponente cero y resultado inexacto)
  assign underflow = (ExpOut == {EBS+1{1'b0}}) & inexact;
endmodule

// -----------------------------------------------------------------------------
// MÓDULO: DivHP
// Propósito: División IEEE-754 a nivel del formato completo (signo/exp/fracción).
//  1) Desempaqueta S y R; calcula signo y exponente efectivo con bias.
//  2) Prepara mantisas con 1 implícito y llama a Division (núcleo).
//  3) Compone el resultado final y evalúa flags (invalid/overflow/underflow/inexact).
// -----------------------------------------------------------------------------
module DivHP #(parameter MBS=9, parameter EBS=4, parameter BS=15) (S, R, F, 
  overflow, underflow, inv_op, inexact);
  
  input [BS:0] S, R;
  output wire [BS:0] F;
  output overflow, underflow, inv_op, inexact;
  wire over_op_handle, under_op_handle;
  // Desempaquetado de campos IEEE-754
  wire[MBS:0] m1 = S[MBS:0];
  wire[MBS:0] m2 = R[MBS:0];
  
  wire[EBS:0] e1 = S[BS-1: BS-EBS-1];
  wire[EBS:0] e2 = R[BS-1: BS-EBS-1];
  
  wire s1 = S[BS];
  wire s2 = R[BS];
  wire sign = s1 ^ s2;
  // Detectores de ceros (dividendo/divisor). Si dividendo=0 y divisor≠0 → F=0.
  wire is_zero_dividend = (e1 == {EBS+1{1'b0}}) && (m1 == {EBS+1{1'b0}});
  wire is_zero_divisor  = (e2 == {EBS+1{1'b0}}) && (m2 == {EBS+1{1'b0}});
  // Bias según formato: 15 (half) o 127 (single)
  wire [7:0] bias = (EBS == 4) ? 8'd15 : 8'd127;
       
  // Suma de exponentes en el producto. FALTA CAMBIAR ESTE 15 POR BIAS
  // Exponente efectivo para la división y auxiliares de flags por exponente
  wire [EBS:0] exp_to_use = e1 - e2 + bias;
  wire [EBS+1:0] evaluate_flags = e1 + bias;
  wire [EBS+1:0] despues_la_borro = e1 - e2 + bias;
    
  // Mantisas con 1 implícito para el núcleo
  wire [MBS+1:0] param_m1 = {1'b1, m1};
  wire [MBS+1:0] param_m2 = {1'b1, m2};
  
  // Resultado del núcleo Division
  wire [MBS:0] m_final;
  wire [EBS:0] exp_final;
  wire uf_core, ix_core;
  Division #(.MBS(MBS), .EBS(EBS), .BS(BS)) 
  div(param_m1, param_m2, exp_to_use, m_final, exp_final, 
      uf_core, ix_core);
  
  // Composición del número IEEE-754 final (manejo explícito del caso dividendo=0)
  assign F[BS] = (is_zero_dividend && !is_zero_divisor) ? 1'b0 : sign;
  assign F[BS-1: BS-EBS-1] = (is_zero_dividend && !is_zero_divisor) ? {EBS+1{1'b0}} : exp_final;
  assign F[MBS: 0] = (is_zero_dividend && !is_zero_divisor) ? {MBS+1{1'b0}} : m_final;
  
  // ------------------- Flags ---------------------
  // Operación inválida en entrada (Inf/NaN combinaciones), a cargo del detector
  is_invalid_op #(.MBS(MBS), .EBS(EBS), .BS(BS)) flag4(
    .Exp1(e1), .Exp2(e2), .Man1(m1), .Man2(m2), .InvalidOp(inv_op)
  );
  // Manejo adicional de over/under por exponente (heurístico a nivel wrapper)
  assign over_op_handle = (evaluate_flags >= e2 && despues_la_borro >= {1'b0, {(EBS+1){1'b1}}});
  assign under_op_handle = (evaluate_flags < e2);
  assign overflow  = (is_zero_dividend && !is_zero_divisor) ? 1'b0 : 1'b0 || over_op_handle;
  assign underflow = (is_zero_dividend && !is_zero_divisor) ? 1'b0 : uf_core || under_op_handle;
  assign inexact   = (is_zero_dividend && !is_zero_divisor) ? 1'b0 : ix_core;
endmodule


