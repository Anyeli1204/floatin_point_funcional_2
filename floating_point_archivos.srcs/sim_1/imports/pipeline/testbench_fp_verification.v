// Testbench mejorado para verificar operaciones FP
module testbench_fp_verification;
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
    $dumpfile("pipeline_dump_fp.vcd"); 
    $dumpvars(0, testbench_fp_verification);  // Solo este módulo y sus sub-módulos
  end
  
  // Inicializar la prueba
  initial begin
    $display("==========================================");
    $display("Testbench de Verificación FP");
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
  
  // Valores esperados para verificación
  reg [31:0] expected_fsw_address = 32'h00000008;  // 8 bytes = RAM[2]
  reg [31:0] expected_fsw_data = 32'h40400000;     // 3.0 en IEEE 754
  reg fsw_detected = 0;
  reg fsw_verified = 0;
  
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      // Detectar fsw f3, 8(x0) cuando está en MEM
      if (FPMemWriteM && DataAdr == expected_fsw_address) begin
        fsw_detected = 1;
        $display("\n==========================================");
        $display("Ciclo %0d: fsw DETECTADO", cycle_count);
        $display("==========================================");
        $display("Direccion: 0x%08h (%0d bytes) = RAM[%0d]", DataAdr, DataAdr, DataAdr/4);
        $display("Dato FP:   0x%08h", FWriteDataM);
        
        // Verificar el dato
        if (FWriteDataM == expected_fsw_data) begin
          $display("? VERIFICACION EXITOSA: Dato correcto (3.0)");
          fsw_verified = 1;
        end else begin
          $display("? ERROR: Dato incorrecto");
          $display("   Esperado: 0x%08h (3.0)", expected_fsw_data);
          $display("   Obtenido: 0x%08h", FWriteDataM);
        end
        
        // Verificar la dirección
        if (DataAdr == expected_fsw_address) begin
          $display("? VERIFICACION EXITOSA: Direccion correcta (8 bytes = RAM[2])");
        end else begin
          $display("? ERROR: Direccion incorrecta");
          $display("   Esperado: 0x%08h (8 bytes)", expected_fsw_address);
          $display("   Obtenido: 0x%08h", DataAdr);
        end
        $display("==========================================\n");
      end
      
      // Mostrar información cada 10 ciclos o cuando hay escritura a memoria
      if (cycle_count % 10 == 0 || MemWrite || FPMemWriteM) begin
        if (FPMemWriteM) begin
          $display("Ciclo %0d: Escritura FP - Dir=0x%08h (%0d), Dato=0x%08h", 
                   cycle_count, DataAdr, DataAdr, FWriteDataM);
        end else if (MemWrite) begin
          $display("Ciclo %0d: Escritura entera - Dir=0x%08h (%0d), Dato=0x%08h (%0d)", 
                   cycle_count, DataAdr, DataAdr, WriteData, WriteData);
        end else begin
          $display("Ciclo %0d: Ejecutando...", cycle_count);
        end
      end
      
      // Resumen final después de suficientes ciclos
      if (cycle_count == 50) begin
        $display("\n==========================================");
        $display("RESUMEN DE VERIFICACION");
        $display("==========================================");
        if (fsw_detected) begin
          if (fsw_verified) begin
            $display("? fsw f3, 8(x0) EJECUTADO CORRECTAMENTE");
            $display("   - Direccion: 0x%08h (RAM[2])", expected_fsw_address);
            $display("   - Dato: 0x%08h (3.0)", expected_fsw_data);
          end else begin
            $display("??  fsw detectado pero con datos incorrectos");
          end
        end else begin
          $display("? fsw NO detectado en los primeros 50 ciclos");
          $display("   Revisa el waveform para verificar");
        end
        $display("==========================================\n");
      end
      
      // Detener la simulación después de 100 ciclos
      if (cycle_count > 100) begin
        $display("\n==========================================");
        $display("Simulacion completada despues de %0d ciclos", cycle_count);
        $display("==========================================");
        $display("\nNota: Revisa el waveform para ver el PC, instrucciones y contenido de memoria");
        $stop;
      end
    end
  end
  
  // Timeout de seguridad
  initial begin
    # 200000;  // Maximo 20000 ciclos (200us con periodo de 10ns)
    $display("\n==========================================");
    $display("TIMEOUT: Simulacion excedio el tiempo maximo");
    $display("Ciclos ejecutados: %0d", cycle_count);
    $display("==========================================");
    $display("Revisa el waveform para ver el estado final");
    $stop;
  end
  
endmodule
