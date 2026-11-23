# CA0309_Proyecto

Proyecto final de CA0309 Contingencias de Vida II, grupo 5.

## Cómo correr el código

Abrir R con la carpeta raíz del proyecto como directorio de trabajo (`here()` la reconoce por la carpeta `.git`) y correr los scripts en este orden:

| Script | Sección | Resultado |
|---|---|---|
| `R/1_depuracion .R` | Depuración de la base | `datos/procesados/Población CA-0309.xlsx` |
| `R/2_mortalidad.R` | A. Decrementos y multiestado | `datos/procesados/Resultados A.xlsx` |
| `R/3_profit_testing.R` | C. Flujos, reservas y profit testing | `datos/procesados/Resultados C.xlsx` |
| `R/4_escenario_adverso.R` | D. Escenario adverso y respaldo | `datos/procesados/Resultados D.xlsx`, `figuras/recursos_vs_reserva.pdf` |
| `R/equity_linked.R` | E. Equity-linked y cargo adicional | `resultados/equity_linked/` |

`4_escenario_adverso.R` carga `3_profit_testing.R` con `source()`, así que basta correr el 4 para obtener C y D.

La sección E se ejecuta por separado. Las instrucciones y la ficha del foro están en [informe/equity_linked](informe/equity_linked/README.md).

Paquetes: `tidyverse`, `readxl`, `writexl`, `here`.

## Parámetros de C y D

| Parámetro | Base | Adverso |
|---|---|---|
| Prima anual por contrato, C | 50 000 | 50 000 |
| Beneficio por muerte, b | 5 000 000 | 5 000 000 |
| Gasto anual por vigente, e | 10 000 | 11 000 |
| Comisión sobre prima | 5 % | 5 % |
| Adquisición por contrato, k | 75 000 | 75 000 |
| Rendimiento anual, i | 5 % | 4 % |
| Descuento anual, d | 4 % | 4 % |
| Reserva por contrato al cierre de los años 1 a 5 | 40 000, 35 000, 25 000, 15 000, 0 | igual |

Los montos de `Resultados C.xlsx` y `Resultados D.xlsx` están en unidades monetarias; en el informe se muestran en millones.
