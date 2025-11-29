module matmul(
    input clk, reset,
    input [31:0] addr_a, addr_b, addr_c
);

    wire [31:0] rd_A_rows, rd_B_rows;
    wire [31:0] rd_A_cols, rd_B_cols;
    reg first_iter;
    
    initial begin
        first_iter = 1'b1;  // Inicializamos first_iter a 1 (es primera iteración)
    end

    // Primer módulo solo para filas
    vmem MEM_rows (
        .clk(clk),
        .we(1'b0),
        .addr_a(addr_a),       
        .addr_b(addr_b),       
        .addr_c(addr_c),
        .wd(32'd0),
        .rv_a(rd_A_rows),
        .rv_b(rd_B_rows)
    );

    // Segundo módulo para columnas, avanzando +1
    vmem MEM_cols (
        .clk(clk),
        .we(1'b0),
        .addr_a(addr_a + 4),
        .addr_b(addr_b + 4),
        .addr_c(addr_c),
        .wd(32'd0),
        .rv_a(rd_A_cols),
        .rv_b(rd_B_cols)
    );

    reg [31:0] i, j, k;
    wire [31:0] next_i, next_j, next_k;
    wire adv_i, adv_j;
    wire not_first_iter;

    // Bases de los datos, saltando filas/columnas
    wire [31:0] baseA = addr_a + 8;
    wire [31:0] baseB = addr_b + 8;
    wire [31:0] baseC = addr_c + 8;

    // Rescata las dimensiones de A y B
    wire [31:0] A_rows = rd_A_rows;
    wire [31:0] A_cols = rd_A_cols;
    wire [31:0] B_rows = rd_B_rows;
    wire [31:0] B_cols = rd_B_cols;

    vdatapath DP (
        .clk(clk),
        .reset(reset),

        .addrM1(baseA),
        .addrM2(baseB),
        .addrM3(baseC),
        .first_iter(first_iter),

        .advance_i(adv_i),
        .advance_j(adv_j),

        .num_i(A_rows),
        .num_j(B_cols),
        .num_k(A_cols),

        .i(i),
        .j(j),
        .k(k),
        
        .adv_next_i(adv_i),
        .adv_next_j(adv_j),

        .next_i(next_i),
        .next_j(next_j),
        .next_k(next_k),

        .not_first_iter(not_first_iter)

    );


    always @(*) begin
        i <= next_i;
        j <= next_j;
        k <= next_k;
        first_iter <= not_first_iter;
    end

endmodule
