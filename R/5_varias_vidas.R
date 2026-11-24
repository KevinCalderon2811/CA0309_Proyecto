# Seccion B: parejas hipoteticas y rentas de varias vidas a cinco anios.

# Aqui usamos las cohortes de A. Al final tomamos las cifras de C para el texto de F.

# Si lo corremos desde la terminal, ubicamos la raiz a partir de este archivo
# Si lo abrimos desde RStudio, usamos el directorio de trabajo que ya tenemos
args <- commandArgs(trailingOnly = FALSE)
if (.Platform$OS.type == "windows") {
  # Esto permite leer los nombres y escribir las tablas con tildes en Windows.
  invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
}
script_arg <- grep("^--file=", args, value = TRUE)
if (length(script_arg)) {
  raiz <- dirname(dirname(normalizePath(sub("^--file=", "", script_arg[1]))))
} else {
  raiz <- getwd()
}

# Primero ubicamos las bibliotecas donde R puede tener instalado readxl.
# Esta parte solo prepara la lectura; no interviene en los calculos 
configurar_bibliotecas <- function(raiz) {
  candidatas <- file.path(raiz, ".R-library")
  if (.Platform$OS.type == "windows") {
    version <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1], sep = ".")
    candidatas <- c(candidatas,
      file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", version),
      file.path(Sys.getenv("USERPROFILE"), "AppData", "Local", "R", "win-library", version))
  }
  .libPaths(unique(c(candidatas[dir.exists(candidatas)], .libPaths())))
}

# Normalmente guardamos todo en resultados/varias_vidas.
# La opcion --salida= permite elegir otra carpeta al ejecutar desde la terminal.
carpeta_salida <- function(raiz) {
  argumento <- grep("^--salida=", commandArgs(trailingOnly = TRUE), value = TRUE)
  if (!length(argumento)) return(file.path(raiz, "resultados", "varias_vidas"))
  ruta <- sub("^--salida=", "", argumento[1])
  if (!grepl("^([A-Za-z]:|/|\\\\)", ruta)) ruta <- file.path(raiz, ruta)
  ruta
}

leer_hoja <- function(raiz, archivo, hoja) {
  ruta <- file.path(raiz, archivo)
  if (!file.exists(ruta)) stop("Falta el insumo existente: ", archivo)
  as.data.frame(readxl::read_excel(ruta, sheet = hoja))
}

# No volvemos a depurar ni a proyectar A o C: leemos sus resultados entregados.
cargar_insumos <- function(raiz) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop('Falta readxl. Instalarlo con install.packages("readxl") antes de continuar.')
  }

  cohortes <- leer_hoja(raiz, "datos/procesados/Resultados A.xlsx", "Cohortes")
  cohortes <- cohortes[c("edad", "genero", "cantidad")]
  cohortes <- cohortes[order(cohortes$edad, cohortes$genero), ]
  rownames(cohortes) <- NULL
  list(cohortes = cohortes,
       mortalidad = read.csv(file.path(raiz, "datos/originales/CA0309_Mortalidad_CR2023.csv")),
       indicadores_C = leer_hoja(raiz, "datos/procesados/Resultados C.xlsx", "Indicadores"),
       flujos_C = leer_hoja(raiz, "datos/procesados/Resultados C.xlsx", "Flujos_Resultados"),
       recursos_C = leer_hoja(raiz, "datos/procesados/Resultados C.xlsx", "Recursos_Aportes"))
}

configurar_bibliotecas(raiz)
insumos <- cargar_insumos(raiz)
salida <- carpeta_salida(raiz)
dir.create(salida, recursive = TRUE, showWarnings = FALSE)
options(digits = 17)  # Conservamos la precision; redondeamos solo para el informe.

# De A solo necesitamos edad, sexo y cantidad inicial de cada cohorte.
cohortes <- insumos$cohortes
mortalidad <- insumos$mortalidad
tasas_mortalidad <- as.matrix(mortalidad[c("qx_masculino", "qx_femenino")])

# Para poder usar la tabla, cada edad debe tener probabilidades entre 0 y 1.
stopifnot(!anyDuplicated(mortalidad$edad), !anyDuplicated(cohortes[c("edad", "genero")]),
          all(cohortes$cantidad > 0), all(cohortes$cantidad == as.integer(cohortes$cantidad)),
          all(cohortes$genero %in% c("MASCULINO", "FEMENINO")),
          all(is.finite(tasas_mortalidad)),
          all(tasas_mortalidad >= 0), all(tasas_mortalidad <= 1))

# Con match buscamos los q de las edades solicitadas y del sexo correspondiente.
# Si una edad no esta en el CSV, devuelve NA
qx <- function(edades, sexo, tabla = mortalidad) {
  columna <- if (sexo == "MASCULINO") "qx_masculino" else "qx_femenino"
  tabla[[columna]][match(edades, tabla$edad)]
}

asignar_parejas <- function(datos, tabla = mortalidad) {
  parejas <- datos
  names(parejas)[names(parejas) == "edad"] <- "edad_inicial"
  names(parejas)[names(parejas) == "genero"] <- "sexo_activo"
  edad <- parejas$edad_inicial
  parejas$con_pareja <- edad >= 30

  # Ahora asignamos la diferencia de edad de acuerdo con las bandas del enunciado.
  # Los menores de 30 quedan sin pareja; por eso su delta se mantiene en NA.
  parejas$delta <- NA_integer_
  parejas$delta[edad >= 30 & edad < 35] <- 0L
  parejas$delta[edad >= 35 & edad < 55] <- 3L
  parejas$delta[edad >= 55] <- 5L

  # Si el activo es hombre, la pareja es menor o de igual edad; si es mujer, mayor o igual.
  # Por ejemplo: hombre de 45 -> mujer de 42; mujer de 45 -> hombre de 48.
  parejas$edad_conyuge <- ifelse(parejas$sexo_activo == "MASCULINO",
                                edad - parejas$delta, edad + parejas$delta)
  parejas$sexo_conyuge <- ifelse(parejas$sexo_activo == "MASCULINO", "FEMENINO", "MASCULINO")
  parejas$sexo_conyuge[!parejas$con_pareja] <- NA_character_

  # Revisamos que ambas vidas tengan los cinco q necesarios para B.
  # Una exclusion aqui no elimina al activo de los otros incisos.
  parejas$motivo <- "Admisible"
  for (j in seq_len(nrow(parejas))) {
    if (!parejas$con_pareja[j]) {
      parejas$motivo[j] <- "Sin pareja: menor de 30"
    } else if (parejas$edad_conyuge[j] > 106) {
      parejas$motivo[j] <- "Exclusion B: conyuge mayor de 106"
    } else {
      valores <- c(qx(edad[j] + 0:4, parejas$sexo_activo[j], tabla),
                   qx(parejas$edad_conyuge[j] + 0:4, parejas$sexo_conyuge[j], tabla))
      if (any(!is.finite(valores))) parejas$motivo[j] <- "Exclusion B: mortalidad faltante"
    }
  }
  parejas$admisible <- parejas$motivo == "Admisible"
  parejas
}

# Las parejas se asignan una sola vez. Durante la proyeccion solo avanzan las edades.
# El descuento del proyecto es 4 %;
calcular_B <- function(parejas, tabla = mortalidad, descuento = 0.04) {
  admisibles <- which(parejas$admisible)
  if (!length(admisibles)) stop("No hay parejas admisibles en B")
  filas <- vector("list", length(admisibles))

  # Recorremos cada cohorte admisible y guardamos sus cinco anios de proyeccion.
  for (j in seq_along(admisibles)) {
    cohorte <- parejas[admisibles[j], ]
    t <- 1:5
    q_act <- qx(cohorte$edad_inicial + t - 1, cohorte$sexo_activo, tabla)
    q_con <- qx(cohorte$edad_conyuge + t - 1, cohorte$sexo_conyuge, tabla)

    # cumprod multiplica las probabilidades anuales de seguir vivo hasta cada cierre.
    
    Sx <- cumprod(1 - q_act)
    Sy <- cumprod(1 - q_con)
    # Como se asume independencia entre las vidas, podemos combinar ambas supervivencias.
    J <- Sx * Sy                 # Ambos vivos.
    U <- Sx + Sy - J             # Al menos uno vivo, incluyendo ambos vivos.
    R <- Sy * (1 - Sx)           # Conyuge vivo y activo ya fallecido.
    # R tambien incluye fallecimientos de anios anteriores, si el conyuge sigue vivo.
    v <- (1 + descuento)^(-t)

    # Cada renta paga una unidad al cierre. Por eso descontamos desde el anio t.
    filas[[j]] <- data.frame(
      edad_inicial = cohorte$edad_inicial,
      sexo_activo = cohorte$sexo_activo,
      cantidad = cohorte$cantidad,
      edad_conyuge = cohorte$edad_conyuge,
      sexo_conyuge = cohorte$sexo_conyuge,
      anio = t,
      edad_activo_anio = cohorte$edad_inicial + t - 1,
      edad_conyuge_anio = cohorte$edad_conyuge + t - 1,
      q_activo = q_act, q_conyuge = q_con,
      S_activo = Sx, S_conyuge = Sy,
      p_ambos = J, p_al_menos_uno = U,
      p_conyuge_activo_fallecido = R,
      factor_descuento = v,
      vp_ambos = J * v, vp_al_menos_uno = U * v,
      vp_conyuge_activo_fallecido = R * v
    )
  }

  # Juntamos las cohortes y sumamos sus cinco pagos descontados con aggregate.
  prob <- do.call(rbind, filas)
  vp <- aggregate(prob[c("vp_ambos", "vp_al_menos_uno", "vp_conyuge_activo_fallecido")],
                  prob[c("edad_inicial", "sexo_activo", "cantidad", "edad_conyuge", "sexo_conyuge")], sum)
  vp <- vp[order(vp$edad_inicial, vp$sexo_activo), ]

  # Asi pasamos del VP por pareja al VP de toda la cohorte.
  # Usamos la cantidad inicial de A, sin volver a aplicar supervivencia ni renuncia.
  vp$vp_cartera_ambos <- vp$cantidad * vp$vp_ambos
  vp$vp_cartera_al_menos_uno <- vp$cantidad * vp$vp_al_menos_uno
  vp$vp_cartera_conyuge_activo_fallecido <- vp$cantidad * vp$vp_conyuge_activo_fallecido
  list(probabilidades = prob, vp_cohortes = vp)
}

parejas <- asignar_parejas(cohortes)
modelo <- calcular_B(parejas)
prob <- modelo$probabilidades
vp <- modelo$vp_cohortes

# Primero resumimos cuantos activos tienen pareja y cuantos pueden valorarse en B.
N0 <- sum(parejas$cantidad)
N_menores <- sum(parejas$cantidad[!parejas$con_pareja])
N_teoricas <- sum(parejas$cantidad[parejas$con_pareja])
N_admisibles <- sum(parejas$cantidad[parejas$admisible])
N_excluidas <- sum(parejas$cantidad[parejas$con_pareja & !parejas$admisible])
resumen_parejas <- data.frame(concepto = c("Activos iniciales A", "Sin pareja: menores de 30", "Con pareja teorica", "Exclusiones propias de B", "Parejas admisibles B"),
                              cantidad = c(N0, N_menores, N_teoricas, N_excluidas, N_admisibles))
# Son tres rentas alternativas. Sus VP se presentan por separado, no se suman.
resumen_vp <- data.frame(estatus = c("Ambos vivos", "Al menos uno vivo (ultimo sobreviviente)", "Conyuge vivo con activo fallecido"),
                         vp_agregado = colSums(vp[c("vp_cartera_ambos", "vp_cartera_al_menos_uno", "vp_cartera_conyuge_activo_fallecido")]),
                         unidad = "Unidades de renta descontadas", horizonte_anios = 5L, descuento = 0.04,
                         mortalidad = "Biologica sin renuncia", parejas_admisibles = N_admisibles)

# Guardamos el resumen y el detalle en CSV para poder consultarlos por separado.
# Los NA se dejan vacios; por ejemplo, la edad del conyuge de un menor de 30.
guardar <- function(datos, nombre) {
  write.csv(datos, file.path(salida, nombre), row.names = FALSE,
            fileEncoding = "UTF-8", na = "")
}
guardar(resumen_parejas, "resumen_parejas_B.csv")
guardar(parejas, "cohortes_parejas_B.csv")
guardar(prob, "probabilidades_B.csv")
guardar(vp, "vp_cohortes_B.csv")
guardar(resumen_vp, "resumen_vp_B.csv")
# Ahora separamos los VP por sexo del activo, usando las mismas cohortes calculadas.
sexos <- do.call(rbind, lapply(c("FEMENINO", "MASCULINO"), function(s) {
  z <- vp[vp$sexo_activo == s, ]
  data.frame(sexo_activo = s, parejas = sum(z$cantidad),
             vp_ambos = sum(z$vp_cartera_ambos), vp_al_menos_uno = sum(z$vp_cartera_al_menos_uno),
             vp_conyuge_activo_fallecido = sum(z$vp_cartera_conyuge_activo_fallecido))
}))
guardar(sexos, "resumen_sexo_B.csv")

# Para el anexo agrupamos las parejas en las mismas tres bandas de edad.
# Cada banda se muestra por sexo, con el rango de edades observado del conyuge.
bandas <- c("30 a 34", "35 a 54", "55 o mas")
limites <- list(c(30, 34), c(35, 54), c(55, Inf))
resumen_bandas <- do.call(rbind, lapply(seq_along(bandas), function(j) {
  do.call(rbind, lapply(c("FEMENINO", "MASCULINO"), function(s) {
    z <- parejas[parejas$con_pareja & parejas$sexo_activo == s &
                  parejas$edad_inicial >= limites[[j]][1] & parejas$edad_inicial <= limites[[j]][2], ]
    data.frame(banda = bandas[j], sexo_activo = s, delta = c(0, 3, 5)[j],
      edad_conyuge_min = if (nrow(z)) min(z$edad_conyuge) else NA_real_,
      edad_conyuge_max = if (nrow(z)) max(z$edad_conyuge) else NA_real_,
      parejas_teoricas = sum(z$cantidad), exclusiones_B = sum(z$cantidad[!z$admisible]),
      parejas_admisibles = sum(z$cantidad[z$admisible]))
  }))
}))
# La media anual debe dar mas peso a las cohortes que tienen mas parejas.
# Por eso multiplicamos cada probabilidad por su cantidad inicial y dividimos por el total.
resumen_probabilidades <- do.call(rbind, lapply(1:5, function(t) {
  z <- prob[prob$anio == t, ]
  n <- sum(z$cantidad)
  data.frame(anio = t, parejas_iniciales = n,
    p_media_ambos = sum(z$cantidad*z$p_ambos)/n,
    p_media_al_menos_uno = sum(z$cantidad*z$p_al_menos_uno)/n,
    p_media_conyuge_activo_fallecido = sum(z$cantidad*z$p_conyuge_activo_fallecido)/n)
}))
guardar(resumen_bandas, "resumen_bandas_B.csv")
guardar(resumen_probabilidades, "resumen_probabilidades_B.csv")

# Finalmente preparamos las tablas que lee main-3.tex.
# Esta parte solo cambia la presentacion: los CSV conservan la precision del calculo.
fmt <- function(x, digits = 2L) {
  s <- formatC(x, format="f", digits=digits, big.mark=" ", decimal.mark=",")
  gsub(" ", "\\,", s, fixed=TRUE)
}
# En LaTeX las columnas se separan con & y cada fila termina con dos barras.
fila <- function(...) paste0(paste(c(...), collapse=" & "), " \\\\")
writeLines(c("\\begin{tabular}{@{}lr@{}}", "\\toprule", fila("Concepto", "Cantidad"), "\\midrule",
             mapply(function(a,b) fila(a,fmt(b,0)), resumen_parejas$concepto, resumen_parejas$cantidad),
             "\\bottomrule", "\\end{tabular}"), file.path(salida,"resumen_parejas_B.tex"), useBytes=TRUE)
writeLines(c("\\begin{tabular}{@{}lr@{}}", "\\toprule", fila("Estatus de pago", "VP agregado"), "\\midrule",
             mapply(function(a,b) fila(a,fmt(b)), resumen_vp$estatus, resumen_vp$vp_agregado),
             "\\bottomrule", "\\end{tabular}"), file.path(salida,"resumen_vp_B.tex"), useBytes=TRUE)
# Estas cifras permiten que el texto del informe se actualice al correr el script.
macros <- c(NInicialB=N0, NMenoresB=N_menores, NParejasTeoricasB=N_teoricas, NExcluidasB=N_excluidas, NParejasB=N_admisibles,
            VPambosB=resumen_vp$vp_agregado[1], VPultimoB=resumen_vp$vp_agregado[2], VPreversionB=resumen_vp$vp_agregado[3],
            DiferenciaVPultimoB=resumen_vp$vp_agregado[2]-resumen_vp$vp_agregado[1],
            AumentoVPultimoB=100*(resumen_vp$vp_agregado[2]/resumen_vp$vp_agregado[1]-1),
            VPreversionHombresB=sexos$vp_conyuge_activo_fallecido[sexos$sexo_activo=="MASCULINO"],
            VPreversionMujeresB=sexos$vp_conyuge_activo_fallecido[sexos$sexo_activo=="FEMENINO"])
lineas_B <- vapply(names(macros), function(nombre) {
  # Las primeras cinco cifras son cantidades de personas o parejas, sin decimales.
  decimales <- if (nombre %in% names(macros)[1:5]) 0L else 2L
  paste0("\\newcommand{\\", nombre, "}{", fmt(macros[nombre], decimales), "}")
}, character(1))
writeLines(lineas_B, file.path(salida,"cifras_B.tex"), useBytes=TRUE)
# Para F solo leemos las cifras entregadas en C y las mostramos en millones.
# No calculamos RA, CSM ni nuevos resultados del seguro colectivo.
contexto <- insumos$indicadores_C
rec <- insumos$recursos_C
flujos <- insumos$flujos_C
macros_f <- c(NPVbaseF=contexto$npv/1e6, MargenbaseF=100*contexto$margen, RecursosUnoF=rec$saldo_antes_aporte[1]/1e6,
              ReservaUnoF=flujos$reserva_final[1]/1e6, BrechaUnoF=contexto$recursos_menos_reserva_1/1e6)
lineas_F <- vapply(names(macros_f), function(nombre) {
  paste0("\\newcommand{\\", nombre, "}{", fmt(macros_f[nombre]), "}")
}, character(1))
writeLines(lineas_F, file.path(salida,"cifras_F.tex"), useBytes=TRUE)

# El PDF lleva los cuadros resumen; las tablas largas quedan en los CSV.
sexo <- function(s) ifelse(s=="MASCULINO", "Hombre", "Mujer")
tabla_tex <- function(nombre, especificacion, encabezado, filas) {
  # Agregamos el encabezado y las lineas de la tabla para incluirla en el anexo.
  writeLines(c(paste0("\\begin{tabular}{@{}", especificacion, "@{}}"), "\\toprule",
               encabezado, "\\midrule", filas, "\\bottomrule", "\\end{tabular}"),
             file.path(salida, nombre), useBytes=TRUE)
}
filas_bandas <- vapply(seq_len(nrow(resumen_bandas)), function(i) {
  z <- resumen_bandas[i, ]
  edades <- if (is.na(z$edad_conyuge_min)) "--" else paste0(fmt(z$edad_conyuge_min,0), "--", fmt(z$edad_conyuge_max,0))
  fila(z$banda, sexo(z$sexo_activo), fmt(z$delta,0), edades, fmt(z$parejas_admisibles,0))
}, character(1))
tabla_tex("resumen_bandas_B.tex", "llrrr",
          fila("Edad inicial activo", "Sexo activo", "$\\delta$", "Edad pareja", "Parejas admisibles"), filas_bandas)
filas_prob <- vapply(seq_len(nrow(resumen_probabilidades)), function(i) {
  z <- resumen_probabilidades[i, ]
  porcentajes <- paste0(fmt(100*c(z$p_media_ambos,z$p_media_al_menos_uno,z$p_media_conyuge_activo_fallecido)), "\\%")
  fila(z$anio, porcentajes)
}, character(1))
tabla_tex("resumen_probabilidades_B.tex", "rrrr",
          fila("Año", "Ambos vivos", "Último sobreviviente", "Reversión"), filas_prob)
filas_sexo <- vapply(seq_len(nrow(sexos)), function(i) {
  z <- sexos[i, ]
  fila(sexo(z$sexo_activo), fmt(z$parejas,0), fmt(z$vp_ambos),fmt(z$vp_al_menos_uno),fmt(z$vp_conyuge_activo_fallecido))
}, character(1))
tabla_tex("resumen_sexo_B.tex", "lrrrr",
          fila("Sexo del activo", "Parejas", "VP ambos", "VP último", "VP reversión"), filas_sexo)

# Ahora comparamos los tres estatus con barras. Cada barra muestra el VP total
# y se divide por sexo del activo para ver cuanto aporta cada grupo.
# La renta del ejercicio paga una unidad: aqui la interpretamos como 1 u.m. anual.
graficar_vp <- function(resumen_sexo, archivo) {
  columnas <- c("vp_ambos", "vp_al_menos_uno", "vp_conyuge_activo_fallecido")
  montos <- as.matrix(resumen_sexo[columnas])
  totales <- colSums(montos)
  etiquetas <- c("Ambos vivos", "Al menos uno vivo", "Cónyuge vivo con\nactivo fallecido")
  colores <- c("#355F7D", "#B4C9D8")

  pdf(archivo, width=7.4, height=4.2, family="Helvetica", pointsize=11)
  on.exit(dev.off())
  par(mar=c(4.4, 6.2, 3.4, 0.7), col.axis="#344054", col.lab="#344054",
      mgp=c(4.7, 0.8, 0), tcl=-0.2, xaxs="i", yaxs="i")

  # Las barras parten de cero y comparten escala para comparar los importes.
  centros <- barplot(montos, names.arg=etiquetas, col=colores, border=NA,
                    space=0.45, xlim=c(0,4.8), ylim=c(0,max(totales)*1.30),
                    axes=FALSE, cex.names=0.9)
  marcas <- pretty(c(0, max(totales)), n=5)
  axis(2, at=marcas, labels=formatC(marcas, format="f", digits=0, big.mark=" "), las=1)
  abline(h=0, col="#667085", lwd=0.8)
  mtext("Valor presente esperado (u.m.)", side=2, line=5, cex=0.9)
  mtext("Valor actual de las obligaciones por estatus", side=3, line=1.8,
        adj=0, cex=1.1, font=2, col="#172B46")
  mtext("Al 31/12/2025; renta anual de 1 u.m.; cinco años; descuento del 4 %.",
        side=3, line=0.4, adj=0, cex=0.82, col="#475467")

  # Encima de cada barra mostramos la suma de los dos grupos, en unidades monetarias.
  text(centros, totales+max(totales)*0.035,
       labels=formatC(totales, format="f", digits=2, big.mark=" ", decimal.mark=","),
       cex=0.9, font=2, col="#172B46")
  legend("topright", title="Sexo del activo", legend=c("Mujeres", "Hombres"),
         fill=colores, border=NA, bty="n", cex=0.85, inset=c(0,0.01))
}

carpeta_figuras <- file.path(raiz, "figuras")
dir.create(carpeta_figuras, showWarnings=FALSE)
graficar_vp(sexos, file.path(carpeta_figuras, "vp_varias_vidas.pdf"))

print(resumen_parejas, row.names=FALSE)
print(resumen_vp, row.names=FALSE)
