# Guía de trabajo de varias vidas y NIIF 17

**Proyecto:** CA-0309 Contingencia de Vida II, II ciclo 2026, UCR. **Grupo 5:** equipo actuarial, defensa de ronda 3. **Horizonte:** cinco años desde el 31/12/2025. **Lenguaje:** R para la lectura y el cálculo. Se asumen los resultados entregados por los compañeros y no se generan archivos de auditoría. **Fuente normativa del encargo:** `CA0309_Grupo5_Instrucciones_Revisadas.pdf`, páginas 1–6; en particular B (p. 2), F (p. 4) y convenciones (p. 5). El `forro examen 1.pdf` es referencia para varias vidas. Este documento es una guía operativa; prevalece el enunciado oficial si existe cualquier diferencia.

## 0. Objetivo y límites

Este bloque comprende **(B)** tres rentas temporales alternativas de varias vidas con parejas hipotéticas y **(F)** una interpretación conceptual de NIIF 17 de **máximo una página** aplicada al seguro de fallecimiento de C. Los demás integrantes ya terminaron sus bloques: **no reconstruir ni modificar sus resultados** salvo que se identifique y documente una inconsistencia. La sección B se alimenta de la población inicial limpia de A y de la tabla oficial de mortalidad; la sección F se apoya en las tablas reales de C y, si aporta contexto, D. El equity-linked E y su cargo de 3 % no son parte de B ni de F.

El resultado final debe incorporarse al informe existente, caber en el máximo global de **10 páginas de contenido**, conservar los anexos de tablas y registrar contribuciones individuales y uso/verificación de IA.

## 1. Insumos y precedencia

### Imprescindibles

1. Guía oficial PDF del grupo 5.
2. `CA0309_Mortalidad_CR2023.csv`: `edad`, `qx_masculino`, `qx_femenino`; mortalidad biológica (no tasas de renuncia).
3. Base inicial limpia o archivo de cohortes (edad cumplida al 31/12/2025, sexo y cantidad) exportado por el integrante 1; su código de depuración para rastrear decisiones.
4. Script y tablas definitivas del integrante 3: flujos de primas, gastos, comisiones, siniestros, reservas, resultados, NPV y margen del caso base; de ser posible saldos y aportes, y escenario adverso.
5. Archivo fuente del informe compartido (LaTeX/Markdown), sus subarchivos, figuras, bibliografía y comando de compilación.

### Referencias útiles

- `forro examen 1.pdf`: seguros/rentas de varias vidas, último sobreviviente y reversión.
- `ForroIIContiII.pdf`: profit testing y el significado de NPV/margen; no trasladar sus ejemplos numéricos al proyecto.
- Código y presentación de otros integrantes, para respetar notación y estilo.
- `CONTEXTO_CODEX_VARIAS_VIDAS_B_F.md`, si ya está en el repositorio; usarlo como contexto secundario, no como fuente de cifras verificadas.

### Jerarquía de autoridad

**Enunciado oficial > código y salidas definitivas del equipo > forros de clase > notas/diálogos anteriores.** No copiar cifras preliminares de conversaciones como resultados finales. Las referencias de una exploración anterior (`N0=104004`, con pareja teórica `97249`, sin pareja `6755`) son **solo controles preliminares**, no constantes a imponer.

## 2. Etapa de reconocimiento del repositorio (Codex)

Antes de escribir código:

1. Consultar `git status`; no sobrescribir cambios de otros integrantes y trabajar en rama propia cuando corresponda.
2. Listar el repositorio: scripts de A/C/D/E, carpetas de datos limpios, tablas, figuras, informe `.tex`, instrucciones de ejecución y pruebas.
3. Mantener el flujo íntegramente en R y reutilizar las convenciones y salidas existentes del repositorio.
4. Rastrear dónde A genera la población limpia/cohortes y dónde C calcula NPV/margen. Anotar las rutas exactas, sin inventarlas.
5. Leer las páginas B, F y convenciones del documento oficial. Leer el forro de varias vidas.
6. Revisar los formatos: codificación, separador, nombres y semántica de columnas, representación de género, niveles de agregación, fechas y posibilidad de duplicados.
7. Anotar línea base reproducible: tamaño de Activos, exclusiones, `N0`, conteos por sexo/edad. Si no existe salida limpia, ejecutar el script de A; en última instancia derivarla del archivo bruto replicando **exactamente** la depuración de A, sin crear una depuración incompatible.
8. Abrir el informe existente y verificar cómo incluye subarchivos, tablas y figuras; reservar las secciones B y F sin alterar C/D/E.

**Salida de etapa:** un inventario de rutas reales y una nota de las dependencias resueltas; ningún cálculo inventado.

## 3. Sección B: metodología completa

### 3.1 Universo inicial y reglas de parejas

La población parte de **Activos admisibles de A**, con una observación por persona, agrupables por `edad_inicial = x` y `sexo_activo = s` y cantidad inicial `n_{x,s}`. Los menores de 30 años **no tienen pareja hipotética y no generan pagos en B**; siguen incluidos en A/C. Los activos con `x >= 30` reciben **una pareja hipotética** del sexo opuesto, sin buscar registros ni matrimonios reales en Excel.

Definir:

- `delta(x)=0`, si `30 <= x < 35`;
- `delta(x)=3`, si `35 <= x < 55`;
- `delta(x)=5`, si `x >= 55`.
- Si el activo es hombre, `y=x-delta(x)` y la pareja es mujer.
- Si la activa es mujer, `y=x+delta(x)` y la pareja es hombre.

Las parejas se asignan **una sola vez en t=0**, y durante la proyección las edades avanzan en paralelo: al inicio de año `t`, `x+t-1` y `y+t-1`. No se modelan nuevos matrimonios, divorcios, nuevas parejas ni reemparejamientos.

**Exclusión solo de B:** pareja con edad inicial `y>106` o cualquier combinación sin probabilidades para completar los cinco años. También validar que existan todos los `q_{x+j,s}` y `q_{y+j,sexo_pareja}` para `j=0,...,4`; no extrapolar ni rellenar probabilidades. Reportar cohortes/registros excluidos en B (y la cantidad de activos afectada) de forma separada de la depuración A. No quitar estos activos de A/C.

### 3.2 Mortalidad exclusivamente biológica

Usar `qx_masculino` y `qx_femenino` del CSV. **NO** combinar con renuncia de 3 %, no usar `p_AA` de decrementos múltiples, ni multiplicar por `N_t` de A, ni considerar otros estados del seguro colectivo.

Para cada cohorte admisible y `t=1,...,5`:

`S_x(0)=S_y(0)=1`

`S_x(t)=∏_{j=0}^{t-1}(1-q_{x+j,s})`

`S_y(t)=∏_{j=0}^{t-1}(1-q_{y+j,sexo_opuesto})`

**Independencia entre tiempos de vida** (supuesto del ejercicio):

`P(ambos vivos en t) = S_x(t)·S_y(t)`.

`P(al menos uno vivo en t) = S_x(t)+S_y(t)-S_x(t)·S_y(t)`.

`P(cónyuge vivo y activo fallecido en t) = S_y(t)·[1-S_x(t)]`.

La tercera probabilidad es un **estatus al cierre** (activo falleció antes o en t y cónyuge permanece vivo), no necesariamente "muerte durante el año t"; distinguirla de un beneficio de fallecimiento único. El último sobreviviente significa **al menos uno vivo**, no solo el cónyuge vivo.

### 3.3 Rentas temporales y agregación

Cada renta paga **1 unidad al cierre de cada año** en que se cumple el estatus. Tipo de descuento efectivo del proyecto `d=0.04` (no rendimiento de fondos `i=0.05`), `v=(1.04)^(-1)`.

Para estatus `h` en `{ambos, al_menos_uno, conyuge_vivo_activo_fallecido}`:

`VP_h(x,s) = Σ_{t=1}^{5} P_h(x,s;t)/(1.04)^t`.

Agregar **con cantidades iniciales**, y no con población superviviente tras renuncia:

`VP_h^cartera = Σ_{(x,s) admisibles en B} n_{x,s} VP_h(x,s)`.

**Unidad:** suma de valores presentes de rentas **unitarias**, equivalente a unidades de pago descontadas para la cohorte; no confundir con colones, reservas o resultados monetarios del seguro. Son **tres coberturas alternativas**: NO sumar `VP_ambos + VP_al_menos_uno + VP_conyuge` como una obligación ni incorporarlos en C o D.

### 3.4 Ejemplo de comprobación de reglas (sin inventar q)

- Activo hombre de 45 años: `delta=3`, cónyuge mujer de 42 años.
- Activa mujer de 45 años: `delta=3`, cónyuge hombre de 48 años.
- Activo de 32 años: `delta=0`, cónyuge de 32 años y sexo opuesto.
- Activa de 60 años: `delta=5`, cónyuge hombre de 65 años.

Estas asignaciones permiten probar la función de edades antes de correr el cálculo real.

### 3.5 Tablas a exportar desde código

1. `resumen_parejas_B.csv`: activos iniciales, menores de 30, con pareja teórica, exclusiones exclusivas de B, parejas admisibles; conciliación de cantidades.
2. `cohortes_parejas_B.csv`: edad/sexo del activo, tamaño inicial, delta, edad/sexo del cónyuge, indicador de pareja, indicador admisible y motivo de exclusión.
3. `probabilidades_B.csv`: una fila por cohorte admisible y año 1–5, edades actualizadas, q de ambas vidas, supervivencias individuales, tres probabilidades de estatus y factor de descuento.
4. `vp_cohortes_B.csv`: VP unitario por cohorte y por estatus, cantidad inicial y VP agregado por cohorte.
5. `resumen_vp_B.csv`: exactamente tres VP agregados, con etiquetas, unidad, horizonte y supuestos.
6. El flujo utiliza los resultados de A/C como insumos definitivos y no genera archivos de auditoría.

Conservar el detalle completo en los CSV. En el PDF, incluir en el anexo B únicamente cuadros resumen de población, parejas por bandas y sexo, probabilidades anuales ponderadas y VP agregados y por sexo. El cuerpo desarrolla la metodología y la interpretación. **Exportar mediante el programa; no editar cifras a mano**.

### 3.6 Verificaciones obligatorias

- `N0 = N_menor_30 + N_con_pareja_teorica` (antes de exclusiones B).
- `N_con_pareja_teorica = N_pareja_admisible + N_exclusiones_B` (sin contar dos veces).
- `0 <= q <= 1`, por edad/sexo; revisar valores ausentes; edades avanzan +1 por año.
- Para todo `t`: `0<=S_x(t),S_y(t)<=1`, y `S_x(t)` y `S_y(t)` no aumentan al transcurrir los años.
- `0 <= P_ambos <= min(S_x,S_y)`.
- `max(S_x,S_y) <= P_al_menos_uno <= 1`.
- `0 <= P_conyuge_vivo_activo_fallecido <= S_y`.
- Identidad: `P_al_menos_uno = P_ambos + S_x(1-S_y) + S_y(1-S_x)`.
- `VP_al_menos_uno >= VP_ambos` y `VP_al_menos_uno >= VP_conyuge_vivo_activo_fallecido`, por cohorte y cartera.
- Cada VP unitario está entre `0` y `Σ_{t=1}^{5}(1.04)^(-t)`.
- Igualdad numérica de la agregación por cohortes y, en muestra pequeña, cálculo manual/independiente por registro; utilizar tolerancia numérica documentada (por ejemplo `1e-10` para probabilidades y tolerancia relativa para sumas grandes).
- Confirmar que cambiar el parámetro de renuncia **no altera B**.
- Confirmar que la salida B no modifica `N0` ni las proyecciones de A/C.

**Criterio de cierre B:** código ejecutable, tres VP reproducibles, conciliación de personas, tablas por cohorte/edad/sexo, exclusiones justificadas, pruebas aprobadas, interpretación actuarial clara.

## 4. Sección F: interpretación conceptual de NIIF 17

### 4.1 Qué se necesita del integrante 3

Extraer de **salidas reales** (sin recalcular C): prima anual por vigente `50 000`, comisión `5 %`, gasto anual base `10 000`, beneficio de fallecimiento `5 000 000`, adquisición inicial `75 000` por contrato, reserva suministrada por cierre `0, 40 000, 35 000, 25 000, 15 000, 0`, NPV final de C, margen de C, proyección de flujos y, si se usa en el argumento, recursos/deficiencia frente a reserva de D. Los valores del enunciado son supuestos; **NPV, margen, saldos y déficit deben venir del código del integrante 3**. Revisa si se registró el costo de adquisición una única vez al inicio y si las reservas no se tratan como efectivo.

### 4.2 Estructura de la página F (responder las cuatro preguntas)

**Pregunta 1: flujos iniciales y RA.** Explicar que la medición introductoria de NIIF 17 considera los flujos de cumplimiento dentro de límites contractuales relevantes: primas esperadas, prestaciones por fallecimiento, gastos directamente atribuibles, comisiones y flujos de adquisición pertinentes, con el valor temporal del dinero y supuestos biométricos/financieros adecuados. El **ajuste por riesgo no financiero (RA)** expresa la compensación requerida por asumir incertidumbre no financiera, como fallecimientos, renuncias y gastos; no es el gasto mismo ni una reserva de caja. Relacionarlo con `C`, `b`, `e`, `α`, `k` del proyecto sin intentar cuantificar RA.

**Pregunta 2: CSM.** La **margen de servicio contractual (CSM)** representa utilidad no devengada que se reconoce según se prestan servicios de seguro. En un grupo rentable, el beneficio inicial pertinente no se reconoce simplemente como ganancia inmediata: se incorpora al mecanismo de CSM conforme al modelo aplicable. En un grupo oneroso se reconoce la pérdida inicial y no se compensa con una CSM positiva de ese grupo. No inferir la clasificación del grupo únicamente a partir del NPV del ejercicio.

**Pregunta 3: NPV positivo ≠ CSM positiva.** Un NPV de profit testing evalúa rentabilidad bajo convenciones específicas del ejercicio: rentabilidad del 5 %, descuento del 4 %, reserva académica fija y adquisición inicial. NIIF 17 persigue medición contable de grupos de contratos con flujos de cumplimiento, descuento y RA, agrupación y criterios de reconocimiento propios. Por ello un NPV positivo **no demuestra** por sí solo la existencia o cuantía de CSM positiva. Si el NPV del equipo es negativo, adaptar redacción y explicar igualmente la falta de equivalencia; no fabricar un signo positivo.

**Pregunta 4: CSM vs reserva vs efectivo.** CSM: ganancia futura no devengada bajo NIIF 17. Reserva académica suministrada `V_t=v_t N_t`: importe fijo por vigente para profit testing (no se ha calibrado ni equivale automáticamente al pasivo contable NIIF 17). Efectivo `F_t`: recursos líquidos disponibles tras flujos y aportes para pagar obligaciones; una reserva contable no es entrada de caja, liberar reserva no equivale a cobrar efectivo y un aporte no es utilidad. Si se menciona `F̃_1−V_1`, usar la cifra real y explicar su carácter ilustrativo, no de solvencia regulatoria.

### 4.3 Restricciones de F

- **Máximo una página** completa dentro del informe de máximo diez páginas.
- **No calcular** FCF, RA ni CSM; **no** desarrollar asientos contables.
- **No** repetir las cuatro respuestas por escenario base/adverso; F se hace una sola vez.
- Evitar definiciones aisladas: referir al menos una o dos cifras **verificadas** del seguro C en el texto final, si están disponibles.
- No afirmar que reserva académica equivale a pasivo NIIF 17, que NPV es CSM, ni que capital/aporte es utilidad.
- Evitar trasladar cifras o rentas unitarias de B a C/F; varias vidas es una valoración académica separada.

**Criterio de cierre F:** las cuatro preguntas respondidas, texto técnico y coherente con C, una página máxima, ninguna cuantificación prohibida, NIIF 17 correctamente diferenciada de reservas y efectivo.

## 5. Integración al informe compartido

1. Trabajar en una rama propia o copia de seguridad del `.tex`; verificar `git diff` antes de terminar.
2. Insertar B tras A y F en el lugar previsto sin rehacer C/D/E ni cambiar resultados de compañeros.
3. Usar la notación existente, uniformar `x`, `y`, `s`, `t`, `q`, `S`, `VP` y tasa de descuento del 4 %, y explicar todas las unidades.
4. En B: fórmula principal e interpretación de último sobreviviente frente a reversión. En el anexo B, incluir únicamente los cuadros resumen, sin las tablas completas por cohorte y año. Conservar el detalle en los CSV.
5. En F: cuatro párrafos numerados o subtítulos breves, una página como máximo; citar datos auténticos de C.
6. Integrar tablas/figuras generadas por scripts mediante rutas relativas; no copiarlas a mano.
7. Respetar el **máximo de diez páginas de contenido**, página adicional de contribuciones individuales y anexos fuera del límite. No eliminar evidencia sustantiva para forzar paginación.
8. Registrar la contribución en varias vidas y NIIF 17: funciones/scripts, tres VP y validaciones; redacción F; uso de IA y verificación.
9. Compilar usando el comando ya utilizado en el repositorio; comprobar errores y referencias; revisar visualmente el PDF final (tablas sin desbordes, fórmulas legibles y página F dentro del límite).
10. Registrar comandos para repetir cálculo y compilación; incluir listado de archivos modificados y `git diff` resumido.

## 6. Propuesta de estructura de código (adaptar, no imponer)

```text
repo/
  [código de integrante 1 y 3 existente]
  R/
    5_varias_vidas.R
  resultados/
    varias_vidas/
      resumen_parejas_B.csv
      cohortes_parejas_B.csv
      probabilidades_B.csv
      vp_cohortes_B.csv
      resumen_vp_B.csv
  informe/
    [informe principal existente]
    [secciones B y F en la ubicación ya utilizada]
  GUIA_FLUJO_VARIAS_VIDAS_B_F_CODEX.md
```

Funciones sugeridas: `cargar_cohortes_y_qx()`, `asignar_pareja()`, `validar_admisibilidad_B()`, `calcular_supervivencias()`, `calcular_estatus()`, `valorar_rentas()`, `agregar_por_cohorte()`, `validar_resultados_B()`, `exportar_tablas_B()`. Reutilizar utilidades ya implementadas por otros integrantes si son correctas y evita introducir una segunda definición inconsistente de sexo/edad/mortalidad.

## 7. Plan de ejecución concreto con Codex

**Paso 1 — Reconocimiento:** pedir a Codex que identifique archivos reales, datos depurados, scripts A/C, resultados C, `.tex` y comandos, y que explique el plan antes de modificar nada. Si falta un insumo imprescindible, anotar la ausencia y buscarlo en las rutas accesibles, sin suponer resultados.

**Paso 2 — Modelo B:** implementar asignación de parejas, validación de admisibilidad, supervivencia biológica, tres estatus, cinco rentas temporales por cohorte y agregación inicial. Ejecutar pruebas antes de redactar interpretación.

**Paso 3 — Exportación B:** generar CSV, controles y tabla compacta del informe. Reportar conteos de exclusiones B y tres VP finales con unidades y criterios.

**Paso 4 — Contexto C para F:** leer resultados base definitivos y comprobar su significado; extraer las cifras efectivamente verificadas del informe.

**Paso 5 — Redactar F:** producir texto de máximo una página con cuatro respuestas ligadas a C; no calcular FCF/RA/CSM ni asientos.

**Paso 6 — Integración:** editar solo archivos de tu propiedad/secciones B/F, compilar, revisar longitud y pruebas, entregar lista de modificaciones y comandos de ejecución.

**Paso 7 — Revisión de estilo:** opcionalmente usar `$humanizer` **solo al final** sobre prosa de B/F, manteniendo ecuaciones, cifras y referencias. No usarlo para disimular errores o sustituir revisión propia. Dejar declarada la asistencia de IA según pide el proyecto.

## 8. Instrucción maestra lista para pegar en Codex

> Actúa como asistente técnico actuarial para el bloque de varias vidas y NIIF 17 del proyecto CA-0309, grupo 5, UCR. Lee `GUIA_FLUJO_VARIAS_VIDAS_B_F_CODEX.md` y `CA0309_Grupo5_Instrucciones_Revisadas.pdf`, priorizando B, F y convenciones. Inspecciona el repositorio antes de modificarlo: localiza base depurada y cohortes del integrante 1, mortalidad CR2023, código y salidas de profit testing del integrante 3, informe LaTeX y comandos de ejecución. Mantén intactas las secciones A/C/D/E y sus cifras. Implementa exclusivamente B: parejas hipotéticas por reglas de edad/sexo, exclusiones B separadas, supervivencia **solo biológica**, tres estatus al cierre, VP de rentas temporales unitarias pagaderas al final de cada año con tasa 4 %, agregación con cantidades **iniciales** y todas las pruebas de coherencia. Exporta automáticamente los resúmenes y tablas detalladas. Después redacta F en máximo una página, contestando sus cuatro preguntas y enlazándolas con los resultados **reales** de C, sin calcular FCF, RA, CSM ni asientos. Integra ambas secciones en el informe existente, preserva notación, verifica longitud y compilación, reporta cifras finales, comandos y archivos modificados. Si falta algún insumo esencial, informa exactamente cuál y evita inventar números. Haz el trabajo en esta sesión y no propongas reconstruir las secciones ya terminadas.

## 9. Lista de aceptación final

- [ ] Se reutiliza la población depurada de A con `N0` conciliado.
- [ ] Se clasifican menores de 30, parejas teóricas y exclusiones B sin doble conteo.
- [ ] Se aplica `delta=0/3/5` y sexo opuesto correctamente.
- [ ] Se rechaza `y>106` y cualquier cohorte con `q` faltante hasta el año 5, sin extrapolar.
- [ ] Los cinco años utilizan edades que avanzan de `x,y` a `x+4,y+4`.
- [ ] B usa solo mortalidad biológica, no renuncia ni población anual de A.
- [ ] Se obtienen y documentan los tres VP separados con descuento de 4 %.
- [ ] Las tablas por edad, sexo y año se exportan desde código.
- [ ] Las verificaciones de probabilidad, descomposición y conciliación aprueban.
- [ ] La sección B interpreta último sobreviviente vs cónyuge sobreviviente.
- [ ] F responde cuatro preguntas, se vincula a C y ocupa máximo una página.
- [ ] No se calculan FCF, RA o CSM, ni se confunden con NPV/reserva/efectivo.
- [ ] Informe completo dentro de diez páginas, contribuciones/anexos correctamente separados.
- [ ] Código y compilación reproducibles, sin alterar resultados ajenos.
- [ ] Uso de IA y comprobaciones declarados.
