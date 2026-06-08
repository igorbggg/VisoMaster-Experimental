@echo off
REM DEPRECATED: requirements_cu124.txt is no longer maintained. Use requirements_cu129.txt instead.
echo WARNING: update_cu124.bat is deprecated. Use scripts\update_cu129.bat or scripts\ubuntu\update.sh
call scripts\setenv.bat
"%GIT_EXECUTABLE%" fetch origin main
"%GIT_EXECUTABLE%" reset --hard origin/main
"%PYTHON_EXECUTABLE%" -m pip install -r requirements_cu124.txt --default-timeout 100
"%PYTHON_EXECUTABLE%" download_models.py
