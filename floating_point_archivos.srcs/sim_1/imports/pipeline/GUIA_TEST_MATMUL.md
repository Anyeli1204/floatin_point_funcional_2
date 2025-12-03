# Guía de Prueba para Instrucción MATMUL

## 📋 Descripción

Esta guía explica cómo probar la instrucción `matmul` en el pipeline RISC-V.

## 🔧 Configuración

### 1. Archivos Necesarios

- **Testbench**: `testbench_matmul.v`
- **Programa de prueba**: `test_matmul.txt`
- **Datos de matrices**: `data_vec.txt` (ya existe)

### 2. Formato de `data_vec.txt`

El archivo `data_vec.txt` contiene las matrices en formato hexadecimal:

```
00000003    // Matriz A: filas = 3
00000002    // Matriz A: columnas = 2
3F800000    // A[0,0] = 1.0
40000000    // A[0,1] = 2.0
40400000    // A[1,0] = 3.0
40800000    // A[1,1] = 4.0
40A00000    // A[2,0] = 5.0
40C00000    // A[2,1] = 6.0
            // (línea vacía)
00000002    // Matriz B: filas = 2
00000005    // Matriz B: columnas = 5
3F800000    // B[0,0] = 1.0
40000000    // B[0,1] = 2.0
...         // (resto de elementos de B)
            // (línea vacía)
00000003    // Matriz C: filas = 3
00000005    // Matriz C: columnas = 5
00000000    // C inicializado en ceros
...
```

### 3. Direcciones Base

Las direcciones base se calculan como índices × 4 (word-aligned):

- **Matriz A**: índice 0 → dirección `0x00000000`
- **Matriz B**: índice 9 → dirección `0x00000024` (9 × 4 = 36 = 0x24)
- **Matriz C**: índice 22 → dirección `0x00000058` (22 × 4 = 88 = 0x58)

## 📝 Codificación de Instrucción MATMUL

### Formato de Instrucción

```
matmul.s vd, vs1, vs2
```

Donde:
- `vd` = registro destino (dirección base de matriz C)
- `vs1` = registro fuente 1 (dirección base de matriz A)
- `vs2` = registro fuente 2 (dirección base de matriz B)

### Codificación RISC-V

- **Opcode**: `1010011` (mismo que operaciones FP)
- **funct7**: `0100000` (0x20)
- **funct3**: `000`
- **rd**: número de registro destino (vd)
- **rs1**: número de registro fuente 1 (vs1)
- **rs2**: número de registro fuente 2 (vs2)

### Fórmula para Calcular Código Máquina

```c
instr = (0x20 << 25) | (rs2 << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x53
```

### Ejemplos

#### Ejemplo 1: `matmul.s v3, v1, v2`
- rd = 3, rs1 = 1, rs2 = 2
- Código: `0x402081D3`

#### Ejemplo 2: `matmul.s v1, v1, v2`
- rd = 1, rs1 = 1, rs2 = 2
- Código: `0x402080D3`

#### Ejemplo 3: `matmul.s v4, v3, v2`
- rd = 4, rs1 = 3, rs2 = 2
- Código: `0x40218253`

## 🚀 Ejecución del Testbench

### 1. Configurar el Testbench

El testbench (`testbench_matmul.v`) inicializa automáticamente los registros vectoriales:

```verilog
// v1 = dirección base de matriz A (0x00000000)
force dut.dp.vrf.vrf[1] = 32'h00000000;
// v2 = dirección base de matriz B (0x00000024)
force dut.dp.vrf.vrf[2] = 32'h00000024;
// v3 = dirección base de matriz C (0x00000058)
force dut.dp.vrf.vrf[3] = 32'h00000058;
```

### 2. Ejecutar Simulación

1. Abrir el proyecto en Vivado/Xilinx
2. Agregar `testbench_matmul.v` al proyecto de simulación
3. Configurar `imem.v` para cargar `test_matmul.txt`:
   ```verilog
   $readmemh("test_matmul.txt", RAM);
   ```
4. Ejecutar simulación
5. Revisar el waveform

### 3. Verificar Resultados

#### Señales a Monitorear

1. **`isMatmulE`**: Debe activarse cuando matmul está en etapa EX
2. **`matmul_busy`**: Debe mantenerse activo durante toda la ejecución
3. **`StallF`, `StallD`**: Deben activarse mientras `matmul_busy = 1`
4. **Registros vectoriales**: `v1`, `v2`, `v3` deben tener las direcciones correctas
5. **VEC_RAM**: Debe contener el resultado de la multiplicación

#### Resultado Esperado

Para matrices:
- A: 3×2
- B: 2×5
- C: 3×5 (resultado)

El resultado C[i,j] = Σ(k=0 to 1) A[i,k] × B[k,j]

Ejemplo: C[0,0] = A[0,0]×B[0,0] + A[0,1]×B[1,0]

## 🔍 Debugging

### Problemas Comunes

1. **`matmul_busy` nunca se activa**:
   - Verificar que `isMatmulE` se active
   - Verificar que los registros vectoriales tengan direcciones válidas
   - Verificar que `is_valid_matmul` sea verdadero (A_cols == B_rows)

2. **Pipeline no hace stall**:
   - Verificar que `matmul_busy` esté conectado a `hazard_unit`
   - Verificar que `StallF` y `StallD` se activen

3. **Resultado incorrecto**:
   - Verificar que `data_vec.txt` tenga el formato correcto
   - Verificar que las direcciones base sean correctas
   - Revisar el waveform para ver los valores en VEC_RAM

## 📊 Latencia Esperada

Para matrices A (m×k) y B (k×n), el resultado C (m×n) requiere:
- **Iteraciones totales**: m × n × k
- **Ciclos totales**: m × n × k (una iteración por ciclo)

Ejemplo: A (3×2), B (2×5) → 3 × 5 × 2 = **30 ciclos**

## 📝 Notas

- Los registros vectoriales (v0-v31) son independientes de los registros enteros (x0-x31) y FP (f0-f31)
- La instrucción matmul usa el vregfile, no el fregfile
- El testbench inicializa los registros vectoriales usando `force` porque no hay instrucciones normales que escriban en vregfile
- En una implementación completa, se necesitarían instrucciones adicionales para cargar direcciones en vregfile

