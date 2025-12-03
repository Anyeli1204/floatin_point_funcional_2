# Estructura de Memoria para MATMUL

## Formato de Matriz en VEC_RAM

Cada matriz se estructura así en memoria (VEC_RAM):

```
VEC_RAM[addr]     = número de filas (A_rows)
VEC_RAM[addr+1]   = número de columnas (A_cols)
VEC_RAM[addr+2]   = primer elemento de la matriz (row-major order)
VEC_RAM[addr+3]   = segundo elemento
...
```

## Ejemplo con data_vec.txt

### Matriz A (dirección base: índice 0 en VEC_RAM)
```
VEC_RAM[0]  = 0x00000003 = 3 filas
VEC_RAM[1]  = 0x00000002 = 2 columnas
VEC_RAM[2]  = 0x3F800000 = 1.0 (IEEE-754)
VEC_RAM[3]  = 0x40000000 = 2.0
VEC_RAM[4]  = 0x40400000 = 3.0
VEC_RAM[5]  = 0x40800000 = 4.0
VEC_RAM[6]  = 0x40A00000 = 5.0
VEC_RAM[7]  = 0x40C00000 = 6.0
```

Matriz A es 3x2:
```
A = [1.0  2.0]
    [3.0  4.0]
    [5.0  6.0]
```

### Matriz B (dirección base: índice 9 en VEC_RAM)
```
VEC_RAM[9]  = 0x00000002 = 2 filas
VEC_RAM[10] = 0x00000005 = 5 columnas
VEC_RAM[11] = 0x3F800000 = 1.0
VEC_RAM[12] = 0x40000000 = 2.0
VEC_RAM[13] = 0x40400000 = 3.0
VEC_RAM[14] = 0x40800000 = 4.0
VEC_RAM[15] = 0x40A00000 = 5.0
VEC_RAM[16] = 0x40C00000 = 6.0
VEC_RAM[17] = 0x40E00000 = 7.0
VEC_RAM[18] = 0x41000000 = 8.0
VEC_RAM[19] = 0x41100000 = 9.0
VEC_RAM[20] = 0x41200000 = 10.0
```

Matriz B es 2x5:
```
B = [1.0  2.0  3.0  4.0  5.0]
    [6.0  7.0  8.0  9.0  10.0]
```

### Matriz C (dirección base: índice 22 en VEC_RAM)
```
VEC_RAM[22] = 0x00000003 = 3 filas
VEC_RAM[23] = 0x00000005 = 5 columnas
VEC_RAM[24] = 0x00000000 = 0.0 (inicializado en ceros)
VEC_RAM[25] = 0x00000000 = 0.0
...
```

Matriz C será 3x5 (resultado de A × B):
```
C = A × B = [1.0  2.0] × [1.0  2.0  3.0  4.0  5.0]
            [3.0  4.0]   [6.0  7.0  8.0  9.0  10.0]
            [5.0  6.0]

Resultado esperado:
C = [13.0  16.0  19.0  22.0  25.0]
    [27.0  34.0  41.0  48.0  55.0]
    [41.0  52.0  63.0  74.0  85.0]
```

## Registros Vectoriales

Los registros `v1`, `v2`, `v3` contienen **direcciones base** (índices de palabra en VEC_RAM):

```
v1 = 0x00000000 → dirección base de matriz A (índice 0)
v2 = 0x00000024 → dirección base de matriz B (índice 9, 9*4 = 36 = 0x24)
v3 = 0x00000058 → dirección base de matriz C (índice 22, 22*4 = 88 = 0x58)
```

**NOTA:** Las direcciones son en bytes, pero VEC_RAM usa índices de palabra (word-aligned).
Por eso:
- `v1 = 0x00000000` → VEC_RAM[0]
- `v2 = 0x00000024` → VEC_RAM[9] (0x24 / 4 = 9)
- `v3 = 0x00000058` → VEC_RAM[22] (0x58 / 4 = 22)

## Cómo el código lee las dimensiones

```verilog
// En matmul.v:
addr_a = v1 = 0x00000000
addr_b = v2 = 0x00000024
addr_c = v3 = 0x00000058

// Lee dimensiones:
rd_A_rows = VEC_RAM[addr_a[31:2]] = VEC_RAM[0] = 3
rd_A_cols = VEC_RAM[(addr_a+4)[31:2]] = VEC_RAM[1] = 2
rd_B_rows = VEC_RAM[addr_b[31:2]] = VEC_RAM[9] = 2
rd_B_cols = VEC_RAM[(addr_b+4)[31:2]] = VEC_RAM[10] = 5

// Bases de datos (empiezan después de las dimensiones):
baseA = addr_a + 8 = 0x00000008 → VEC_RAM[2] (primer dato de A)
baseB = addr_b + 8 = 0x0000002C → VEC_RAM[11] (primer dato de B)
baseC = addr_c + 8 = 0x00000060 → VEC_RAM[24] (primer dato de C)
```

## Verificación

Para verificar que la instrucción matmul funciona:

1. **Verifica las dimensiones:**
   - `A_rows = 3`, `A_cols = 2`
   - `B_rows = 2`, `B_cols = 5`
   - `is_valid_matmul = (A_cols == B_rows) = (2 == 2) = true` ✓

2. **Verifica los datos iniciales:**
   - Matriz A: valores 1.0, 2.0, 3.0, 4.0, 5.0, 6.0
   - Matriz B: valores 1.0, 2.0, ..., 10.0
   - Matriz C: inicializada en ceros

3. **Verifica el resultado:**
   - Después de ejecutar matmul, verifica VEC_RAM[24] hasta VEC_RAM[38]
   - Debe contener el resultado de A × B

## Si usas v1=1, v2=2, v3=3

Si cambias los registros a:
```
v1 = 0x00000004 → VEC_RAM[1] (pero esto es donde está A_cols, no A_rows!)
v2 = 0x00000008 → VEC_RAM[2]
v3 = 0x0000000C → VEC_RAM[3]
```

**Esto NO funcionará** porque:
- `v1 = 0x00000004` apunta a `VEC_RAM[1]` que contiene `A_cols = 2`, no `A_rows`
- Necesitas que `v1` apunte a donde está `A_rows` (índice 0)

**Solución:** Usa las direcciones correctas:
- `v1 = 0x00000000` (índice 0, donde empieza matriz A)
- `v2 = 0x00000024` (índice 9, donde empieza matriz B)
- `v3 = 0x00000058` (índice 22, donde empieza matriz C)

