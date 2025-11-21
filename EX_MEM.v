module EX_MEM(
    input clk,
    input reset,
    
    input RegWriteE,
    input MemWriteE,
    input [1:0] ResultSrcE,
    
    input [31:0] ALUResultE,
    input [31:0] WriteDataE,
    input [31:0] PCPlus4E,
    input [4:0] RdE,
    input [31:0] InstruE,
    
    output reg RegWriteM,
    output reg MemWriteM,
    output reg [1:0] ResultSrcM,
    
    output reg [31:0] ALUResultM,
    output reg [31:0] WriteDataM,
    output reg [31:0] PCPlus4M,
    output reg [4:0] RdM,
    output reg [31:0] InstruM
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        RegWriteM   <= 0;
        MemWriteM   <= 0;
        ResultSrcM  <= 2'b00;
        ALUResultM  <= 32'b0;
        WriteDataM  <= 32'b0;
        PCPlus4M    <= 32'b0;
        RdM         <= 5'b0;
    end else begin
        RegWriteM   <= RegWriteE;
        MemWriteM   <= MemWriteE;
        ResultSrcM  <= ResultSrcE;
        ALUResultM  <= ALUResultE;
        WriteDataM  <= WriteDataE;
        PCPlus4M    <= PCPlus4E;
        RdM         <= RdE;
        InstruM     <= InstruE;
    end
end

endmodule