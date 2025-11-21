module adder(input  [31:0] a, b,
             input StallF,
             output [31:0] y);
  
  assign y = a + b; 
endmodule