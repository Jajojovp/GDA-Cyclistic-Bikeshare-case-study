# Cargar bibliotecas
library(readr)
library(tidyverse)
library(dplyr)
library(lubridate)
library(skimr)
library(janitor)
library(vroom)
library(data.table)
library(readxl)
library(caret)
library(rpart)
library(randomForest)
library(glmnet)

# Establecer directorio de trabajo y obtener una lista de archivos XLSX
setwd("~/R/google data analyst proyect/data .xls")
files <- list.files(pattern = ".xlsx$")

# Leer y combinar archivos XLSX
df_list <- lapply(files, function(x) read_xlsx(x))
combined <- bind_rows(df_list)

# Convertir la columna 'started_at' a formato datetime
combined$started_at <- as.POSIXct(combined$started_at, format = "%Y-%m-%dT%H:%M:%S")

# Crear la columna 'hour' extrayendo la hora de la columna 'started_at'
combined$hour <- as.integer(format(combined$started_at, "%H"))

# Análisis exploratorio y descriptivo

## Análisis por día de la semana
usage_by_day <- combined %>%
  group_by(member_casual, day_of_week) %>%
  summarize(rides = n()) %>%
  ungroup()

usage_by_day_plot <- ggplot(usage_by_day, aes(x = day_of_week, y = rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  scale_x_continuous(breaks = 1:7, labels = c("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo")) +
  labs(title = "Uso por tipo de usuario y día de la semana",
       x = "Día de la semana",
       y = "Cantidad de viajes",
       fill = "Tipo de usuario") +
  theme_minimal()

## Análisis por hora del día
usage_by_hour <- combined %>%
  group_by(member_casual, hour) %>%
  summarize(rides = n()) %>%
  ungroup()

usage_by_hour_plot <- ggplot(usage_by_hour, aes(x = hour, y = rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  labs(title = "Uso por tipo de usuario y hora del día",
       x = "Hora del día",
       y = "Cantidad de viajes",
       fill = "Tipo de usuario") +
  theme_minimal()

# Guardar las visualizaciones en archivos utilizando ggsave
ggsave(filename = "usage_by_day_plot.png", plot = usage_by_day_plot, width = 10, height = 6, dpi = 300)
ggsave(filename = "usage_by_hour_plot.png", plot = usage_by_hour_plot, width = 10, height = 6, dpi = 300)

# Crear la variable objetivo
combined$member <- as.factor(ifelse(combined$member_casual == "member", 1, 0))

# Dividir los datos en conjuntos de entrenamiento y prueba (80/20)
set.seed(123)
trainIndex <- createDataPartition(combined$member, p = 0.8, list = FALSE, times = 1)
train_set <- combined[trainIndex,]
test_set <- combined[-trainIndex,]

# Crear función para entrenar y evaluar un modelo de regresión logística con regularización Ridge
train_and_evaluate_logreg_ridge <- function(alpha, lambda, train_set, test_set) {
  x_train <- model.matrix(member ~ ride_length + day_of_week, data = train_set)[,-1]
  y_train <- train_set$member
  
  x_test <- model.matrix(member ~ ride_length + day_of_week, data = test_set)[,-1]
  y_test <- test_set$member
  
  logreg_ridge <- glmnet(x_train, y_train, alpha = alpha, lambda = lambda, family = "binomial")
  predictions <- predict(logreg_ridge, newx = x_test, type = "response", s = lambda)
  predicted_classes <- ifelse(predictions > 0.5, 1, 0)
  
  conf_matrix <- confusionMatrix(as.factor(predicted_classes), y_test)
  return(conf_matrix$overall["Accuracy"])
}

# Entrenar y evaluar modelos de regresión logística con regularización Ridge
alpha <- 0
lambdas <- c(0.001, 0.01, 0.1, 1, 10)

ridge_accuracy_results <- c()
for (lambda in lambdas) {
  accuracy <- train_and_evaluate_logreg_ridge(alpha, lambda, train_set, test_set)
  ridge_accuracy_results <- c(ridge_accuracy_results, accuracy)
}

# Mostrar resultados de precisión para diferentes valores de lambda
ridge_accuracy_results

# Encontrar el mejor valor de lambda
best_lambda <- lambdas[which.max(ridge_accuracy_results)]

# Entrenar el modelo final de regresión logística con regularización Ridge utilizando el mejor valor de lambda
x_train <- model.matrix(member ~ ride_length + day_of_week, data = train_set)[,-1]
y_train <- train_set$member
x_test <- model.matrix(member ~ ride_length + day_of_week, data = test_set)[,-1]
y_test <- test_set$member

logreg_ridge_final <- glmnet(x_train, y_train, alpha = 0, lambda = best_lambda, family = "binomial")
predictions_final <- predict(logreg_ridge_final, newx = x_test, type = "response", s = best_lambda)
predicted_classes_final <- ifelse(predictions_final > 0.5, 1, 0)
conf_matrix_final <- confusionMatrix(as.factor(predicted_classes_final), y_test)

# Mostrar la matriz de confusión y precisión del modelo final
conf_matrix_final
conf_matrix_final$overall["Accuracy"]
