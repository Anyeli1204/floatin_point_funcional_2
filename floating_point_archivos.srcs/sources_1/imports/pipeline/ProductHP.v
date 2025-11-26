/* ============================================================================
   Estructura principal:
     - Prod      : n�cleo de multiplicaci�n de mantisas + normalizaci�n + RNE
     - ProductHP : wrapper a nivel de n�mero IEEE-754 (signo/exponente/mantisa)
   Par�metros comunes:
     - MBS: �ndice m�x. de la fracci�n (mantisa sin 1 impl�cito)
     - EBS: �ndice m�x. del exponente
     - BS : �ndice m�x. del ancho total (signo+exponente+fracci�n)
============================================================================ */
`timescale 1ns / 1ps

/* ---------------------------------------------------------------------------
   M�DULO: Prod
   PROP�SITO: Multiplicar mantisas (con 1 impl�cito ya agregado), normalizar el
              producto y redondear a "round-to-nearest, ties-to-even" (RNE).
   ENTRADAS:
     - Sm, Rm   : mantisas extendidas (1 impl�cito + MBS bits) => [MBS+1:0]
     - ExpIn    : exponente preajustado que acompa�a al producto de mantisas
   SALIDAS:
     - Fm       : fracci�n final (MBS:0) tras normalizar y redondear
     - ExpOut   : exponente ajustado por normalizaci�n/redondeo
     - overflow : indicador de overflow (a nivel de exponente)
     - inexact  : hubo p�rdida de precisi�n (guard/rest)
   NOTAS DE IMPLEMENTACI�N:
     1) Result = Sm*Rm; se detecta bit alto (Debe) para saber si el producto est�
        en [2,4) (bit MSB=1) o en [1,2) (bit MSB=0). Con ello se decide el shift.
     2) If !Debe && !Result[MSIZE-1] ? el producto est� por debajo de 1.x, se
        localiza la primera '1' (first_one) para normalizar a 1.xx.
     3) Se empaquetan los bits para redondeo: top10 + guard + rest(3) + sticky.
     4) RoundNearestEven ajusta mantisa y, si corresponde, exponente.
---------------------------------------------------------------------------- */
module Prod #(parameter MBS=9, parameter EBS=4, parameter BS=15) (Sm, Rm, ExpIn, Fm, ExpOut, 
  overflow, inexact);
  
  input [MBS+1:0] Sm, Rm;
  input [EBS:0] ExpIn;
  output wire [MBS:0] Fm;
  output wire [EBS:0] ExpOut;
  output        overflow, inexact;

  // Tama�os derivados: ancho del paquete de redondeo (FSIZE),
  // producto crudo de mantisas (MSIZE+1 bits) y "steam" intermedio.
  parameter FSIZE = MBS + 5;
  parameter MSIZE = MBS + MBS + 3;
  parameter STEAMSIZE = MBS + MBS + 3 + 6;
  
  // ------------ Function Section -------------
  // first_one: devuelve cu�ntas posiciones desplazar para llevar la primera '1'
  // a la posici�n normalizada (cuenta desde zona alta del producto).
  function [EBS:0] first_one;
  
    input [MBS+1 + MBS+1 :0] bits;
    integer idx;
    reg found;
    
    begin
      found = 0;
      first_one = 5'b00000; 
      
      // MBS + MBS + 1 + 1 - 2  ("-2" por la forma xx.mantisa)
      for (idx = MBS + MBS; idx >= 9 && !found; idx = idx - 1) begin
        if (bits[idx]) begin
          first_one = (MBS + MBS + 2 - idx);
          found = 1;
        end
      end

    end
  
  endfunction

  // ------------ Op Section -------------
  // Producto crudo de mantisas con 1 impl�cito. MSB => Debe (bit de acarreo alto).
  wire [MSIZE: 0] Result = Sm * Rm;
  wire Debe = Result[MSIZE];

  // Criterio de normalizaci�n inicial: si no hay MSB ni el bit siguiente, hay que
  // buscar la primera '1' para escalar (producto demasiado peque�o).
  wire ShiftCondition = !Debe && !Result[MSIZE - 1];
  wire [EBS + 5:0] shifts = (ShiftCondition) ? first_one(Result) : 5'b00000;

  // Exponente previo al redondeo: si hubo Debe, el valor est� en [2,4) ? +1.
  // De lo contrario, se resta el n�mero de shifts necesarios para normalizar.
  wire [EBS:0] exp_pre = (Debe) ? (ExpIn + 1) : (ExpIn - shifts);

  // Secuencia de "streams":
  //  - stream0: concatena resultado con 6 ceros para disponer de guard/rest/sticky.
  //  - stream1: corrige la posici�n base en funci�n de Debe (MBS+2 vs MBS+1).
  //  - stream2: aplica desplazamiento de normalizaci�n si hizo falta (ShiftCondition).
  wire [STEAMSIZE: 0] stream0 = {Result[MSIZE: 0], 6'b0};           
  wire [STEAMSIZE: 0] stream1 = Debe ? (stream0 >> MBS + 2) : (stream0 >> MBS + 1);
  wire [STEAMSIZE: 0] stream2 = ShiftCondition ? (stream1 << shifts) : stream1;

  // top10 (10), guard (1), rest3 (3) + sticky (1)
  // Genera 5 bits en el LSB para el redondeo
  wire [MBS:0] top10  = stream2[MBS+6 :6];
  wire       guard  = stream2[5];
  wire [2:0] rest3  = stream2[4:2];
  wire       sticky = |stream2[1:0];                     // OR de lo que queda
  wire [3:0] rest4  = {rest3, sticky};

  // Paquete de 15 bits (FSIZE+1) para el redondeo RNE
  wire [FSIZE: 0] ms15 = {top10, guard, rest4};

  // Redondeo al par (RoundNearestEven)
  wire [MBS:0] frac_rnd;
  wire [EBS:0] exp_rnd;
  RoundNearestEven #(.MBS(MBS), .EBS(EBS), .BS(BS), .FSIZE(FSIZE))
  rne_mul(.ms(ms15), .exp(exp_pre), .ms_round(frac_rnd), .exp_round(exp_rnd));

  // Salidas finales de Prod
  assign Fm     = frac_rnd;
  assign ExpOut = exp_rnd;

  // ------------ Flag Section -------------  
  // inexact: si guard o cualquier bit de "rest"/"sticky" es 1, hubo redondeo.
  wire h_overflow;
  
  // Si en la parte adicional hay almenos 1 bit de 1, la operaci�n es inexacta.
  assign inexact = guard | |rest4;
  
  // Verificaci�n de overflow a partir de ExpIn y +1 (por posible Debe)
  is_overflow #(.MBS(MBS), .EBS(EBS), .BS(BS))
  flag2(.Exp(ExpIn), .AddExp(5'b00001), .OverFlow(h_overflow));
  
  assign overflow = (Debe) ? h_overflow : 1'b0;
  
endmodule



/* ---------------------------------------------------------------------------
   M�DULO: ProductHP
   PROP�SITO: Multiplicaci�n IEEE-754 (half/single) a nivel del formato completo.
              Extrae signo/exponente/mantisa, invoca Prod para mantisas y compone
              el resultado final con flags.
   ENTRADAS:
     - S, R     : operandos IEEE-754 (signo+exp+frac) de ancho (BS+1)
   SALIDAS:
     - F        : resultado IEEE-754 (BS:0)
     - overflow, underflow, inv_op, inexact: indicadores de estado
   FLUJO:
     1) signo = s1 ^ s2. Detecci�n r�pida de ceros (si uno es cero ? resultado cero).
     2) bias = 15 (half) o 127 (single) seg�n EBS. exp_to_use = e1 + e2 - bias.
     3) Se forma {1, m} para cada operando y se llama a Prod.
     4) Se compone F con signo/exp/frac finales. Flags se derivan de sumas de exp
        (over/under) y de Prod (over_t2, inexact_core), m�s validez (inv_op).
---------------------------------------------------------------------------- */
// #(parameter N=8), LUEGO adaptar con parameter a 32 bits.
module ProductHP #(parameter MBS=9, parameter EBS=4, parameter BS=15) (S, R, F,
  overflow, underflow, inv_op, inexact);
  
  input [BS:0] S, R;
  output wire [BS:0] F;
  output overflow, underflow, inv_op, inexact;
  
  // Desempaquetado IEEE-754
  wire[MBS:0] m1 = S[MBS:0];
  wire[MBS:0] m2 = R[MBS:0];
  
  wire[EBS:0] e1 = S[BS-1: BS-EBS-1];
  wire[EBS:0] e2 = R[BS-1: BS-EBS-1];
  
  wire s1 = S[BS];
  wire s2 = R[BS];
  wire sign = s1^s2;

  // Detecci�n de ceros en entradas (resultado cero conserva signo=0)
  wire is_zero_s = (e1 == {EBS+1{1'b0}}) && (m1 == {EBS+1{1'b0}});
  wire is_zero_r = (e2 == {EBS+1{1'b0}}) && (m2 == {EBS+1{1'b0}});
  wire result_is_zero = is_zero_s | is_zero_r;

  // C�lculo de bias y exponentes auxiliares
  wire [7:0] bias = (EBS == 4) ? 8'd15 : 8'd127;
  wire [EBS:0] exp_to_use = e1 + e2 - bias;
  wire [EBS+1:0] evaluate_flags  = e1 + e2;
  wire [EBS+1:0] despues_la_borro= e1 + e2 - bias;

  // Mantisas con 1 impl�cito para el n�cleo Prod
  wire [MBS+1:0] param_m1 = {1'b1, m1};
  wire [MBS+1:0] param_m2 = {1'b1, m2};
  
  // Resultado de Prod
  wire [MBS:0] m_final;
  wire [EBS:0] exp_final;
  wire over_t2, inexact_core;

  Prod #(.MBS(MBS), .EBS(EBS), .BS(BS)) 
  product_mantisa(param_m1, param_m2, exp_to_use, m_final, exp_final, over_t2, inexact_core);

  // Composici�n del n�mero IEEE-754 final (manejo de caso cero)
  assign F[BS]    = result_is_zero ? 1'b0 : sign;
  assign F[BS-1:BS-EBS-1] = result_is_zero ? {EBS+1{1'b0}} : exp_final;
  assign F[MBS:0]   = result_is_zero ? {MBS+1{1'b0}} : m_final;

  // ------------------- Flags ---------------------
  // invalid_op depende de combinaciones no v�lidas en entradas (p.ej., Inf*0)
  is_invalid_op #(.MBS(MBS), .EBS(EBS), .BS(BS))
  flag4(.Exp1(e1), .Exp2(e2), .Man1(m1), .Man2(m2), .InvalidOp(inv_op));

  // Heur�sticas de overflow/underflow por suma de exponentes previa a normalizar
  wire over_t1   = (evaluate_flags >= bias) && (despues_la_borro >= {EBS+1{1'b1}});
  wire under_t1  = (evaluate_flags <  bias);

  assign overflow   = result_is_zero ? 1'b0 : (over_t1 | over_t2 | inv_op);
  assign underflow  = result_is_zero ? 1'b0 : under_t1;
  assign inexact    = result_is_zero ? 1'b0 : inexact_core;


endmodule
