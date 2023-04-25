import os
import pandas as pd

def convert_csv_to_xls(csv_path, xls_path):
    # Leer el archivo CSV
    df = pd.read_csv(csv_path)

    # Calcular la duración de cada viaje y agregar la columna "ride_length"
    df['started_at'] = pd.to_datetime(df['started_at'])
    df['ended_at'] = pd.to_datetime(df['ended_at'])
    df['ride_length'] = df['ended_at'] - df['started_at']
    df['ride_length'] = df['ride_length'].dt.total_seconds().div(60).round(2)

    # Calcular el día de la semana y agregar la columna "day_of_week"
    df['day_of_week'] = df['started_at'].dt.dayofweek + 1

    # Guardar el archivo en formato XLSX
    df.to_excel(xls_path, index=False)

# Ruta de los archivos CSV y XLS
csv_directory = "C:\\Users\\jairo\\Proyectos python Jupyter\\proyecto data analyst google\\data .csv"
xls_directory = "C:\\Users\\jairo\\Proyectos python Jupyter\\proyecto data analyst google\\data .xls"

# Verificar que las carpetas existan
if not os.path.exists(csv_directory):
    print(f"La carpeta de archivos CSV no existe: {csv_directory}")
if not os.path.exists(xls_directory):
    print(f"La carpeta de archivos XLS no existe: {xls_directory}")

# Convertir todos los archivos CSV en la carpeta
for file in os.listdir(csv_directory):
    if file.endswith(".csv"):
        csv_path = os.path.join(csv_directory, file)
        xls_path = os.path.join(xls_directory, file[:-4] + ".xlsx")
        convert_csv_to_xls(csv_path, xls_path)
