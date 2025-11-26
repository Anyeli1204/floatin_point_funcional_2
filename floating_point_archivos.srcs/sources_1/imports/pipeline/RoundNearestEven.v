`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.10.2025 19:36:16
// Design Name: 
// Module Name: RoundNearestEven
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module RoundNearestEven #(parameter MBS=9, parameter EBS=4, parameter BS=15, parameter FSIZE=14) 
  (ms, exp, ms_round, exp_round);
  input  [FSIZE:0] ms;
  input  [EBS:0]  exp;
  output [MBS:0]  ms_round;
  output [EBS:0]  exp_round;

  wire guard   = ms[4];

  wire boolean = |ms[3:0];

  // LSB de la mantisa
  wire is_even = ~ms[5];

  // Vamos de FSIZE:5, quitando la parte que no se puede representar.
  wire [MBS+1:0] temp = ms[FSIZE:5] + ((guard && (boolean || !is_even)) ? 1 : 0);

  assign ms_round  = temp[MBS:0];
  assign exp_round = exp + temp[MBS+1];

endmodule


