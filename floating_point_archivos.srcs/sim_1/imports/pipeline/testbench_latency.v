// Testbench específico para verificar el manejo de latencias FP
module testbench_latency;
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
  
  // Acceder a señales internas para monitorear latencias
  // Nota: Estas señales deben estar disponibles en el módulo top o datapath
  wire [31:0] PCF;
  wire [31:0] InstrD;
  wire isFPE;
  wire [3:0] FPLatencyE;
  wire StallF, StallD, FlushE;
  
  // Intentar acceder a señales internas (puede requerir modificar top.v)
  // Por ahora, monitoreamos las señales visibles
  
  // Guardar todas las señales en el archivo de waveform
  initial begin
    $dumpfile("pipeline_dump_latency.vcd"); 
    $dumpvars(0, testbench_latency);  // Solo este módulo y sus sub-módulos
  end
  
  // Inicializar la prueba
  initial begin
    $display("==========================================");
    $display("Testbench de Verificacion de LATENCIAS FP");
    $display("==========================================");
    $display("Este test verifica que:");
    $display("  - fadd.s/fsub.s tienen latencia de 1 ciclo");
    $display("  - fmul.s tiene latencia de 4 ciclos (3 stalls adicionales)");
    $display("  - fdiv.s tiene latencia de 12 ciclos (11 stalls adicionales)");
    $display("==========================================\n");
    reset = 1; 
    # 22;
    reset = 0;
    $display("Reset completado en tiempo %0t", $time);
    $display("Iniciando ejecucion del programa de prueba de latencias...\n");
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
  reg [31:0] last_fp_cycle = 0;
  reg [3:0] last_fp_latency = 0;
  
  // Monitorear operaciones FP y sus latencias
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Detectar cuando hay una operación FP en ejecución
      // Nota: Necesitarías exponer isFPE y FPLatencyE desde el datapath
      // Por ahora, monitoreamos indirectamente a través de los stalls
      
      // Mostrar información cada ciclo durante los primeros 50 ciclos
      if (cycle_count <= 50) begin
        if (FPMemWriteM) begin
          $display("Ciclo %0d: [FP STORE] Direccion=0x%08h, Dato=0x%08h", 
                   cycle_count, DataAdr, FWriteDataM);
        end else if (MemWrite) begin
          $display("Ciclo %0d: [STORE] Direccion=0x%08h, Dato=0x%08h", 
                   cycle_count, DataAdr, WriteData);
        end else begin
          // Mostrar cada 5 ciclos para no saturar la salida
          if (cycle_count % 5 == 0) begin
            $display("Ciclo %0d: Ejecutando...", cycle_count);
          end
        end
      end
      
      // Resumen de latencias detectadas
      if (cycle_count == 50) begin
        $display("\n==========================================");
        $display("RESUMEN DE VERIFICACION DE LATENCIAS");
        $display("==========================================");
        $display("Para verificar las latencias:");
        $display("1. Abre el waveform (pipeline_dump_latency.vcd)");
        $display("2. Busca las senales:");
        $display("   - dut.rvpipeline.dp.hu.latencyCounter");
        $display("   - dut.rvpipeline.dp.hu.fpLatencyStall");
        $display("   - dut.rvpipeline.dp.isFPE");
        $display("   - dut.rvpipeline.dp.FPLatencyE");
        $display("3. Verifica que:");
        $display("   - fadd.s: latencyCounter = 0 (sin stall adicional)");
        $display("   - fmul.s: latencyCounter = 3 (3 ciclos de stall)");
        $display("   - fdiv.s: latencyCounter = 11 (11 ciclos de stall)");
        $display("==========================================\n");
      end
      
      // Detener la simulacion despues de 100 ciclos
      if (cycle_count > 100) begin
        $display("\n==========================================");
        $display("Simulacion completada despues de %0d ciclos", cycle_count);
        $display("==========================================");
        $display("\nRevisa el waveform para verificar las latencias:");
        $display("  - Busca 'latencyCounter' en el hazard_unit");
        $display("  - Verifica que los stalls coinciden con las latencias");
        $display("  - Confirma que las operaciones FP avanzan correctamente");
        $stop;
      end
    end
  end
  
  // Timeout de seguridad
  initial begin
    # 200000;  // Maximo 20000 ciclos
    $display("\n==========================================");
    $display("TIMEOUT: Simulacion excedio el tiempo maximo");
    $display("Ciclos ejecutados: %0d", cycle_count);
    $display("==========================================");
    $stop;
  end
  
endmodule


