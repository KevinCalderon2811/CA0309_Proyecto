library(tidyverse)
library(readxl)
library(here)


activos <- read_excel(here("datos", "procesados", "Población CA-0309.xlsx"), sheet = "Activos")
mortalidad <- read_csv(here("datos", "originales", "CA0309_Mortalidad_CR2023.csv"),show_col_types = FALSE)

# Ahora, de acuerdo al enunciado, se agrupa por edad y sexo para obtener las cohortes:
cohortes <- activos %>% 
  count(`Años Cumplidos`, Genero, name = "cantidad") %>%
    rename(edad = `Años Cumplidos`, genero = Genero)

# Con esto verificamos que esten los N0 activos:
sum(cohortes$cantidad)

#NOTA: Revisar que en la base de activos existe 1 masculino con 1 año y una femenina con 4 años.
activos %>%
  filter(`Años Cumplidos` < 5) %>%
  select(`Id Asociado`, `Fecha Nacimiento`,
         `Años Cumplidos`, Genero)

mortalidad <- mortalidad %>%
  # Pasamos las columnas de qx por genero, a filas:
  pivot_longer(cols = c(qx_masculino, qx_femenino), names_to = "genero", values_to = "qx") %>%
  mutate(
    genero = genero %>%
      # La columna de genero ahora tendria masculino o femenino. Entonces quitamos el qx_ y ponemos los generos en mayusculass.
      str_remove("qx_") %>%
      str_to_upper()
  )

# Añadimos la columna de la probabilidad de muerte qx, mediante left join. Donde coincida en edad y genero, 
# se le asocia su respectivo qx:
cohortes <- cohortes %>%
  left_join(mortalidad, by = c("edad", "genero"))

r <- 0.03  # Probabilidad anual de renuncia

# Añadimos las fuerzas de mortalidad bajo el supuesto de que las mismas son constantes. Además, asumimos que c
# Aqui, defina j=1 muerte, j= 2 renuncia, τ= todas las causas:
cohortes <- cohortes %>%
  mutate(
    mu_1 = -log(1 - qx),
    mu_2 = -log(1 - r),
    mu_τ = mu_1 + mu_2
  )

#Aniadimos asi la probabilidad de permanencia total, la de salida por las dos causas, y la verificacion de que 
# las 3 probabilidades suman 1:
cohortes <- cohortes %>%
  mutate(
    p_τ = exp(-mu_τ),
    q_1 = ((mu_1 / mu_τ) * (1 - p_τ)),
    q_2 = ((mu_2 / mu_τ) * (1 - p_τ)),
    suma = p_τ + q_1 + q_2
  )



# Cambiamos para efectos del calculo de las proyecciones, las columnas de edad y genero:
poblacion <- cohortes %>%
  transmute(
    edad_inicial = edad,
    genero,
    l_x = as.numeric(cantidad)
  )
resultados <- vector("list", 5)

# Para cada cohorte de edad, calculamos la tabla de vida proyectada del año 1 al 5:
for (t in 1:5) {
 
  poblacion <- poblacion %>%
    mutate(
      anio = t,
      edad = edad_inicial + t - 1
    ) %>%
    left_join(mortalidad, by = c("edad", "genero"))

  poblacion <- poblacion %>%
    mutate(
      mu_1 = -log(1 - qx),
      mu_2 = -log(1 - r),
      mu_τ = mu_1 + mu_2,

      p_τ = exp(-mu_τ),
      q_1 = (mu_1 / mu_τ) * (1 - p_τ),
      q_2 = (mu_2 / mu_τ) * (1 - p_τ),

      d_1 = l_x * q_1,
      d_2 = l_x * q_2,

      l_x1 = l_x - d_1 - d_2
    )

  # Guardamos las tablas de vida por cada anio, guardamos las cohortes, las probabilidades de salida
  # las salidas esperadas y los activos restantes esperados.
  resultados[[t]] <- poblacion %>%
    select(
      anio, edad_inicial, edad, genero,
      l_x, q_1, q_2, d_1, d_2, l_x1
    )

  # Activos finales pasan al siguiente año
  poblacion <- poblacion %>%
    transmute(
      edad_inicial,
      genero,
      l_x = l_x1
    )
}


# Finalmente, la tabla de vida se ordena asi:
# Por cada cohorte (Edad), se calculan las proyecciones de los 5 años.
# Este proceso se hace con cada cohorte primero para el genero femenino.
# Luego, se repite el proceso para los masculinos.
proyeccion <- bind_rows(resultados) %>%
  arrange(genero, edad_inicial, anio)



# Esta tabla resume las cohortes restantes, salidas totales y renuncias totales.
# se agregan dos columnas donde se acumulan las muertes y loss r
tabla_anual_decrementos_mult <- proyeccion %>%
  group_by(anio) %>%
  summarise(
    activos_iniciales = sum(l_x),
    fallecimientos = sum(d_1),
    renuncias = sum(d_2),
    activos_finales = sum(l_x1),
    .groups = "drop"
  ) %>%
  mutate(
    fallecimientos_acumulados = cumsum(fallecimientos),
    renuncias_acumuladas = cumsum(renuncias)
  )




# Hacemos las proyecciones mediante las matrices de transiciones:
multiestado <- proyeccion %>%
  # Agrupamos por edad inicial (Antes de descontar fallecidos y renuncias)
  group_by(edad_inicial, genero) %>%
    group_modify(~ {
        datos <- arrange(.x, anio)
         # Inicialmente, hay lx activos, 0 fallecidos y 0 renuncias:
        estado <- c(datos$l_x[1], 0, 0)
        resultados <- vector("list", 5)
        # Realizamos las proyecciones con la matriz de transicion:
        for (t in 1:5) {

            # Para el anio t, sea la matriz de transicion:
            P <- matrix(
            c(
            # el complemento de las probabilidades de salida corresponde a la
            # probabilidad de permanencia:
            1 - datos$q_1[t] - datos$q_2[t],
            datos$q_2[t], datos$q_1[t],
            # Como los estados son absorbentes,es 100% probable quedarse en fallecimiento o renuncia:
            0, 1, 0,
            0, 0, 1
            ),
            nrow = 3,
            byrow = TRUE
            )

            # Multiplicamos el vector de estado con las matrices de transicion P:
            nuevo_estado <- as.numeric(estado %*% P)
            resultados[[t]] <- tibble(
                anio = t,
                activos_finales = nuevo_estado[1],
                fallecimientos = nuevo_estado[3] - estado[3],
                renuncias = nuevo_estado[2] - estado[2],
                fallecimientos_acumulados = nuevo_estado[3],
                renuncias_acumuladas = nuevo_estado[2]
            )
        estado <- nuevo_estado
        }
    bind_rows(resultados)
    }) %>%
ungroup()


# Ressumimos los resultados obtenidos mediante el modelo multiestado con las matrices de transicion:
tabla_anual_multiestado <- multiestado %>%
  group_by(anio) %>%
  summarise(
    activos_finales = sum(activos_finales),
    fallecimientos = sum(fallecimientos),
    renuncias = sum(renuncias),
    fallecimientos_acumulados = sum(fallecimientos_acumulados),
    renuncias_acumuladas = sum(renuncias_acumuladas),
    .groups = "drop"
  )

# Finalmente, comparamos el modelo de decrementos multiples con el multiestado de la siguiente forma:
# | variable decremento | variable multiestado|
comparacion <- tabla_anual_decrementos_mult %>%
  left_join(
    tabla_anual_multiestado,
    by = "anio",
    suffix = c("_decr_mult", "_multiestado")
  ) %>%
  transmute(
    anio,
    activos_decr_mult = activos_finales_decr_mult,
    activos_multiestado = activos_finales_multiestado,
    diferencia_activos = activos_decr_mult -activos_multiestado,
    fallecimientos_decr_mult,
    fallecimientos_multiestado,
    diferencia_fallecidos = fallecimientos_decr_mult - fallecimientos_multiestado,
    renuncias_decr_mult,
    renuncias_multiestado,
    diferencia_renuncias = renuncias_decr_mult - renuncias_multiestado)

# Al observar las columnas de las diferencias, se concluye que ambos modelos reproducen los mismos resultados.
writexl::write_xlsx(
  list(
    Cohortes = cohortes,
    Proyeccion = proyeccion,
    Tabla_Anual = tabla_anual_decrementos_mult,
    Multiestado = tabla_anual_multiestado,
    Comparacion = comparacion
  ),
  here("datos", "procesados", "Resultados A.xlsx")
)