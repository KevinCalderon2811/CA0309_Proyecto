library(tidyverse)
library(here)

mortalidad <- read_csv(here("datos", "originales", "CA0309_Mortalidad_CR2023.csv"),
                       show_col_types = FALSE) %>%
  filter(between(edad, 45, 49)) %>%
  arrange(edad)
stopifnot(nrow(mortalidad) == 5, all(mortalidad$edad == 45:49),
          all(mortalidad$qx_masculino >= 0 & mortalidad$qx_masculino < 1))

# al inicio de cada año usamos la permanencia del cierre anterior
descuento <- 0.04
permanencia <- mortalidad %>%
  mutate(renuncia = 0.03,
         prob_permanencia_anual = (1 - qx_masculino) * (1 - renuncia),
         permanencia_cierre = cumprod(prob_permanencia_anual)) %>%
  transmute(anio = 1:5, edad, qx_masculino, renuncia, prob_permanencia_anual,
            permanencia_inicio = lag(permanencia_cierre, default = 1),
            permanencia_cierre, peso_cargo = permanencia_inicio / (1 + descuento)^(anio - 1))
peso_complemento <- permanencia$permanencia_cierre[5] / (1 + descuento)^5

casos <- tibble(caso = c("E1", "E2", "G5"),
                garantia = c(100000, 110000, 110000),
                cargo_anual = c(0.02, 0.02, 0.03))

# guardamos los mismos rendimientos para comparar los tres casos
n <- 1000
set.seed(2026, kind = "Mersenne-Twister", normal.kind = "Inversion")
normales <- matrix(rnorm(n * 5), nrow = n, byrow = TRUE)
crecimiento <- exp(0.04 + 0.15 * normales)
trayectorias <- tibble()
detalle <- tibble()

for (i in 1:nrow(casos)) {
  cuenta <- tibble(trayectoria = 1:n, saldo = 100000, vp_cargos = 0)

  for (t in 1:5) {
    # cobramos primero y aplicamos el rendimiento al saldo que queda
    cuenta <- cuenta %>%
      mutate(saldo_inicio = saldo,
             cargo = casos$cargo_anual[i] * saldo_inicio,
             saldo_despues_cargo = saldo_inicio - cargo,
             saldo = saldo_despues_cargo * crecimiento[, t],
             vp_cargo = cargo * permanencia$peso_cargo[t],
             vp_cargos = vp_cargos + vp_cargo)

    primera <- cuenta %>%
      slice(1) %>%
      transmute(caso = casos$caso[i], trayectoria, anio = t, edad = permanencia$edad[t],
                normal = normales[1, t], rendimiento = crecimiento[1, t] - 1,
                saldo_inicio, cargo, saldo_despues_cargo, saldo_cierre = saldo, vp_cargo)
    detalle <- bind_rows(detalle, primera)
  }

  resultado <- cuenta %>%
    transmute(caso = casos$caso[i], trayectoria, saldo_final = saldo, vp_cargos,
              complemento = pmax(casos$garantia[i] - saldo, 0),
              vp_complemento = peso_complemento * complemento,
              npv = vp_cargos - vp_complemento, perdida = -npv)
  trayectorias <- bind_rows(trayectorias, resultado)
}

comparacion <- trayectorias %>%
  group_by(caso) %>%
  summarise(vp_cargos_medio = mean(vp_cargos),
            vp_complemento_medio = mean(vp_complemento), npv_medio = mean(npv),
            frecuencia_perdida = mean(npv < 0),
            cte95 = mean(sort(perdida, decreasing = TRUE)[1:50]),
            frecuencia_activacion = mean(complemento > 0), saldo_final_medio = mean(saldo_final))
comparacion <- left_join(casos, comparacion, by = "caso")

e1 <- trayectorias %>% filter(caso == "E1")
e2 <- trayectorias %>% filter(caso == "E2")
stopifnot(all(e2$complemento >= e1$complemento), all(e2$npv <= e1$npv))

salida <- here("resultados", "equity_linked")
dir.create(salida, recursive = TRUE, showWarnings = FALSE)
colnames(normales) <- paste0("z_", 1:5)
write.csv(comparacion, file.path(salida, "comparacion.csv"), row.names = FALSE)
write.csv(permanencia, file.path(salida, "permanencia.csv"), row.names = FALSE)
write.csv(data.frame(trayectoria = 1:n, normales), file.path(salida, "normales.csv"), row.names = FALSE)
write.csv(trayectorias, file.path(salida, "trayectorias.csv"), row.names = FALSE)
write.csv(detalle, file.path(salida, "trayectoria_1_por_anio.csv"), row.names = FALSE)

source(here("informe", "equity_linked", "formato_informe.R"), local = TRUE)
print(comparacion, width = Inf)
