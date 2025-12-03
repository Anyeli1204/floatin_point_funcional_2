# Guía de Verificación del Matmul en Waveform

## Señales Clave para Monitorear

### 1. Señales de Control del Matmul

**En el módulo `matmul`:**
- `is_matmul_op` → Debe ser `1` cuando la instrucción matmul está en EX
- `matmul_active` → Debe activarse cuando `is_matmul_op = 1` y mantenerse hasta que `done = 1`
- `matmul_busy` → Debe ser igual a `matmul_active`
- `done` → Debe activarse cuando todas las iteraciones terminan (`curr_i >= num_i`)

**En el módulo `vdatapath` (DP):**
- `curr_i`, `curr_j`, `curr_k` → Índices actuales de la iteración
- `valid_iter` → Debe ser `1` cuando estamos en una iteración válida
- `advance` → Debe ser `1` cuando avanzamos a la siguiente iteración

### 2. Señales de Lectura de Matrices A y B

**En el módulo `vdatapath` (DP):**
- `addr_a` → Dirección de lectura de matriz A (debe cambiar según `curr_i` y `curr_k`)
- `addr_b` → Dirección de lectura de matriz B (debe cambiar según `curr_k` y `curr_j`)
- `rd1` → Valor leído de matriz A (desde `VEC_RAM[addr_a]`)
- `rd2` → Valor leído de matriz B (desde `VEC_RAM[addr_b]`)

**Ejemplo de valores esperados (primera iteración, i=0, j=0, k=0):**
```
curr_i = 0, curr_j = 0, curr_k = 0
addr_a = baseA + (0 * 2 + 0) * 4 = baseA + 0 = 0x00000008 → VEC_RAM[2] = 1.0
addr_b = baseB + (0 * 5 + 0) * 4 = baseB + 0 = 0x0000002C → VEC_RAM[11] = 1.0
rd1 = 0x3F800000 (1.0 en IEEE-754)
rd2 = 0x3F800000 (1.0 en IEEE-754)
```

### 3. Señales de Cálculo

**En el módulo `vdatapath` (DP):**
- `prod` → Producto de `rd1 * rd2` (calculado por `alusito1` con `FALUControl = 3'b010`)

**Ejemplo (primera iteración):**
```
rd1 = 1.0, rd2 = 1.0
prod = 1.0 * 1.0 = 1.0 = 0x3F800000
```

### 4. Señales de Escritura en Matriz C

**En el módulo `vdatapath` (DP):**
- `addr_c` → Dirección de escritura en matriz C (debe cambiar según `curr_i` y `curr_j`)
- `we` → Write enable (debe ser `1` cuando `valid_iter = 1` y `!reset`)

**En el módulo `vmem` (vector_mem):**
- `rv_c` → Valor actual en `VEC_RAM[addr_c]` (valor acumulado previo)
- `wd` → Dato a escribir (`prod` desde vdatapath)
- `sum` → Suma acumulativa: `rv_c + wd` (calculado por `alusito2` con `FALUControl = 3'b000`)

**Ejemplo (primera iteración, i=0, j=0, k=0):**
```
addr_c = baseC + (0 * 5 + 0) * 4 = baseC + 0 = 0x00000060 → VEC_RAM[24]
rv_c = VEC_RAM[24] = 0.0 (inicial)
wd = prod = 1.0
sum = 0.0 + 1.0 = 1.0 = 0x3F800000
```

**En el siguiente ciclo de reloj (si `we = 1`):**
```
VEC_RAM[24] <= sum = 1.0
```

### 5. Verificación de VEC_RAM

**Monitorear directamente:**
- `dut.rvpipeline.dp.matmul_unit.DP.vector_mem.VEC_RAM[24]` hasta `VEC_RAM[38]`
- Estos son los elementos de la matriz C (3 filas × 5 columnas = 15 elementos)

## Ejemplo Completo: Primera Iteración (i=0, j=0, k=0)

### Valores Esperados:

```
curr_i = 0, curr_j = 0, curr_k = 0
baseA = 0x00000008 (VEC_RAM[2])
baseB = 0x0000002C (VEC_RAM[11])
baseC = 0x00000060 (VEC_RAM[24])

// Lectura
addr_a = 0x00000008 → VEC_RAM[2] = 1.0 (A[0][0])
addr_b = 0x0000002C → VEC_RAM[11] = 1.0 (B[0][0])
rd1 = 0x3F800000 (1.0)
rd2 = 0x3F800000 (1.0)

// Cálculo
prod = rd1 * rd2 = 1.0 * 1.0 = 1.0 = 0x3F800000

// Escritura
addr_c = 0x00000060 → VEC_RAM[24] (C[0][0])
rv_c = VEC_RAM[24] = 0.0 (inicial)
wd = prod = 1.0
sum = rv_c + wd = 0.0 + 1.0 = 1.0 = 0x3F800000
we = valid_iter && !reset = 1 && 1 = 1

// En el siguiente ciclo de reloj:
VEC_RAM[24] <= 1.0
```

## Ejemplo: Segunda Iteración (i=0, j=0, k=1)

```
curr_i = 0, curr_j = 0, curr_k = 1
addr_a = 0x0000000C → VEC_RAM[3] = 2.0 (A[0][1])
addr_b = 0x00000040 → VEC_RAM[16] = 6.0 (B[1][0])
rd1 = 0x40000000 (2.0)
rd2 = 0x40C00000 (6.0)

prod = 2.0 * 6.0 = 12.0 = 0x41400000

addr_c = 0x00000060 → VEC_RAM[24] (C[0][0])
rv_c = VEC_RAM[24] = 1.0 (valor acumulado anterior)
wd = prod = 12.0
sum = 1.0 + 12.0 = 13.0 = 0x41500000

// En el siguiente ciclo de reloj:
VEC_RAM[24] <= 13.0
```

## Resultado Final Esperado

Después de ejecutar todas las iteraciones (3×5×2 = 30 iteraciones), la matriz C debe contener:

```
C = A × B = [1.0  2.0] × [1.0  2.0  3.0  4.0  5.0]
            [3.0  4.0]   [6.0  7.0  8.0  9.0  10.0]
            [5.0  6.0]

C[0][0] = 1.0*1.0 + 2.0*6.0 = 1.0 + 12.0 = 13.0
C[0][1] = 1.0*2.0 + 2.0*7.0 = 2.0 + 14.0 = 16.0
C[0][2] = 1.0*3.0 + 2.0*8.0 = 3.0 + 16.0 = 19.0
C[0][3] = 1.0*4.0 + 2.0*9.0 = 4.0 + 18.0 = 22.0
C[0][4] = 1.0*5.0 + 2.0*10.0 = 5.0 + 20.0 = 25.0

C[1][0] = 3.0*1.0 + 4.0*6.0 = 3.0 + 24.0 = 27.0
C[1][1] = 3.0*2.0 + 4.0*7.0 = 6.0 + 28.0 = 34.0
C[1][2] = 3.0*3.0 + 4.0*8.0 = 9.0 + 32.0 = 41.0
C[1][3] = 3.0*4.0 + 4.0*9.0 = 12.0 + 36.0 = 48.0
C[1][4] = 3.0*5.0 + 4.0*10.0 = 15.0 + 40.0 = 55.0

C[2][0] = 5.0*1.0 + 6.0*6.0 = 5.0 + 36.0 = 41.0
C[2][1] = 5.0*2.0 + 6.0*7.0 = 10.0 + 42.0 = 52.0
C[2][2] = 5.0*3.0 + 6.0*8.0 = 15.0 + 48.0 = 63.0
C[2][3] = 5.0*4.0 + 6.0*9.0 = 20.0 + 54.0 = 74.0
C[2][4] = 5.0*5.0 + 6.0*10.0 = 25.0 + 60.0 = 85.0
```

**Valores en VEC_RAM (después de matmul):**
```
VEC_RAM[24] = 0x41500000 (13.0)  // C[0][0]
VEC_RAM[25] = 0x41800000 (16.0)  // C[0][1]
VEC_RAM[26] = 0x41980000 (19.0)  // C[0][2]
VEC_RAM[27] = 0x41B00000 (22.0)  // C[0][3]
VEC_RAM[28] = 0x41C80000 (25.0)  // C[0][4]
VEC_RAM[29] = 0x41D80000 (27.0)  // C[1][0]
VEC_RAM[30] = 0x42080000 (34.0)  // C[1][1]
VEC_RAM[31] = 0x42280000 (41.0)  // C[1][2]
VEC_RAM[32] = 0x42400000 (48.0)  // C[1][3]
VEC_RAM[33] = 0x425C0000 (55.0)  // C[1][4]
VEC_RAM[34] = 0x42280000 (41.0)  // C[2][0]
VEC_RAM[35] = 0x42500000 (52.0)  // C[2][1]
VEC_RAM[36] = 0x427C0000 (63.0)  // C[2][2]
VEC_RAM[37] = 0x42940000 (74.0)  // C[2][3]
VEC_RAM[38] = 0x42AA0000 (85.0)  // C[2][4]
```

## Pasos para Verificar en el Waveform

1. **Verifica que `matmul_active` se active:**
   - Busca cuando `is_matmul_op = 1`
   - `matmul_active` debe pasar a `1`

2. **Verifica las lecturas:**
   - Monitorea `addr_a`, `addr_b`, `rd1`, `rd2`
   - Verifica que los valores leídos correspondan a los elementos correctos de A y B

3. **Verifica el cálculo:**
   - Monitorea `prod`
   - Debe ser `rd1 * rd2`

4. **Verifica las escrituras:**
   - Monitorea `addr_c`, `rv_c`, `wd`, `sum`, `we`
   - Verifica que `sum = rv_c + wd`
   - Verifica que `we = 1` cuando `valid_iter = 1`

5. **Verifica VEC_RAM:**
   - Al final de la ejecución, verifica que `VEC_RAM[24]` hasta `VEC_RAM[38]` contengan los valores esperados

6. **Verifica que `done` se active:**
   - Cuando `curr_i >= num_i` (curr_i >= 3)
   - `done` debe pasar a `1`
   - `matmul_active` debe pasar a `0`
   - `matmul_busy` debe pasar a `0`

## Conversión de Valores IEEE-754

Para verificar valores en hexadecimal:
- `0x3F800000` = 1.0
- `0x40000000` = 2.0
- `0x40400000` = 3.0
- `0x40800000` = 4.0
- `0x40A00000` = 5.0
- `0x40C00000` = 6.0
- `0x40E00000` = 7.0
- `0x41000000` = 8.0
- `0x41100000` = 9.0
- `0x41200000` = 10.0
- `0x41500000` = 13.0
- `0x41800000` = 16.0
- `0x41980000` = 19.0
- `0x41B00000` = 22.0
- `0x41C80000` = 25.0
- `0x41D80000` = 27.0
- `0x42080000` = 34.0
- `0x42280000` = 41.0
- `0x42400000` = 48.0
- `0x425C0000` = 55.0
- `0x42500000` = 52.0
- `0x427C0000` = 63.0
- `0x42940000` = 74.0
- `0x42AA0000` = 85.0

