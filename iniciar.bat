@echo off
echo Iniciando mongo.py...
start cmd /k "python C:\xampp\htdocs\scripts\mongo.py"
timeout /t 5 /nobreak >nul

echo Iniciando sensor.py...
start cmd /k "python C:\xampp\htdocs\scripts\sensor.py"
timeout /t 5 /nobreak >nul

echo Iniciando mazerun.exe...
start cmd /k "C:\xampp\htdocs\executables\mazerun.exe 9 1 5"
