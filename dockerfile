# Usa una imagen base de Python
FROM python:3.10-slim

# Establecer el directorio de trabajo
WORKDIR /app

# Copiar el archivo de requisitos para instalar las dependencias
COPY Flask/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copiar todo el código fuente de Flask al contenedor
COPY Flask /app

# Exponer el puerto donde se ejecutará Flask
EXPOSE 5000

# Comando para iniciar el servidor usando gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "aid:app"]
