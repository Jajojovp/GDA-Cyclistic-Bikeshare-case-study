# Load libraries
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

# Set working directory and obtain a list of XLSX files
setwd("~/R/google data analyst proyect/data .xls")
files <- list.files(pattern = ".xlsx$")

# Read and combine XLSX files
df_list <- lapply(files, function(x) read_xlsx(x))
combined <- bind_rows(df_list)

# Convert 'started_at' column to datetime format
combined$started_at <- as.POSIXct(combined$started_at, format = "%Y-%m-%dT%H:%M:%S")

# Create 'hour' column by extracting the hour from the 'started_at' column
combined$hour <- as.integer(format(combined$started_at, "%H"))

# Exploratory and descriptive analysis

## Analysis by day of the week
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

## Analysis by hour of the day
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

# Save visualizations to files using ggsave
ggsave(filename = "usage_by_day_plot.png", plot = usage_by_day_plot, width = 10, height = 6, dpi = 300)
ggsave(filename = "usage_by_hour_plot.png", plot = usage_by_hour_plot, width = 10, height = 6, dpi = 300)

# Create the target variable
combined$member <- as.factor(ifelse(combined$member_casual == "member", 1, 0))

# Split data into training and test sets (80/20)
set.seed(123)
trainIndex <- createDataPartition(combined$member, p = 0.8, list = FALSE, times = 1)
train_set <- combined[trainIndex,]
test_set <- combined[-trainIndex,]

# Create a function to train and evaluate a logistic regression model with Ridge regularization
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

# Train and evaluate logistic regression models with Ridge regularization
alpha <- 0
lambdas <- c(0.001, 0.01, 0.1, 1, 10)

ridge_accuracy_results <- c()
for (lambda in lambdas) {
  accuracy <- train_and_evaluate_logreg_ridge(alpha, lambda, train_set, test_set)
  ridge_accuracy_results <- c(ridge_accuracy_results, accuracy)
}

# Show accuracy results for different lambda values
ridge_accuracy_results

# Find the best lambda value
best_lambda <- lambdas[which.max(ridge_accuracy_results)]

# Train the final logistic regression model with Ridge regularization using the best lambda value
x_train <- model.matrix(member ~ ride_length + day_of_week, data = train_set)[,-1]
y_train <- train_set$member
x_test <- model.matrix(member ~ ride_length + day_of_week, data = test_set)[,-1]
y_test <- test_set$member

logreg_ridge_final <- glmnet(x_train, y_train, alpha = 0, lambda = best_lambda, family = "binomial")
predictions_final <- predict(logreg_ridge_final, newx = x_test, type = "response", s = best_lambda)
predicted_classes_final <- ifelse(predictions_final > 0.5, 1, 0)
conf_matrix_final <- confusionMatrix(as.factor(predicted_classes_final), y_test)

# Display the confusion matrix and accuracy of the final model
conf_matrix_final
conf_matrix_final$overall["Accuracy"]
