module testbench;
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;
  
  // instantiate device to be tested
  top dut(
    .clk(clk), 
    .reset(reset), 
    .WriteData(WriteData), 
    .DataAdr(DataAdr), 
    .MemWrite(MemWrite)
  );

  // Dump file para waveforms - incluir TODAS las señales
  initial begin
    $dumpfile("pipeline_dump.vcd"); 
    $dumpvars;  // Incluye todas las señales de todos los módulos
  end

  // initialize test
  initial begin
    $display("==========================================");
    $display("Iniciando simulación del pipeline RISC-V");
    $display("==========================================");
    reset = 1; 
    # 22;
    reset = 0;
    $display("Reset completado en tiempo %0t", $time);
    $display("Iniciando ejecución del programa...\n");
  end

  // generate clock to sequence tests (periodo de 10ns)
  always begin
    clk = 1;
    # 5; 
    clk = 0; 
    # 5;
  end

  // Monitoreo de señales importantes
  reg [31:0] cycle_count = 0;
  reg [31:0] last_PC = 0;
  reg [31:0] stall_count = 0;
  
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Mostrar información cada 10 ciclos o en eventos importantes
      if (cycle_count % 10 == 0 || MemWrite) begin
        if (MemWrite) begin
          $display("Ciclo %0d: Escritura a memoria - Addr=0x%08h (%0d), Data=0x%08h (%0d)", 
                   cycle_count, DataAdr, DataAdr, WriteData, WriteData);
        end else begin
          $display("Ciclo %0d: Ejecutando...", cycle_count);
        end
      end
      
      // Detectar si el programa terminó (muchos ciclos sin actividad)
      if (cycle_count > 500) begin
        $display("\n==========================================");
        $display("Simulación completada después de %0d ciclos", cycle_count);
        $display("==========================================");
        $display("\nNota: Revisa el waveform para ver el PC, instrucciones y contenido de memoria");
        $stop;
      end
    end
  end

  // Timeout de seguridad
  initial begin
    # 100000;  // 10000 ciclos máximo (100us con periodo de 10ns)
    $display("\n==========================================");
    $display("TIMEOUT: Simulación excedió el tiempo máximo");
    $display("Ciclos ejecutados: %0d", cycle_count);
    $display("==========================================");
    $display("Revisa el waveform para ver el estado final");
    $stop;
  end

endmodule
