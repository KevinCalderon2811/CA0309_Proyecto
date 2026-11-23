library(tidyverse)
library(writexl)
library(here)

# Seccion D: escenario adverso con gasto anual de 11 000 por vigente y rendimiento del 4 %.
# Reutiliza las funciones, parametros y la proyeccion de A cargados en 3_profit_testing.R.
# Se mantienen el descuento del 4 % y el cuadro de reservas.
source(here("R", "3_profit_testing.R"))

e_adverso <- 11000
i_adverso <- 0.04

flujos_adverso <- profit_test(poblacion, e_adverso, i_adverso)
recursos_adverso <- proyectar_recursos(flujos_adverso, i_adverso)
indicadores_adverso <- indicadores(flujos_adverso, recursos_adverso)

# la demografia no cambia, entonces las reservas totales son las mismas del caso base
all.equal(flujos_base$reserva_final, flujos_adverso$reserva_final)


# cuadro base/adverso con los indicadores pedidos en D
comparacion_D <- bind_rows(
    indicadores_base %>% mutate(escenario = "Base"),
    indicadores_adverso %>% mutate(escenario = "Adverso")
) %>%
    select(escenario, npv, margen, saldo_minimo, anio_saldo_minimo,
           total_aportes, recursos_menos_reserva_1)

comparacion_D


# resultados y recursos anio por anio en ambos escenarios
comparacion_anual <- tibble(
    anio = 1:5,
    resultado_base = flujos_base$resultado,
    resultado_adverso = flujos_adverso$resultado,
    saldo_base = recursos_base$saldo_antes_aporte,
    saldo_adverso = recursos_adverso$saldo_antes_aporte,
    aporte_base = recursos_base$aporte,
    aporte_adverso = recursos_adverso$aporte,
    reserva_final = flujos_base$reserva_final
)

comparacion_anual


# grafico: saldo de cierre antes del aporte contra la reserva total, en millones
datos_grafico <- bind_rows(
    tibble(anio = 1:5, serie = "Recursos base", monto = recursos_base$saldo_antes_aporte),
    tibble(anio = 1:5, serie = "Recursos adverso", monto = recursos_adverso$saldo_antes_aporte),
    tibble(anio = 1:5, serie = "Reserva total", monto = flujos_base$reserva_final)
) %>%
    mutate(monto = monto / 1e6)

grafico <- ggplot(datos_grafico, aes(x = anio, y = monto, color = serie, linetype = serie)) +
    geom_hline(yintercept = 0, color = "grey60") +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    scale_color_manual(values = c("Recursos base" = "#283F3B",
                                  "Recursos adverso" = "#95BF74",
                                  "Reserva total" = "grey45")) +
    scale_linetype_manual(values = c("Recursos base" = "solid",
                                     "Recursos adverso" = "solid",
                                     "Reserva total" = "dashed")) +
    labs(x = "Año", y = "Millones de unidades monetarias", color = NULL, linetype = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")

dir.create(here("figuras"), showWarnings = FALSE)
ggsave(here("figuras", "recursos_vs_reserva.pdf"), grafico, width = 6.5, height = 3.6)


write_xlsx(
    list(
        Comparacion = comparacion_D,
        Comparacion_Anual = comparacion_anual,
        Flujos_Adverso = flujos_adverso,
        Recursos_Adverso = recursos_adverso
    ),
    here("datos", "procesados", "Resultados D.xlsx")
)
