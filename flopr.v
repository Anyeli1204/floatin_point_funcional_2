module flopr (input  clk, reset,
               input  [WIDTH-1:0] d,
               input StallF, 
               output [WIDTH-1:0] q);

  parameter WIDTH = 8;

  reg [WIDTH-1:0] q; 

  always @(posedge clk or posedge reset) begin 
    if (reset) q <= 0; 
    else if(!StallF)  q <= d; 
  end
endmodule