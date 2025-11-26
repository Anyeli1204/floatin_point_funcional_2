module EX_MEM(
    input clk,
    input reset,
    
    input RegWriteE,
    input MemWriteE,
    input [1:0] ResultSrcE,
    // Señales FP
    input FPRegWriteE,
    input FPMemWriteE,
    
    input [31:0] ALUResultE,
    input [31:0] WriteDataE,
    // Señales FP separadas
    input [31:0] FALUResultE,
    input [31:0] FWriteDataE,
    input [31:0] PCPlus4E,
    input [4:0] RdE,
    
    output reg RegWriteM,
    output reg MemWriteM,
    output reg [1:0] ResultSrcM,
    // Salidas FP
    output reg FPRegWriteM,
    output reg FPMemWriteM,
    
    output reg [31:0] ALUResultM,
    output reg [31:0] WriteDataM,
    // Salidas FP separadas
    output reg [31:0] FALUResultM,
    output reg [31:0] FWriteDataM,
    output reg [31:0] PCPlus4M,
    output reg [4:0] RdM
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        RegWriteM   <= 0;
        MemWriteM   <= 0;
        ResultSrcM  <= 2'b00;
        FPRegWriteM <= 0;
        FPMemWriteM <= 0;
        ALUResultM  <= 32'b0;
        WriteDataM  <= 32'b0;
        FALUResultM <= 32'b0;
        FWriteDataM <= 32'b0;
        PCPlus4M    <= 32'b0;
        RdM         <= 5'b0;
    end else begin
        RegWriteM   <= RegWriteE;
        MemWriteM   <= MemWriteE;
        ResultSrcM  <= ResultSrcE;
        FPRegWriteM <= FPRegWriteE;
        FPMemWriteM <= FPMemWriteE;
        ALUResultM  <= ALUResultE;
        WriteDataM  <= WriteDataE;
        FALUResultM <= FALUResultE;
        FWriteDataM <= FWriteDataE;
        PCPlus4M    <= PCPlus4E;
        RdM         <= RdE;
    end
end

endmodule