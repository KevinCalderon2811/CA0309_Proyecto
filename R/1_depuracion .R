library(readxl)
library(here)
library(writexl)
library(tidyverse)



#Clave: ponerse en la carpeta raiz del proyecto para q funcione, hacer getdw() en la ruta de la raiz
# del proyecto y luego setdw() :)
fecha_corte <- as.Date("2025-12-31")

activos <- read_excel(here("datos", "originales", "Población CA-0309.xlsx"), sheet = "Activos",
range = cell_cols("A:G"), col_types = c("text", "date", "date", "date", "numeric", "text", "numeric"))

names(activos) <- c(
  "id_asociado", "fecha_nacimiento", "fecha_ingreso", "fecha_defuncion", "edad", "genero", "cuotas"
)
activos <- as.data.frame(activos)

activos <- activos %>%
  mutate(across(c(fecha_nacimiento, fecha_ingreso, fecha_defuncion), as.Date))

activos <- activos %>%
  mutate(
    anios_cumplidos = year(fecha_corte)- year(fecha_nacimiento) - 
    as.integer(format(fecha_nacimiento, "%m%d") > format(fecha_corte, "%m%d"))
  )

# Identificamos en estas lineas los registros invalidos
activos <- activos %>%
  mutate(
    id_asociado = str_trim(id_asociado),
    genero = str_to_upper(str_trim(genero)),

    sin_id = is.na(id_asociado) | id_asociado == "", # que no cuenten con ID asociado
    duplicado = duplicated(id_asociado) & !sin_id,  # IDS duplicados o q no tengan ID
    sin_nacimiento = is.na(fecha_nacimiento),    # Sin fecha de nacimiento
    sin_genero = is.na(genero) |                # Sin genero disponible
      !genero %in% c("MASCULINO", "FEMENINO"),  # Sin genero disponible
    edad_invalida = !is.na(anios_cumplidos) &  # La columna de edad vacia
      !between(anios_cumplidos, 0, 106),      # Que la edad no se encuentre en el rango de supuestos
    con_defuncion = !is.na(fecha_defuncion)   # Columna de fecha defuncion no vacia (Q murio)
  )

activos <- activos %>%
  mutate(
    motivo_exclusion = case_when(
      sin_id ~ "Sin identificador",
      sin_nacimiento ~ "Sin nacimiento valido",
      sin_genero ~ "Sin genero utilizable",
      edad_invalida ~ "Edad fuera de rango",
      con_defuncion ~ "Defuncion informada",
      TRUE ~ NA_character_
    )
  )
# Aca es importante aclarar que 18 de los 19 registros sin genero disponible tampoco cuentan con
# fecha de nacimiento disponible. Al estar ya contabilizados esos casos, entonces solo se cuenta 1
# caso donde el genero no esta disponible.


# Diagnostico general
activos %>%
  summarise(
    registros_originales = n(),
    sin_id = sum(sin_id),
    duplicados = sum(duplicado),
    sin_nacimiento = sum(sin_nacimiento),
    sin_genero = sum(sin_genero),
    edad_invalida = sum(edad_invalida),
    con_defuncion = sum(con_defuncion),
    exclusiones_unicas = sum(!is.na(motivo_exclusion)),
    N0 = sum(is.na(motivo_exclusion))
  )

# Entonces, se concluye que hay 136 observaciones sin fecha de nacimiento disponible, 1 sin genero disponible
# (sin repetir), y 1 que ya murio y que se encuentra en la hoja de activos.
# Por lo tanto, N0 = 104 142 - 138 = 104 004.

# Asi, filtramos la hoja de activos depurada:
activos_depurados <- activos %>%
  filter(is.na(motivo_exclusion)) %>%
    select(id_asociado, fecha_nacimiento, fecha_ingreso, anios_cumplidos, genero, cuotas)


# Comprobamos la depuracion con lass observaciones de fallecidos e inactivos.
# La logica es comparar loos IDS de inactivos y fallecidos con los activos. Si alguno coincide, 
# hay problema. Por lo tanto, solo extraemos la columna de los ID
fallecidos <- read_excel( here("datos", "originales", "Población CA-0309.xlsx"), sheet = "Fallecidos", range = cell_cols("A"), col_types = "text")
inactivos <- read_excel(
  here("datos", "originales", "Población CA-0309.xlsx"), sheet = "Inactivos",range = cell_cols("A"),col_types = "text")


fallecidos <- fallecidos %>%
  rename(id_asociado = 1) %>%
    mutate(id_asociado = str_trim(as.character(id_asociado)))

inactivos <- inactivos %>%
  rename(id_asociado = 1) %>%
    mutate(id_asociado = str_trim(as.character(id_asociado)))


# Coincidencias con activos. 
coincidencias_fallecidos <- activos %>% 
  semi_join(fallecidos, by = "id_asociado") %>% 
    filter(!is.na(id_asociado), id_asociado != "")

# Coincidencias con inactivos
coincidencias_inactivos <- activos %>%
  semi_join(inactivos, by = "id_asociado") %>%
    filter(!is.na(id_asociado), id_asociado != "")

# NOTA: Con el semi_join q es de tidyverse, verificamos que observaciones de activos
# coinciden con los inactivos. En este caso, los IDS.

# Ahora, con esto verificamos si las ID de fallecidos e inactivos coinciden con los activos.
tibble(
  "categoria" = c("IDS de activos y fallecidos:", "IDS de activos e inactivos:"),
  datos_repetidos = c( nrow(coincidencias_fallecidos),nrow(coincidencias_inactivos))
)


# Una vez comprobado que no se encuentran IDS de activos en las otras hojas, guardamos el xlsx con la hoja de activos depurada:

activos_depurados <- activos %>%
  filter(is.na(motivo_exclusion)) %>%
  select(
    id_asociado,
    fecha_nacimiento,
    fecha_ingreso,
    fecha_defuncion,
    edad,
    genero,
    cuotas,
    anios_cumplidos
  ) %>%
  rename(
    "Id Asociado" = id_asociado,
    "Fecha Nacimiento" = fecha_nacimiento,
    "Fecha Ingreso" = fecha_ingreso,
    "Fecha Defuncion" = fecha_defuncion,
    "Edad" = edad,
    "Genero" = genero,
    "Cuotas Fondo Mutual" = cuotas,
    "Años Cumplidos" = anios_cumplidos
  )

# Finalmente, guardamos el excel depurado:
write_xlsx(
  list(
    Activos = activos_depurados,
    Fallecidos = read_excel(here("datos", "originales",
                                "Población CA-0309.xlsx"),
                           sheet = "Fallecidos"),
    Inactivos = read_excel(here("datos", "originales",
                               "Población CA-0309.xlsx"),
                          sheet = "Inactivos")
  ),
  here("datos", "procesados", "Población CA-0309.xlsx")
)