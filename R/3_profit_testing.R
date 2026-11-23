library(tidyverse)
library(readxl)
library(writexl)
library(here)

# Seccion C: flujos, reservas suministradas y profit testing del seguro colectivo.
# Usa la proyeccion demografica de A (correr antes 2_mortalidad.R).

# parametros del producto (seccion 1 del enunciado)
C <- 50000          # prima anual por contrato
b <- 5000000        # beneficio por muerte
e <- 10000          # gasto anual por contrato vigente
alfa <- 0.05        # comision sobre la prima
k <- 75000          # gasto de adquisicion por contrato, una sola vez
i <- 0.05           # rendimiento anual
d <- 0.04           # descuento anual efectivo
recursos_iniciales <- 100000   # recursos por contrato antes de la adquisicion

# reserva por contrato vigente al cierre de los anios 1 a 5 (cuadro suministrado)
v <- c(40000, 35000, 25000, 15000, 0)

poblacion <- read_excel(here("datos", "procesados", "Resultados A.xlsx"), sheet = "Tabla_Anual")
N0 <- poblacion$activos_iniciales[1]


# Tabla anual de flujos, reservas y resultado del profit testing.
# Prima, gasto y comision al inicio del anio con los activos al cierre anterior;
# beneficios y reserva final al cierre.
profit_test <- function(poblacion, e, i) {
    poblacion %>%
        transmute(
            anio,
            activos_inicio = activos_iniciales,
            fallecimientos,
            activos_cierre = activos_finales,

            primas = C * activos_inicio,
            gastos = e * activos_inicio,
            comisiones = alfa * primas,
            flujo_inicio = primas - gastos - comisiones,
            beneficios = b * fallecimientos,

            # v_0 = 0 antes de emision, despues la reserva del cierre anterior
            reserva_inicial = c(0, v[1:4]) * activos_inicio,
            reserva_final = v * activos_cierre,

            rendimiento = i * (reserva_inicial + flujo_inicio),
            resultado = reserva_inicial + flujo_inicio + rendimiento - beneficios - reserva_final,

            # resultado de efectivo del anio: mismos flujos, sin mover reservas
            resultado_efectivo = flujo_inicio * (1 + i) - beneficios,

            resultado_descontado = resultado * (1 + d)^(-anio),
            primas_descontadas = primas * (1 + d)^(-(anio - 1))
        )
}


# Recursos: saldo anterior mas flujos de inicio, con rendimiento, menos beneficios.
# Si el saldo de cierre queda negativo, el aporte cubre exactamente el deficit.
proyectar_recursos <- function(flujos, i) {
    saldo <- (recursos_iniciales - k) * N0
    filas <- vector("list", 5)

    for (t in 1:5) {
        saldo_antes_aporte <- (saldo + flujos$flujo_inicio[t]) * (1 + i) - flujos$beneficios[t]

        aporte <- 0
        if (saldo_antes_aporte < 0) {
            aporte <- -saldo_antes_aporte
        }

        filas[[t]] <- tibble(
            anio = t,
            saldo_inicial = saldo,
            flujo_inicio = flujos$flujo_inicio[t],
            rendimiento = i * (saldo + flujos$flujo_inicio[t]),
            beneficios = flujos$beneficios[t],
            saldo_antes_aporte = saldo_antes_aporte,
            aporte = aporte,
            saldo_despues_aporte = saldo_antes_aporte + aporte,
            reserva_final = flujos$reserva_final[t],
            recursos_menos_reserva = saldo_antes_aporte - flujos$reserva_final[t]
        )

        saldo <- saldo_antes_aporte + aporte
    }

    bind_rows(filas)
}


# Indicadores que se piden en C y en el cuadro comparativo de D
indicadores <- function(flujos, recursos) {
    vp_primas <- sum(flujos$primas_descontadas)
    npv <- -k * N0 + sum(flujos$resultado_descontado)

    tibble(
        adquisicion = k * N0,
        vp_resultados = sum(flujos$resultado_descontado),
        npv = npv,
        vp_primas = vp_primas,
        margen = npv / vp_primas,
        saldo_minimo = min(recursos$saldo_antes_aporte),
        anio_saldo_minimo = recursos$anio[which.min(recursos$saldo_antes_aporte)],
        total_aportes = sum(recursos$aporte),
        recursos_menos_reserva_1 = recursos$recursos_menos_reserva[1]
    )
}


flujos_base <- profit_test(poblacion, e, i)
recursos_base <- proyectar_recursos(flujos_base, i)
indicadores_base <- indicadores(flujos_base, recursos_base)

flujos_base
recursos_base
indicadores_base


# comprobaciones
# la reserva inicial de cada anio es la final del anterior
all.equal(flujos_base$reserva_inicial[2:5], flujos_base$reserva_final[1:4])

# ningun anio empieza con saldo negativo despues del aporte
all(recursos_base$saldo_despues_aporte >= 0)


# detalle del anio 2, que tiene reserva inicial y final distintas de cero
flujos_base %>%
    filter(anio == 2) %>%
    select(primas, gastos, comisiones, flujo_inicio, reserva_inicial,
           rendimiento, beneficios, reserva_final, resultado) %>%
    pivot_longer(everything(), names_to = "concepto", values_to = "monto")


write_xlsx(
    list(
        Flujos_Resultados = flujos_base,
        Recursos_Aportes = recursos_base,
        Indicadores = indicadores_base
    ),
    here("datos", "procesados", "Resultados C.xlsx")
)
