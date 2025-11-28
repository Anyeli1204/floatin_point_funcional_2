// addr_a es [i][k] de la matriz A
// addr_b es [k][j] de la matriz B
// addr_s es la suma parcial en [i][j] de la matriz resultante C

// Calcula una iteración de los 3 for's
module vdatapath(
    
    // Register
    input clk, reset,

    // Direcciones de la posición actual de la matriz
    input [31:0] addrM1, addrM2, addrM3,

    // Señales
    input advance_i, advance_j,

    // first iter mux
    input first_iter,

    // Shape <- ( num_i x num_j ) prod (  num_j x num_k )
    input [31:0] num_i, num_j, num_k,

    // i, j, k <- deben ser unsigned value
    input [31:0] i, j, k,

    // Siguientes señales
    output adv_next_i, adv_next_j,

    // Siguientes i, j, k
    output [31:0] next_i, next_j, next_k,

    // ya no es first iter
    output not_first_iter

);

    // Segun las shape [i, j] [j, k] así debería ser los fors 
    // for(int i)
    //      for (int k)
    //          for (int j)

    // M1[i, k] = addrM1 + (i * num_j + k) * 4
    wire [31:0] addr_a = addrM1 + ((i * num_k + k) << 2);

    // M2[k, j] = addrM2 + (k * num_k + j) * 4
    wire [31:0] addr_b = addrM2 + ((k * num_j + j) << 2);

    // M3[i, j] = addrM3 + (i * num_k + j) * 4
    wire [31:0] addr_c = addrM3 + ((i * num_j + j) << 2);


    wire[31:0] rd1, rd2;
    wire[31:0] sum;
    wire[31:0] prod;


    // Rescato los valores de las matrices
    // y sumo el resultado parcial
    vmem vector_mem(

        // Inputs
        .clk(clk),
        .we(1'b1),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .addr_c(addr_c),
        .wd(prod),

        // Outputs
        .rv_a(rd1),
        .rv_b(rd2)

    );

    assign prod = rd1 * rd2;   // multiplicación unsigned

    wire[31:0] curr_i, curr_j, curr_k;
    vmux2 mux_i(
        .d0(i),
        .d1(i+1),
        .s(advance_i),
        .y(curr_i)
    );

    vmux3 mux_j(
        .d0(j),
        .d1(j+1),
        .d2(32'b0),
        .s({advance_i, advance_j}),
        .y(curr_j)
    );

    vmux4 mux_k(
        .d0(32'b0),
        .d1(k+1),
        .d2(32'b0),
        .s({advance_i, ~advance_j}),
        .is_first_iter(first_iter),
        .y(curr_k)
    );

    nextaddr ff(

        // flip flop
        .clk(clk),
        .reset(reset),

        // Shape Matriz
        .num_i(num_i),
        .num_j(num_j),
        .num_k(num_k),

        // current i, j, k
        .curr_i(curr_i),
        .curr_j(curr_j),
        .curr_k(curr_k),

        // next i, j, k
        .next_i(next_i),
        .next_j(next_j),
        .next_k(next_k),

        // next signals
        .adv_next_i(adv_next_i),
        .adv_next_j(adv_next_j),

        // first iter control
        .not_first_iter(not_first_iter)

    );

endmodule