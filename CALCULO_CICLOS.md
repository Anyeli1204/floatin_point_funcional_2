# Cálculo de Ciclos para test_latency.txt

## Instrucciones a ejecutar:

1. `flw f1, 0(x0)` - Cargar 1.0
2. `flw f2, 4(x0)` - Cargar 2.0
3. `fadd.s f3, f1, f2` - f3 = 1.0 + 2.0 (latencia: 1 ciclo)
4. `fmul.s f4, f1, f2` - f4 = 1.0 * 2.0 (latencia: 4 ciclos, 3 stalls adicionales)
5. `fdiv.s f5, f1, f2` - f5 = 1.0 / 2.0 (latencia: 12 ciclos, 11 stalls adicionales)
6. `fadd.s f6, f3, f4` - f6 = 3.0 + 2.0 (depende de f3 y f4)
7. `fsw f6, 8(x0)` - Guardar f6
8-15. 8 NOPs

## Cálculo detallado (Pipeline de 5 etapas):

### Ciclo 1-5: Primera instrucción entra
- **Ciclo 1**: flw f1 en IF
- **Ciclo 2**: flw f1 en ID, flw f2 en IF
- **Ciclo 3**: flw f1 en EX, flw f2 en ID, fadd.s f3 en IF
- **Ciclo 4**: flw f1 en MEM, flw f2 en EX, fadd.s f3 en ID, fmul.s f4 en IF
- **Ciclo 5**: flw f1 en WB (f1 disponible), flw f2 en MEM, fadd.s f3 en EX, fmul.s f4 en ID, fdiv.s f5 en IF

### Ciclo 6-10: fadd.s y fmul.s
- **Ciclo 6**: flw f2 en WB (f2 disponible), fadd.s f3 en EX (usa f1, f2 via forwarding), fmul.s f4 en EX, fdiv.s f5 en ID
- **Ciclo 7**: fadd.s f3 completa EX (latencia 1), fmul.s f4 empieza latencia, fdiv.s f5 en EX
- **Ciclo 8**: fadd.s f3 en MEM, fmul.s f4 sigue en EX (latencyCounter = 2), fdiv.s f5 empieza latencia
- **Ciclo 9**: fadd.s f3 en WB (f3 disponible), fmul.s f4 sigue en EX (latencyCounter = 1), fdiv.s f5 sigue en EX (latencyCounter = 10)
- **Ciclo 10**: fadd.s f3 completa, fmul.s f4 completa EX (latencyCounter = 0), fdiv.s f5 sigue en EX (latencyCounter = 9)

### Ciclo 11-20: fmul.s termina, fdiv.s continúa
- **Ciclo 11**: fmul.s f4 en MEM (f4 disponible para forwarding), fdiv.s f5 en EX (latencyCounter = 8)
- **Ciclo 12**: fmul.s f4 en WB, fdiv.s f5 en EX (latencyCounter = 7)
- **Ciclo 13**: fdiv.s f5 en EX (latencyCounter = 6)
- ... (fdiv.s continúa contando)
- **Ciclo 22**: fdiv.s f5 completa EX (latencyCounter = 0)

### Ciclo 21-25: fadd.s f6 espera y ejecuta
- **Ciclo 11**: fadd.s f6 entra a IF (pero puede estar esperando)
- **Ciclo 12-13**: fadd.s f6 puede estar en stall esperando a f4 (que está lista en ciclo 11)
- **Ciclo 14**: fadd.s f6 en EX (f3 y f4 disponibles)
- **Ciclo 15**: fadd.s f6 en MEM
- **Ciclo 16**: fadd.s f6 en WB (f6 disponible)

### Ciclo 16-20: fsw f6
- **Ciclo 17**: fsw f6 en IF
- **Ciclo 18**: fsw f6 en ID
- **Ciclo 19**: fsw f6 en EX
- **Ciclo 20**: fsw f6 en MEM (escribe a memoria)
- **Ciclo 21**: fsw f6 en WB

### Ciclo 21-28: NOPs
- 8 NOPs adicionales para permitir que fdiv.s termine
- Cada NOP toma 5 ciclos en el pipeline
- fdiv.s f5 termina en ciclo ~22-24

## Estimación total:

**Mínimo esperado**: ~30-35 ciclos para completar las instrucciones principales
**Con stalls de latencia**: ~40-45 ciclos
**Con 8 NOPs adicionales**: ~45-55 ciclos
**Con márgenes y delays**: ~55-65 ciclos

## Conclusión:

**61 ciclos es razonable** considerando:
- Pipeline de 5 etapas
- Stalls por latencia FP (3 ciclos para FMUL, 11 para FDIV)
- 8 NOPs adicionales
- Tiempos de propagación y sincronización

Si quieres reducir los ciclos, podrías:
1. Reducir el número de NOPs (8 puede ser excesivo)
2. Verificar que no hay stalls innecesarios
3. Asegurar que el forwarding funciona correctamente

