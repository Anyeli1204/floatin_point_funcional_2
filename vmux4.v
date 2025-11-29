module vmux4(
    input [31:0] d0, d1, d2,
    input [1:0] s,
    input is_first_iter,
    output [31:0] y
);

    assign y = is_first_iter ? 32'b0 : 
    (s[1] ? d2 : (s[0] ? d1 : d0));


endmodule
