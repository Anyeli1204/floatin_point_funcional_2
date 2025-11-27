# Diferencia entre Stall Normal (Load-Use) y Stall por Latencia FP

## 📊 Tabla Comparativa

| Característica | **Stall Normal (Load-Use)** | **Stall por Latencia FP** |
|---|---|---|
| **Causa** | Dependencia RAW: `lw`/`flw` seguido de instrucción que usa el dato | Operación FP con latencia > 1 ciclo (FMUL, FDIV) |
| **Condición** | `(Rs1D == RdE) || (Rs2D == RdE)` donde EX es `lw`/`flw` | `latencyCounter > 0` |
| **Duración** | **1 ciclo fijo** | **Variable**: 0 (FADD), 3 (FMUL), 11 (FDIV) |
| **FlushE** | ✅ **SÍ** (inserta NOP en EX) | ❌ **NO** (mantiene FP en EX) |
| **Señal** | `loadUseStall` | `fpLatencyStall` |
| **Contador** | No usa contador | Usa `latencyCounter` (3 bits) |

## 🔍 Detección en el Código

### Stall Normal (Load-Use)
```verilog
assign loadUseStall = (ResultSrcE[0] && RegWriteE && 
                       ((Rs1D == RdE) || (Rs2D == RdE))) ||
                      (ResultSrcE[0] && FPRegWriteE && 
                       ((Rs1D == RdE) || (Rs2D == RdE)));
```

### Stall por Latencia FP
```verilog
assign fpLatencyStall = (latencyCounter > 4'b0);
```

## 📈 Ejemplo Visual

### Escenario 1: Load-Use Stall
```
Ciclo:   1     2     3     4
IF:      add   add   NOP   add
ID:      -     add   add   add
EX:      lw    NOP   add   ...
MEM:     -     lw    NOP   add
WB:      -     -     lw    NOP
          ↑           ↑
     Stall activo  Stall termina
     FlushE = 1    FlushE = 0
```

### Escenario 2: FP Latency Stall (FMUL)
```
Ciclo:   1     2     3     4     5
IF:      add   add   add   add   add
ID:      -     add   add   add   add
EX:      fmul  fmul  fmul  fmul  add
         ↓     ↓     ↓     ↓
latCounter: 3    2    1    0
fpLatStall: 1    1    1    0
FlushE:     0    0    0    0  ← NO se activa!
MEM:      -     -     -     fmul  add
WB:       -     -     -     -     fmul
```

## 🎯 Puntos Clave

1. **Load-Use Stall**: Espera 1 ciclo, **inserta NOP** en EX
2. **FP Latency Stall**: Espera múltiples ciclos, **mantiene FP** en EX
3. Ambos activan `StallF` y `StallD`
4. Solo Load-Use activa `FlushE`
5. FP Latency usa un contador que se decrementa cada ciclo

## 🔧 En el Waveform

### Para Load-Use Stall:
- `loadUseStall = 1` por **1 ciclo**
- `FlushE = 1` simultáneamente
- `InstrE` cambia a `0x00000013` (NOP)

### Para FP Latency Stall:
- `fpLatencyStall = 1` por **múltiples ciclos** (3 o 11)
- `FlushE = 0` (no se activa)
- `latencyCounter` decrementa: `3 → 2 → 1 → 0`
- `InstrE` mantiene la operación FP (no cambia a NOP)

