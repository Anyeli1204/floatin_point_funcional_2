// -----------------------------------------------------------------------------
// is_overflow
// Propósito: Detectar si Exp + AddExp excede el rango del exponente (EBS+1 bits).
// Notas: NewExp se calcula con EBS+2 bits (EBS+1:0) para capturar el posible acarreo.
//        OverFlow = 1 si NewExp alcanza/supera todo-1 en (EBS+1) bits.
// -----------------------------------------------------------------------------
module is_overflow #(parameter MBS=9, parameter EBS=4, parameter BS=15) 
(Exp, AddExp, OverFlow);
  input [EBS:0] Exp;
  input [EBS:0] AddExp;
  output OverFlow;

  wire [EBS+1:0] NewExp = Exp + AddExp;
  
  assign OverFlow = (NewExp >= {EBS+1{1'b1}});
  
endmodule

// -----------------------------------------------------------------------------
// is_underflow
// Propósito: Detectar si al restar SubExp de Exp el resultado sería negativo.
// Criterio: UnderFlow = 1 cuando SubExp > Exp.
// -----------------------------------------------------------------------------
module is_underflow #(parameter MBS=9, parameter EBS=4, parameter BS=15) 
(Exp, SubExp, UnderFlow);
  input [EBS:0] Exp;
  input [EBS:0] SubExp;
  output UnderFlow;
  
  assign UnderFlow = ( SubExp > Exp );
  
endmodule

// -----------------------------------------------------------------------------
// is_inexact
// Propósito: Señal auxiliar de inexactitud basada en LSB de mantisa y acarreo.
// Criterio: inexact = Man[0] & CarryOut (aproximación simple).
// Nota: El diseño global también usa guard/sticky y bits perdidos al normalizar.
// -----------------------------------------------------------------------------
module is_inexact #(parameter MBS=9, parameter EBS=4, parameter BS=15) 
(Man, CarryOut, inexact);
  input CarryOut;
  input [MBS:0] Man;
  output inexact;
  
  assign inexact = (Man[0] && CarryOut);
  
endmodule

// -----------------------------------------------------------------------------
// is_invalid_op
// Propósito: Marcar presencia de operandos no finitos/NaN.
// Detecta:
//   - is_inf_ValX      : exp=all1 y mantisa=0 (±Inf)
//   - is_invalid_ValX  : exp=all1 y mantisa!=0 (NaN)
// Criterio de salida (según este diseño): InvalidOp = 1 si cualquiera es Inf o NaN.
// -----------------------------------------------------------------------------
module is_invalid_op #(parameter MBS=9, parameter EBS=4, parameter BS=15) 
(Exp1, Exp2, Man1, Man2, InvalidOp);

  input [EBS:0] Exp1, Exp2;
  input [MBS:0] Man1, Man2;
  output InvalidOp;
  
  wire is_inf_Val1 = (&Exp1 && ~|Man1);
  wire is_inf_Val2 = (&Exp2 && ~|Man2);
  
  wire is_invalid_Val1 = (&Exp1 && |Man1);
  wire is_invalid_Val2 = (&Exp2 && |Man2);
  
  assign InvalidOp = (is_inf_Val1 | is_inf_Val2 | is_invalid_Val1 | is_invalid_Val2);

endmodule

// -----------------------------------------------------------------------------
// is_invalid_val
// Propósito: Detector de NaN para un único operando IEEE-754.
// value = {sign[BS], exp[BS-1:MBS+1], man[MBS:0]}; InvalidVal=1 si exp=all1 y man!=0.
// -----------------------------------------------------------------------------
module is_invalid_val #(
  parameter MBS = 9, 
  parameter EBS = 4,  
  parameter BS  = 15  
)(
  input  [BS:0] value,       
  output        InvalidVal
);

  wire              sign = value[BS];
  wire [EBS:0]      Exp  = value[BS-1:MBS+1];
  wire [MBS:0]      Man  = value[MBS:0];

  assign InvalidVal = (&Exp && |Man);

endmodule

// -----------------------------------------------------------------------------
// is_inf_detector
// Propósito: Detectar +Inf / -Inf en un operando IEEE-754.
// Criterio: exp=all1 y mantisa=0; el signo decide +Inf (sign=0) o -Inf (sign=1).
// -----------------------------------------------------------------------------
module is_inf_detector #(
    parameter MBS = 9,   
    parameter EBS = 4,   
    parameter BS  = 15   
)(
    input  [BS:0]  value,     
    output         is_posInf, 
    output         is_negInf
);

  wire sign = value[BS];
  wire [EBS:0] Exp = value[BS-1 : BS-EBS-1];
  wire [MBS:0] Man = value[MBS:0];

  assign is_posInf = (~sign) & (&Exp) & (~|Man); 
  assign is_negInf = ( sign) & (&Exp) & (~|Man); 

endmodule

// -----------------------------------------------------------------------------
// both_are_inf
// Propósito: Señalar si ambos operandos son infinitos (sin importar el signo).
// Implementación: reutiliza dos is_inf_detector y combina sus salidas.
// -----------------------------------------------------------------------------
module both_are_inf #(
    parameter MBS = 9,   
    parameter EBS = 4,   
    parameter BS  = 15   
) (input [BS:0] v1, input[BS:0] v2,
  output is_both_inf);

  wire i1_1, i1_2, i2_1, i2_2;
  is_inf_detector #(.MBS(MBS), .EBS(EBS), .BS(BS)) inf1(v1, i1_1, i1_2);
  is_inf_detector #(.MBS(MBS), .EBS(EBS), .BS(BS)) inf2(v2, i2_1, i2_2);

  assign is_both_inf = (i1_1 || i1_2) && (i2_1 || i2_2);

endmodule


