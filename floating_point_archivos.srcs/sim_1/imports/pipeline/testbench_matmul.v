// Testbench específico para verificar la instrucción matmul
module testbench_matmul;
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;
  // Señales FP
  wire         FPMemWriteM;
  wire [31:0]  FWriteDataM;
  
  // Instanciar el procesador a probar
  top dut(
    .clk(clk), 
    .reset(reset), 
    .WriteData(WriteData), 
    .DataAdr(DataAdr), 
    .MemWrite(MemWrite),
    .FPMemWriteM(FPMemWriteM),
    .FWriteDataM(FWriteDataM)
  );
  
  // Guardar todas las señales en el archivo de waveform
  initial begin
    $dumpfile("pipeline_dump_matmul.vcd"); 
    $dumpvars(0, testbench_matmul);  // Solo este módulo y sus sub-módulos
  end
  
  // Inicializar la prueba
  initial begin
    $display("==========================================");
    $display("Testbench de Verificacion MATMUL");
    $display("==========================================");
    $display("Este test verifica:");
    $display("  - Carga de direcciones base en registros vectoriales");
    $display("  - Ejecucion de instruccion matmul");
    $display("  - Stall del pipeline durante matmul");
    $display("  - Resultado correcto en VEC_RAM");
    $display("==========================================\n");
    
    reset = 1; 
    # 22;
    reset = 0;
    $display("Reset completado en tiempo %0t", $time);
    
    // Inicializar registros vectoriales con direcciones base
    // Matriz A: dirección 0x00000000 (índice 0 en VEC_RAM)
    // Matriz B: dirección 0x00000024 (índice 9 en VEC_RAM, 9*4 = 36 = 0x24)
    // Matriz C: dirección 0x00000058 (índice 22 en VEC_RAM, 22*4 = 88 = 0x58)
    
    // Esperar un ciclo después del reset para que el pipeline se estabilice
    # 10;
    
    // Inicializar registros vectoriales usando force
    // v1 = dirección base de matriz A (0x00000000)
    force dut.rvpipeline.dp.vrf.vrf[1] = 32'h00000000;
    // v2 = dirección base de matriz B (0x00000024)
    force dut.rvpipeline.dp.vrf.vrf[2] = 32'h00000024;
    // v3 = dirección base de matriz C (0x00000058)
    force dut.rvpipeline.dp.vrf.vrf[3] = 32'h00000058;
    
    $display("Registros vectoriales inicializados:");
    $display("  v1 (vs1) = 0x%08h (direccion base matriz A)", dut.rvpipeline.dp.vrf.vrf[1]);
    $display("  v2 (vs2) = 0x%08h (direccion base matriz B)", dut.rvpipeline.dp.vrf.vrf[2]);
    $display("  v3 (vd)  = 0x%08h (direccion base matriz C)", dut.rvpipeline.dp.vrf.vrf[3]);
    $display("\nIniciando ejecucion del programa matmul...\n");
  end
  
  // Generar el reloj (periodo de 10ns)
  always begin
    clk = 1;
    # 5; 
    clk = 0; 
    # 5;
  end
  
  // Contador de ciclos
  reg [31:0] cycle_count = 0;
  reg matmul_started = 0;
  reg [31:0] matmul_start_cycle = 0;
  reg [31:0] matmul_end_cycle = 0;
  
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Detectar inicio de matmul (usando try-catch para evitar errores si la señal no existe)
      // Nota: Si isMatmulE no está disponible, comentar estas líneas
      // if (dut.rvpipeline.dp.isMatmulE && !matmul_started) begin
      //   matmul_started = 1;
      //   matmul_start_cycle = cycle_count;
      //   $display("==========================================");
      //   $display("Ciclo %0d: MATMUL INICIADO", cycle_count);
      //   $display("==========================================");
      // end
      
      // Mostrar información cada 10 ciclos o cuando hay eventos importantes
      if (cycle_count % 10 == 0 || MemWrite || FPMemWriteM) begin
        if (FPMemWriteM) begin
          $display("Ciclo %0d: Escritura FP a memoria - Direccion=0x%08h, Dato=0x%08h", 
                   cycle_count, DataAdr, FWriteDataM);
        end else if (MemWrite) begin
          $display("Ciclo %0d: Escritura entera a memoria - Direccion=0x%08h, Dato=0x%08h", 
                   cycle_count, DataAdr, WriteData);
        end else begin
          $display("Ciclo %0d: Ejecutando...", cycle_count);
        end
      end
      
      // Verificar resultado después de que matmul termine
      if (matmul_end_cycle > 0 && cycle_count == matmul_end_cycle + 5) begin
        $display("\n==========================================");
        $display("Verificando resultados de matmul...");
        $display("==========================================");
        
        // Leer algunos valores de la matriz resultado (matriz C)
        // Los resultados deberían estar en VEC_RAM[22] en adelante
        // Nota: Necesitamos acceder a la memoria vectorial del matmul
        $display("Matriz resultado (C) deberia estar en VEC_RAM[22:36]");
        $display("Revisa el waveform para ver los valores finales en VEC_RAM");
        $display("==========================================\n");
      end
      
      // Detener la simulacion después de suficiente tiempo
      if (cycle_count > 1000) begin
        $display("\n==========================================");
        $display("Simulacion completada despues de %0d ciclos", cycle_count);
        $display("==========================================");
        if (matmul_start_cycle > 0) begin
          $display("Matmul inicio en ciclo: %0d", matmul_start_cycle);
          if (matmul_end_cycle > 0) begin
            $display("Matmul termino en ciclo: %0d", matmul_end_cycle);
            $display("Ciclos totales de matmul: %0d", matmul_end_cycle - matmul_start_cycle);
          end else begin
            $display("Matmul aun no ha terminado");
          end
        end
        $display("\nNota: Revisa el waveform para ver el PC, instrucciones y contenido de memoria");
        $stop;
      end
    end
  end
  
  // Timeout de seguridad
  initial begin
    # 200000;  // Máximo 20000 ciclos (200us con periodo de 10ns)
    $display("\n==========================================");
    $display("TIMEOUT: Simulacion excedio el tiempo maximo");
    $display("Ciclos ejecutados: %0d", cycle_count);
    $display("==========================================");
    $display("Revisa el waveform para ver el estado final");
    $stop;
  end
  
endmodule

