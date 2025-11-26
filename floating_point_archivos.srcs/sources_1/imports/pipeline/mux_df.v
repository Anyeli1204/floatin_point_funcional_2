module mux_df(
    input  [1:0]  forward,
    input  [31:0] data_in,
    input  [31:0] AluResultM,
    input  [31:0] ResultW,
    output reg [31:0] data_out
);

    always @(*) begin

        // $display("forward: %b", forward);
        case (forward)
            2'b00: data_out = data_in;
            2'b10: data_out = AluResultM;
            2'b01: data_out = ResultW;
            default: 
                begin 
                    $display("Error in mux_df: invalid forward signal");
                    data_out = 2'bxx;
                end
        endcase
    end

endmodule
