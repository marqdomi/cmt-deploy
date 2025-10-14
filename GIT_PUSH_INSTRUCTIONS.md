# 🚀 Instrucciones para Subir Cambios a GitHub

## ✅ Estado Actual
- ✅ Rama creada: `feature/responsive-tables`
- ✅ Cambios commiteados localmente
- ⏳ Pendiente: Push al repositorio remoto

---

## 🔐 Opciones de Autenticación

### Opción 1: Personal Access Token (PAT) - RECOMENDADO

#### Paso 1: Crear un Personal Access Token
1. Ve a GitHub: https://github.com/settings/tokens
2. Click en **"Generate new token"** → **"Generate new token (classic)"**
3. Configura el token:
   - **Note**: `CMT Development Token`
   - **Expiration**: 90 days (o el que prefieras)
   - **Scopes**: Selecciona `repo` (completo)
4. Click en **"Generate token"**
5. **¡IMPORTANTE!** Copia el token inmediatamente (solo se muestra una vez)

#### Paso 2: Usar el Token para Push
```bash
# Ejecuta este comando en WSL (reemplaza YOUR_TOKEN con tu token)
cd /home/marco/cmt-deploy/app
git push -u origin feature/responsive-tables

# Cuando te pida credenciales:
Username: marqdomi
Password: <PEGA_TU_TOKEN_AQUÍ>
```

#### Paso 3: (Opcional) Guardar el token permanentemente
```bash
# Edita el archivo de credenciales
nano ~/.git-credentials

# Agrega esta línea (reemplaza YOUR_TOKEN):
https://marqdomi:YOUR_TOKEN@github.com
```

---

### Opción 2: SSH (Más Seguro y Permanente)

#### Paso 1: Generar clave SSH
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Presiona Enter para ubicación por defecto
# Presiona Enter para sin passphrase (o usa una)
```

#### Paso 2: Agregar clave SSH a GitHub
```bash
# Copia la clave pública
cat ~/.ssh/id_ed25519.pub

# Ve a GitHub: https://github.com/settings/ssh/new
# Pega la clave y guarda
```

#### Paso 3: Cambiar remote a SSH
```bash
cd /home/marco/cmt-deploy/app
git remote set-url origin git@github.com:marqdomi/certificate-manager-v2.git
git push -u origin feature/responsive-tables
```

---

### Opción 3: GitHub CLI (gh)

#### Paso 1: Instalar GitHub CLI
```bash
# En WSL Ubuntu
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

#### Paso 2: Autenticarse
```bash
gh auth login
# Selecciona: GitHub.com → HTTPS → Yes → Login with a web browser
```

#### Paso 3: Push
```bash
cd /home/marco/cmt-deploy/app
git push -u origin feature/responsive-tables
```

---

## 🎯 Comandos Completos (Después de Autenticarte)

### 1. Push de la Rama Feature
```bash
cd /home/marco/cmt-deploy/app
git push -u origin feature/responsive-tables
```

### 2. Merge a Main (Submódulo)
```bash
cd /home/marco/cmt-deploy/app
git checkout main
git pull origin main
git merge feature/responsive-tables
git push origin main
```

### 3. Actualizar Repositorio Principal
```bash
cd /home/marco/cmt-deploy
git add app
git add PROJECT_SCHEDULE.md RESUMEN_TABLAS_RESPONSIVAS.md TABLA_RESPONSIVE_MEJORAS.md
git commit -m "docs: Add responsive tables documentation and update app submodule"
git push origin feature/responsive-tables
```

### 4. Merge en Repositorio Principal
```bash
cd /home/marco/cmt-deploy
git checkout main
git pull origin main
git merge feature/responsive-tables
git push origin main
```

---

## 📋 Checklist de Pasos

### En el Submódulo (app/)
- [ ] Crear PAT o configurar SSH
- [ ] Push de `feature/responsive-tables` al remoto
- [ ] Checkout a `main`
- [ ] Merge de `feature/responsive-tables` en `main`
- [ ] Push de `main` al remoto

### En el Repositorio Principal (cmt-deploy/)
- [ ] Agregar documentación nueva
- [ ] Actualizar referencia del submódulo
- [ ] Commit de cambios
- [ ] Push de `feature/responsive-tables` al remoto
- [ ] Merge a `main`
- [ ] Push de `main` al remoto

---

## 🐛 Solución de Problemas

### Error: "Authentication failed"
**Solución**: Usa un Personal Access Token en lugar de tu password de GitHub

### Error: "Permission denied (publickey)"
**Solución**: Verifica que tu clave SSH esté agregada a GitHub

### Error: "fatal: The current branch has no upstream branch"
**Solución**: Usa `git push -u origin feature/responsive-tables`

### Error: "Updates were rejected because the tip of your current branch is behind"
**Solución**: 
```bash
git pull --rebase origin feature/responsive-tables
git push origin feature/responsive-tables
```

---

## 📞 Comando Rápido (Una Línea)

Si ya tienes el token, puedes usar este comando directo:

```bash
# Reemplaza YOUR_TOKEN
echo "https://marqdomi:YOUR_TOKEN@github.com" > ~/.git-credentials && chmod 600 ~/.git-credentials && cd /home/marco/cmt-deploy/app && git push -u origin feature/responsive-tables
```

---

## ✨ Siguiente Paso Recomendado

**OPCIÓN 1 (PAT)**: Es la más rápida. Ve a https://github.com/settings/tokens y genera un token ahora.

**OPCIÓN 2 (SSH)**: Es más segura y no necesitas recordar tokens. Configurala una vez y olvídate.

**OPCIÓN 3 (gh CLI)**: La más moderna y conveniente si trabajas con GitHub frecuentemente.

---

**¡Avísame cuál opción prefieres y te ayudo a completar el push! 🚀**
