@echo off
REM DEPRECATED: use requirements_cu130.txt instead.
echo WARNING: update_cu118.bat is deprecated. Use scripts\update_cu130.bat or scripts\ubuntu\update.sh
call scripts\setenv.bat
"%GIT_EXECUTABLE%" fetch origin main
"%GIT_EXECUTABLE%" reset --hard origin/main
"%PYTHON_EXECUTABLE%" -m pip install -r requirements_cu118.txt --default-timeout 100
"%PYTHON_EXECUTABLE%" download_models.py
