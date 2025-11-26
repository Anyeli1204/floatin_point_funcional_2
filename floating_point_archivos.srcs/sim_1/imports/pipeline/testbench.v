module testbench;
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
    $dumpfile("pipeline_dump.vcd"); 
    $dumpvars;  // Incluye todas las señales de todos los módulos
  end

  // Inicializar la prueba
  initial begin
    $display("==========================================");
    $display("Iniciando simulacion del pipeline RISC-V");
    $display("==========================================");
    reset = 1; 
    # 22;
    reset = 0;
    $display("Reset completado en tiempo %0t", $time);
    $display("Iniciando ejecucion del programa...\n");
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
  
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar informacion cada 10 ciclos o cuando hay escritura a memoria
      if (cycle_count % 10 == 0 || MemWrite || FPMemWriteM) begin
        if (FPMemWriteM) begin
          $display("Ciclo %0d: Escritura FP a memoria - Direccion=0x%08h (%0d), Dato FP=0x%08h", 
                   cycle_count, DataAdr, DataAdr, FWriteDataM);
        end else if (MemWrite) begin
          $display("Ciclo %0d: Escritura entera a memoria - Direccion=0x%08h (%0d), Dato=0x%08h (%0d)", 
                   cycle_count, DataAdr, DataAdr, WriteData, WriteData);
        end else begin
          $display("Ciclo %0d: Ejecutando...", cycle_count);
        end
      end
      
      // Detener la simulacion despues de 500 ciclos
      if (cycle_count > 500) begin
        $display("\n==========================================");
        $display("Simulacion completada despues de %0d ciclos", cycle_count);
        $display("==========================================");
        $display("\nNota: Revisa el waveform para ver el PC, instrucciones y contenido de memoria");
        $stop;
      end
    end
  end

  // Timeout de seguridad (detener si la simulacion tarda mucho)
  initial begin
    # 100000;  // Maximo 10000 ciclos (100us con periodo de 10ns)
    $display("\n==========================================");
    $display("TIMEOUT: Simulacion excedio el tiempo maximo");
    $display("Ciclos ejecutados: %0d", cycle_count);
    $display("==========================================");
    $display("Revisa el waveform para ver el estado final");
    $stop;
  end

endmodule
