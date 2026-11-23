# Aporte del integrante 4

## Ejecución e integración

Desde la carpeta `CA0309_Proyecto`, ejecutar con R instalado.

```sh
Rscript --vanilla R/equity_linked.R
```

El código usa `tidyverse` y `here`, igual que los scripts de población y mortalidad del grupo. Se ejecutó con R 4.5.2, semilla 2026, generador Mersenne-Twister y método de inversión para las normales. Lee las tasas masculinas de las edades 45 a 49 de `datos/originales/CA0309_Mortalidad_CR2023.csv`. Actualiza la cuenta con `mutate()` en cada año y resume los resultados por caso con `summarise()`. Al final carga `informe/equity_linked/formato_informe.R` para generar las tablas de LaTeX y el histograma.

- `main-3.tex`, en la raíz del proyecto, ya contiene la sección E, el cálculo adicional del Grupo 5 y el anexo E.
- `seccion_E.tex` y `anexo_E.tex` permiten copiar el aporte a una versión posterior del informe grupal.
- `ficha_foro.pdf` es la ficha de una página para compartir antes del foro. Su fuente editable es `ficha_foro.tex`.

El `main-3.tex` incluye las tablas generadas por el script. Para compilarlo en Overleaf, el histograma `histograma_npv.pdf` puede ir junto al `main-3.tex` o en `resultados/equity_linked/`. La portada y el anexo D requieren los gráficos del informe grupal. Para regenerar la ficha, compilar `informe/equity_linked/ficha_foro.tex` con pdfLaTeX desde la raíz del proyecto.

## Archivos generados

El programa guarda las salidas en `resultados/equity_linked/`. Los CSV usan coma como delimitador y punto decimal.

| Archivo | Contenido |
|---|---|
| `comparacion.csv` | Indicadores de los tres diseños por contrato emitido. Las frecuencias se expresan como proporciones. |
| `permanencia.csv` | Mortalidad, renuncia, permanencia y factor de VP de los cargos de cada año. |
| `normales.csv` | Los cinco choques normales por trayectoria, compartidos por los tres diseños. |
| `trayectorias.csv` | Saldo final, cargos en VP, complemento nominal y en VP, NPV y pérdida de cada trayectoria por diseño. |
| `trayectoria_1_por_anio.csv` | Saldos, cargo, rendimiento y VP de cada cargo de la trayectoria de comprobación. |
| `histograma_npv.pdf` | Distribuciones de NPV con intervalos y escalas comunes. |
| `comparacion.tex`, `trayectoria_1.tex`, `trayectoria_1_anual.tex` | Tablas para la ficha, el informe y el anexo. |

## Verificación para la defensa

1. La permanencia del primer año es `(1 − 0,003278) × (1 − 0,03) = 0,96682034`. El cargo del primer año tiene peso 1 porque se cobra al emitir.
2. La trayectoria 1 empieza con un rendimiento de `12,534354 %`. Con cargo del 2 %, se retiran `2 000` u.m. El saldo de cierre es `98 000 × 1,125343543… = 110 283,67` u.m.
3. Al cierre del quinto año, el saldo con cargo del 2 % es `92 616,64` u.m. La garantía de `100 000` genera un complemento de `7 383,36` u.m. Su VP ponderado es `5 118,63` u.m. y el VP de cargos es `8 801,98` u.m. La diferencia da un NPV de `3 683,35` u.m. La garantía se activa y el proveedor obtiene utilidad en esa trayectoria.

La ejecución en una carpeta limpia reprodujo los CSV y las tablas LaTeX. Un recálculo independiente usó la forma cerrada del saldo $A_t=A_0(1-c)^t\exp[\sum_{k=1}^t(0{,}04+0{,}15Z_k)]$ para cotejar las 3 000 valoraciones, la trayectoria detallada y los indicadores. El script también comprueba que elevar la garantía con el mismo cargo aumenta o mantiene el complemento y reduce o mantiene el NPV en cada trayectoria.

## Registro individual para el informe

| Nombre | Tarea técnica | Bloque de código | Resultado | Verificación |
|---|---|---|---|---|
| Gabriel de Jesús Chaves Esquivel | Sección E y variación del cargo para la garantía mayor | `R/equity_linked.R`, cálculo de permanencia, proyección por año y valoración de cada garantía | Comparación de los tres diseños, histograma, trayectoria de comprobación y recomendación | Reejecución de R, cotejo con fórmula cerrada y comprobación por trayectoria del efecto de la garantía |

### Declaración de IA para revisar antes de entregar

El 22 y el 23 de noviembre de 2026 se usó Codex (GPT-6) como apoyo para escribir y simplificar el código de R, generar las tablas y el histograma y redactar la sección E, el cálculo adicional y la ficha. Se verificaron los resultados con una reejecución y un cálculo independiente del saldo. Tras simplificar el script, los CSV y las tablas LaTeX dieron exactamente la misma salida. Para completar la declaración, indicar la comprobación que realizó personalmente el integrante y su responsabilidad sobre la interpretación, el cálculo y la defensa.
