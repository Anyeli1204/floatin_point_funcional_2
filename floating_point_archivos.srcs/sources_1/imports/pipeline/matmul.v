module matmul(
    input clk, reset,
    input [31:0] addr_a, addr_b, addr_c,
    input is_matmul_op
);

    wire [31:0] rd_A_rows, rd_B_rows;
    wire [31:0] rd_A_cols, rd_B_cols;

    // Señal interna para lógica combinacional
    wire advance;  // wire conectado al datapath
    wire act_advance = advance;

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

    // Segundo módulo para columnas
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

    // Variables de control
    reg [31:0] i, j, k;
    reg first_iter;
    reg was_matmul;

    wire [31:0] next_i, next_j, next_k;
    wire adv_i, adv_j;
    wire not_first_iter;

    // Bases de datos
    wire [31:0] baseA = addr_a + 8;
    wire [31:0] baseB = addr_b + 8;
    wire [31:0] baseC = addr_c + 8;

    // Dimensiones
    wire [31:0] A_rows = rd_A_rows;
    wire [31:0] A_cols = rd_A_cols;
    wire [31:0] B_rows = rd_B_rows;
    wire [31:0] B_cols = rd_B_cols;

    wire is_valid_matmul = (A_cols == B_rows);

    // Instancia datapath
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
        .not_first_iter(not_first_iter),
        .act_advance(act_advance),
        .advance(advance)  // conectar el wire
    );

    // --- Lógica combinacional de control ---
    always @(*) begin
        if (reset) begin
            i = 0;
            j = 0;
            k = 0;
            first_iter = 1;
            was_matmul = 0;
            //advance = 0;
        end
        // Inicio de matmul
        else if (is_matmul_op && !was_matmul && is_valid_matmul) begin
            i = 0;
            j = 0;
            k = 0;
            first_iter = 1;
            was_matmul = 1;
            //advance_internal = 1;
        end
        // Matmul en progreso
        else if (is_matmul_op && is_valid_matmul) begin
            if (advance) begin
                i = next_i;
                j = next_j;
                k = next_k;
                first_iter = not_first_iter;
                //advance_internal = 0; // se consume el avance
            end
            else begin
                i = i;
                j = j;
                k = k;
                first_iter = first_iter;
            end
        end
        // No es matmul
        else begin
            was_matmul = 0;
            //advance = 0;
        end
    end

endmodule
