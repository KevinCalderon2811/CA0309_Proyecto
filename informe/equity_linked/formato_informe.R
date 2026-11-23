# tablas y gráfico para el informe, a partir de los resultados del script
# redondeamos solo al armar las tablas de LaTeX
formato_tex <- function(x, decimales = 2L) {
  texto <- formatC(x, format = "f", digits = decimales, big.mark = " ", decimal.mark = ",")
  gsub(" ", "\\,", texto, fixed = TRUE)
}
fila_tex <- function(etiqueta, valores) {
  paste0(paste(c(etiqueta, valores), collapse = " & "), " \\\\")
}
encabezado_tex <- c(
  "\\begin{tabular}{@{}lrrr@{}}",
  "\\toprule",
  fila_tex("Garantía / cargo", paste0(formato_tex(casos$garantia, 0L), " / ",
                                     formato_tex(100 * casos$cargo_anual, 0L), "\\%")),
  "\\midrule"
)
cierre_tex <- c("\\bottomrule", "\\end{tabular}")
writeLines(c(
  encabezado_tex,
  fila_tex("VP medio de cargos", formato_tex(comparacion$vp_cargos_medio)),
  fila_tex("VP medio del complemento", formato_tex(comparacion$vp_complemento_medio)),
  fila_tex("NPV medio del proveedor", formato_tex(comparacion$npv_medio)),
  fila_tex("Frecuencia de pérdida", paste0(formato_tex(100 * comparacion$frecuencia_perdida, 1L), "\\%")),
  fila_tex("CTE95 del proveedor", formato_tex(comparacion$cte95)),
  fila_tex("Frecuencia de activación", paste0(formato_tex(100 * comparacion$frecuencia_activacion, 1L), "\\%")),
  fila_tex("Saldo final medio antes de la garantía", formato_tex(comparacion$saldo_final_medio)),
  cierre_tex
), file.path(salida, "comparacion.tex"))

trayectoria_1 <- trayectorias[trayectorias$trayectoria == 1, ]
writeLines(c(
  encabezado_tex,
  fila_tex("Saldo al cierre del año 5", formato_tex(trayectoria_1$saldo_final)),
  fila_tex("Complemento al vencimiento", formato_tex(trayectoria_1$complemento)),
  fila_tex("VP de cargos", formato_tex(trayectoria_1$vp_cargos)),
  fila_tex("VP del complemento", formato_tex(trayectoria_1$vp_complemento)),
  fila_tex("NPV del proveedor", formato_tex(trayectoria_1$npv)),
  cierre_tex
), file.path(salida, "trayectoria_1.tex"))

# en el anexo mostramos una proyección anual por tasa de cargo
detalle_anexo <- detalle[detalle$caso %in% c("E1", "G5"), ]
filas_detalle <- character(nrow(detalle_anexo))
for (i in seq_len(nrow(detalle_anexo))) {
  x <- detalle_anexo[i, ]
  tasa <- casos$cargo_anual[match(x$caso, casos$caso)]
  tasa_tex <- paste0(formato_tex(100 * tasa, 0L), "\\%")
  rendimiento_tex <- paste0(formato_tex(100 * x$rendimiento), "\\%")
  montos <- formato_tex(c(x$saldo_inicio, x$cargo, x$saldo_cierre, x$vp_cargo))
  filas_detalle[i] <- fila_tex(x$anio, c(tasa_tex, rendimiento_tex, montos))
}
writeLines(c(
  "\\begin{tabular}{@{}rrrrrrr@{}}",
  "\\toprule",
  fila_tex("Año", c("Tasa de cargo", "Rendimiento", "Saldo inicial", "Cargo", "Saldo final", "VP de cargo")),
  "\\midrule",
  filas_detalle,
  cierre_tex
), file.path(salida, "trayectoria_1_anual.tex"))

# los cortes y ejes son los mismos para que se puedan comparar los histogramas
graficar_npv <- function(ruta) {
  npv_miles <- trayectorias$npv / 1000
  rango <- range(npv_miles)
  cortes <- seq(2.5 * floor(rango[1] / 2.5), 2.5 * ceiling(rango[2] / 2.5), by = 2.5)
  histogramas <- list()
  max_frecuencia <- 0
  for (i in seq_len(nrow(casos))) {
    npv_caso <- npv_miles[trayectorias$caso == casos$caso[i]]
    histogramas[[i]] <- hist(npv_caso, breaks = cortes, plot = FALSE)
    max_frecuencia <- max(max_frecuencia, histogramas[[i]]$counts)
  }
  marcas_y <- pretty(c(0, max_frecuencia), n = 4)
  marcas_x <- pretty(range(cortes), n = 4)
  marcas_x <- marcas_x[marcas_x >= min(cortes) & marcas_x <= max(cortes)]
  etiquetas <- c("Garantía 100 000 | Cargo 2%", "Garantía 110 000 | Cargo 2%",
                 "Garantía 110 000 | Cargo 3%")

  pdf(ruta, width = 10, height = 4.4, pointsize = 11, bg = "white")
  on.exit(dev.off())
  par(mfrow = c(1, 3), mar = c(2.4, 3.1, 2.5, 0.8), oma = c(3.0, 2.0, 5.0, 1.1),
      col.axis = "#253247", col.main = "#172B46", col.lab = "#253247",
      xaxs = "i", yaxs = "i", tcl = -0.25, mgp = c(1.9, 0.55, 0))
  for (i in seq_along(histogramas)) {
    plot(histogramas[[i]], freq = TRUE, axes = FALSE, ann = FALSE,
         xlim = range(cortes), ylim = range(marcas_y), col = "#6789AE", border = "white")
    axis(1, at = marcas_x, col = "#657486")
    axis(2, at = marcas_y, las = 1, col = "#657486")
    abline(v = 0, lty = 2, lwd = 1.2, col = "#283141")
    title(main = etiquetas[i], cex.main = 0.96, font.main = 2)
  }
  mtext("NPV del proveedor por garantía y cargo", side = 3, outer = TRUE,
        adj = 0, line = 2.7, cex = 1.33, font = 2, col = "#172B46")
  mtext("1 000 trayectorias de cinco años por caso. La línea discontinua marca el NPV cero.",
        side = 3, outer = TRUE, adj = 0, line = 1.3, cex = 0.9, col = "#43556D")
  mtext("NPV (miles de u.m. por contrato emitido)", side = 1, outer = TRUE, line = 0.65)
  mtext("Número de trayectorias", side = 2, outer = TRUE, line = 0.1)
}

graficar_npv(file.path(salida, "histograma_npv.pdf"))
