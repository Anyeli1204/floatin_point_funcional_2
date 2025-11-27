# Guía de Pruebas para el Manejo de Latencias FP

## Objetivo
Verificar que el pipeline maneja correctamente las diferentes latencias de las operaciones de punto flotante:
- **FADD.S / FSUB.S**: 1 ciclo (sin stall adicional)
- **FMUL.S**: 4 ciclos (3 ciclos de stall adicional)
- **FDIV.S**: 12 ciclos (11 ciclos de stall adicional)

## Métodos de Prueba

### Método 1: Simulación con Waveform (Recomendado)

#### Paso 1: Configurar el archivo de instrucciones
1. Abre `imem.v` y cambia la línea que carga el archivo:
   ```verilog
   $readmemh("test_latency.txt", RAM);
   ```

#### Paso 2: Ejecutar la simulación
1. En Vivado/Xilinx:
   - Abre el proyecto
   - Ve a **Simulation** → **Run Simulation** → **Behavioral Simulation**
   - Selecciona `testbench_latency` como top module
   - Ejecuta la simulación

2. O desde la línea de comandos:
   ```bash
   xvlog testbench_latency.v top.v riscvpipeline.v datapath.v hazard_unit.v ...
   xelab testbench_latency
   xsim testbench_latency
   ```

#### Paso 3: Analizar el Waveform
Abre el archivo `pipeline_dump_latency.vcd` y busca estas señales:

**Señales clave a monitorear:**
```
dut.rvpipeline.dp.hu.latencyCounter    # Contador de latencia (debe decrementar)
dut.rvpipeline.dp.hu.fpLatencyStall    # Stall activo por latencia FP
dut.rvpipeline.dp.hu.totalStall         # Stall total (incluye latencia)
dut.rvpipeline.dp.isFPE                 # 1 si hay operación FP en EX
dut.rvpipeline.dp.FPLatencyE           # Latencia de la operación actual
dut.rvpipeline.dp.PCF                   # Program Counter (para ver qué instrucción se ejecuta)
```

**Qué verificar:**
1. **FADD.S** (ciclo ~3):
   - `isFPE = 1`
   - `FPLatencyE = 1`
   - `latencyCounter = 0` (no hay stall adicional)
   - `fpLatencyStall = 0`

2. **FMUL.S** (ciclo ~4):
   - `isFPE = 1`
   - `FPLatencyE = 4`
   - `latencyCounter` se inicializa en 3
   - `fpLatencyStall = 1` durante 3 ciclos
   - `latencyCounter` decrementa: 3 → 2 → 1 → 0

3. **FDIV.S** (ciclo ~8):
   - `isFPE = 1`
   - `FPLatencyE = 12`
   - `latencyCounter` se inicializa en 11
   - `fpLatencyStall = 1` durante 11 ciclos
   - `latencyCounter` decrementa: 11 → 10 → ... → 1 → 0

### Método 2: Análisis de Ciclos en Consola

El testbench imprime información en la consola. Observa:
- Los ciclos en que se ejecutan las operaciones FP
- Los stalls que ocurren
- Las escrituras a memoria

### Método 3: Verificación Manual

1. **Conteo de ciclos entre instrucciones:**
   - FADD.S debería completarse en 1 ciclo
   - FMUL.S debería tomar 4 ciclos totales (1 en EX + 3 stalls)
   - FDIV.S debería tomar 12 ciclos totales (1 en EX + 11 stalls)

2. **Verificar que el PC no avanza durante stalls:**
   - Cuando `StallF = 1`, el PC debe mantenerse constante
   - Cuando `StallD = 1`, la instrucción en ID debe repetirse

## Señales Importantes en el Waveform

### En hazard_unit:
- `latencyCounter`: Contador que se inicializa con (latencia - 1)
- `fpLatencyStall`: Stall activo cuando `latencyCounter > 0`
- `totalStall`: Stall total (incluye load-use y latencia FP)

### En datapath:
- `isFPE`: Indica operación FP en EX
- `FPLatencyE`: Latencia de la operación actual
- `StallF`, `StallD`: Señales de stall del pipeline

## Resultados Esperados

### Timeline aproximado (asumiendo pipeline de 5 etapas):

```
Ciclo 1:  flw f1  (IF)
Ciclo 2:  flw f1  (ID), flw f2 (IF)
Ciclo 3:  flw f1  (EX), flw f2 (ID), fadd.s (IF)
Ciclo 4:  flw f1  (MEM), flw f2 (EX), fadd.s (ID), fmul.s (IF)
Ciclo 5:  flw f1  (WB), flw f2 (MEM), fadd.s (EX), fmul.s (ID)
Ciclo 6:  flw f2  (WB), fadd.s (MEM), fmul.s (EX) ← Stall inicia aquí
Ciclo 7:  fadd.s  (WB), fmul.s (EX) ← Stall (latencyCounter = 2)
Ciclo 8:  fmul.s  (EX) ← Stall (latencyCounter = 1)
Ciclo 9:  fmul.s  (EX) ← Stall (latencyCounter = 0)
Ciclo 10: fmul.s  (MEM), fdiv.s (EX) ← Stall inicia aquí
...
```

## Troubleshooting

### Si no ves stalls:
1. Verifica que `FPLatencyE` tiene el valor correcto (1, 4, o 12)
2. Verifica que `isFPE = 1` durante las operaciones FP
3. Verifica que `latencyCounter` se inicializa correctamente

### Si los stalls son incorrectos:
1. Revisa la lógica en `hazard_unit.v` líneas 107-138
2. Verifica que el contador se decrementa correctamente
3. Asegúrate de que `FlushE` no está reseteando el contador incorrectamente

### Si la simulación no inicia:
1. Verifica que `test_latency.txt` existe en el directorio correcto
2. Verifica que `imem.v` está cargando el archivo correcto
3. Revisa los errores de compilación en la consola

## Notas Adicionales

- El contador de latencia se inicializa con `(latencia - 1)` porque el primer ciclo ya está en EX
- Los stalls afectan a las etapas Fetch y Decode, pero no a Execute (que mantiene la operación FP)
- El forwarding sigue funcionando normalmente durante los stalls


