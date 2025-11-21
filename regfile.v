module regfile(input  clk, 
               input  we3, 
               input  [ 4:0] a1, a2, a3, 
               input  [31:0] wd3, 
               output [31:0] rd1, rd2); 

  reg [31:0] rf[31:0]; 
  integer i;

  // Inicializamos todos los registros con 0
  initial begin
    for (i = 0; i < 32; i = i + 1)
      rf[i] = 0;
  end

  // write third port on rising edge of clock (A3/WD3/WE3)
  always @(posedge clk) begin 
    if (we3) rf[a3] <= wd3; 
  end
  
  // read two ports combinationally (A1/RD1, A2/RD2)
  // register 0 hardwired to 0
  // Internal bypassing: si se lee el registro que se está escribiendo, devolver wd3
  assign rd1 = (a1 != 0) ? ((we3 && (a1 == a3)) ? wd3 : rf[a1]) : 0; 
  assign rd2 = (a2 != 0) ? ((we3 && (a2 == a3)) ? wd3 : rf[a2]) : 0; 
endmodule