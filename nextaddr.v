module nextaddr(
    // Flip-flops
    input clk, reset,

    // Shapes
    input [31:0] num_i, num_j, num_k,

    // i, j, k de entrada
    input [31:0] curr_i, curr_j, curr_k,
    
    // i, j, k de salida
    output reg [31:0] next_i, next_j, next_k,

    output reg adv_next_i, adv_next_j,

    output reg not_first_iter
    
);

    always @(posedge clk or posedge reset) begin

        // Si acaba toda la multiplicación reseteo todo.
        if(reset) begin
            adv_next_i <= 1'b0;
            adv_next_j <= 1'b0;
            next_i <= 32'b0;
            next_j <= 32'b0;
            next_k <= 32'b0;
            not_first_iter <= 1'b1;
        end
        else if((curr_i+1 == num_i && curr_j+1 == num_j && curr_k+1 == num_k)) begin
                adv_next_i <= 1'bx;
                adv_next_j <= 1'bx;
                next_i <= 32'bx;
                next_j <= 32'bx;
                next_k <= 32'bx;
                not_first_iter <= 1'bx;
        end
        
        else begin

                // Una iteración antes de que acabe, setee las señales para que en la última 
                // iteración rescate los valores esperados.
                // Los mux's se encargaran de setear con 0, al siguiente o el actual.

                // Si acaba el 2do for avanza i
                if(curr_j+1 == num_j && curr_k+1 == num_k) begin
                    adv_next_i <= 1'b1;
                    adv_next_j <= 1'b0;
                end
                else begin

                    // Si no acaba el 2do for, no avanza i
                    adv_next_i <= 1'b0;

                    // Si acaba el 3er for, avanza j
                    if(curr_k+1 == num_k) adv_next_j <= 1'b1;
                    // Si no acaba avanza k  
                    else adv_next_j <= 1'b0;
                
                
                end

                // Seteo los siguientes i, j, k según los valores de los mux's
                next_i <= curr_i;
                next_j <= curr_j;
                next_k <= curr_k;
                
                not_first_iter <= 1'b0;
            end
            
        end


endmodule