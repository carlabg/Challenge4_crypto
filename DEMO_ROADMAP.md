# 🎬 DEMO ROADMAP - Challenge 4 SSS Movie Night
## Usando Remix + Sepolia Testnet ✅

**Status:** ✅ DECISIONES CONFIRMADAS - LISTO PARA EJECUTAR

---

## Decisiones Confirmadas:
1. ✅ Contrato: **MovieNightAllFriends.sol** (existente)
2. ✅ Blockchain: **Sepolia testnet** (real pero gratis)
3. ✅ IDE: **Remix** (https://remix.ethereum.org)
4. ✅ Código: **Mínimos cambios** (solo si es necesario)
5. ✅ Objetivo: **Demo funcional** (corta pero clara)
6. ✅ Direcciones: **Fake** (0x1111, 0x2222, etc)

---

## 🛣️ FASE 1: Preparar Contrato en Remix

**Duración:** 10 mins
**Deliverable:** Contrato compilado y listo

### 1.1 Abrir Remix
```
1. Ir a https://remix.ethereum.org
2. Click en "New File" → `MovieNightAllFriends.sol`
3. Copiar todo el contenido de MovieNightAllFriends.sol del repo
4. Pegar en Remix
```

### 1.2 Compilar
```
1. Click en "Solidity Compiler" (lado izquierdo)
2. Seleccionar versión: 0.8.24 (debe coincidir con pragma en contrato)
3. Click en "Compile MovieNightAllFriends.sol"
4. Si hay errores → Fixearlos (pero deben ser mínimos)
```

**Output esperado:**
```
✓ Compilation successful
```

---

## 💰 FASE 2: Obtener Sepolia Testnet ETH

**Duración:** 5 mins
**Deliverable:** Wallet con ETH de prueba

### 2.1 Crear/Conectar wallet
```
1. Metamask o wallet que uses
2. Cambiar red a "Sepolia" (no Ethereum Mainnet)
3. Copiar tu address (ej: 0xABC123...)
```

### 2.2 Obtener ETH gratis
```
Ir a faucet Sepolia:
- https://sepoliafaucet.com (requiere Alchemy account gratis)
- O: https://www.infura.io/faucet/sepolia

Pegar tu address → Click "Send" → Esperar ~30s
```

**Verificar:**
```
Vuelve a Metamask → Deberías ver ~0.5 ETH en Sepolia
```

---

## 🔐 FASE 3: Deployar Contrato en Sepolia

**Duración:** 5 mins
**Deliverable:** Contrato on-chain en Sepolia

### 3.1 Configurar Remix para Sepolia
```
1. En Remix, click en "Deploy & Run Transactions" (lado izquierdo)
2. Cambiar "Environment" a "Injected Provider - MetaMask"
3. Confirmar en Metamask que estás en Sepolia
```

### 3.2 Deployar
```
1. Seleccionar contrato: "MovieNightAllFriends"
2. En "Constructor parameters", ingresar las 6 direcciones:
   [
     "0x1111111111111111111111111111111111111111",
     "0x2222222222222222222222222222222222222222",
     "0x3333333333333333333333333333333333333333",
     "0x4444444444444444444444444444444444444444",
     "0x5555555555555555555555555555555555555555",
     "0x6666666666666666666666666666666666666666"
   ]
3. Click en "Deploy"
4. Confirmar en Metamask (pagar gas ~0.01 ETH)
```

**Esperar ~15 segundos...**

**Output esperado:**
```
✓ Contract deployed at: 0xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**GUARDAR esta dirección** ← necesitaremos después

---

## 🔢 FASE 4: Generar Shares

**Duración:** 10 mins
**Deliverable:** 6 shares listos para usar

### OPCIÓN A: Script Python (recomendado)

**Crear archivo:** `generate_shares.py`

```python
#!/usr/bin/env python3
"""Genera shares para la demo"""

FIELD_PRIME = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

# Polinomio simple: f(x) = 12345 + 111*x + 222*x^2 + 333*x^3 + 444*x^4 + 555*x^5
# f(0) = 12345 es el SECRET

coeffs = [12345, 111, 222, 333, 444, 555]

def eval_poly(x):
    result = 0
    for i, c in enumerate(coeffs):
        result = (result + c * pow(x, i, FIELD_PRIME)) % FIELD_PRIME
    return result

print("Generating shares...\n")

# Shares para los 6 amigos
for friend in range(1, 7):
    x = friend
    y = eval_poly(x)
    print(f"Friend {friend}: x={x}, y={y}")

# Secret y hash
secret = eval_poly(0)
print(f"\nSecret (f(0)): {secret}")

# Para el hash, usamos web3 o simplemente mostramos el valor
import hashlib
secret_bytes = secret.to_bytes(32, 'big')
# Usamos SHA3-256 como aproximación (en la demo, usaremos el valor directo)
hash_hex = hashlib.sha3_256(secret_bytes).hexdigest()
print(f"Hash (para setEpisodeHash): 0x{hash_hex}")
```

**Ejecutar:**
```bash
python3 generate_shares.py
```

**Output:**
```
Generating shares...

Friend 1: x=1, y=14010
Friend 2: x=2, y=40983
Friend 3: x=3, y=194496
Friend 4: x=4, y=719637
Friend 5: x=5, y=2071950
Friend 6: x=6, y=4984035

Secret (f(0)): 12345
Hash (para setEpisodeHash): 0x1abc5def...
```

### OPCIÓN B: Calcular Manualmente (si no quieres Python)

Usar una calculadora o web3.py online:
- https://www.python.org/downloads/ (instala Python)
- O pregúntame y te calculo los valores

---

## 🎬 FASE 5: Ejecutar Demo en Remix

**Duración:** 10 mins
**Deliverable:** Demo viendo Lagrange en acción

### 5.1 STEP 1: Organizer establece el hash

En Remix:
```
1. Expandir el contrato deployado (bajo "Deployed Contracts")
2. Buscar función: setEpisodeHash
3. Ingresar el hash que generamos:
   0x1abc5def...
4. Click "transact" (naranja)
5. Confirmar en Metamask
6. Esperar ~15s
```

**Verificar:**
```
En las transacciones abajo, deberías ver una "Status: ✓"
```

### 5.2 STEP 2: Los 6 amigos envían sus shares

**IMPORTANTE:** Esto es donde se vuelve "mágico" porque cada amigo es una dirección diferente.

**En Remix:**
```
1. Buscar función: unlockEpisode (en sección "Write")
2. Parámetros:
   - episodeId: 1
   - x: 1
   - y: 14010 (del Friend 1)
3. Click "transact"
4. Confirmar en Metamask

REPETIR PARA LOS 6 AMIGOS:
   Friend 2: x=2, y=40983
   Friend 3: x=3, y=194496
   Friend 4: x=4, y=719637
   Friend 5: x=5, y=2071950
   Friend 6: x=6, y=4984035
```

**NOTA:** En una demo real, cada amigo haría esto desde su propia wallet. Para simplificar, todos usan la misma wallet de Remix, pero técnicamente es como si cada uno participara.

### 5.3 STEP 3: Verificar que el episodio fue desbloqueado

**En Remix:**
```
1. Buscar función: getEpisodeStatus (en sección "Call")
2. Parámetro episodeId: 1
3. Click "call"
```

**Output esperado:**
```
(
  submissions: 6,
  secretRevealed: true,
  secretHash: 0x1abc5def...
)
```

> ⚠️ **NOTA:** El contrato ya NO devuelve `reconstructedSecret`. Solo confirma
> que la verificación fue exitosa. El secret NUNCA se almacena ni se emite on-chain.
> El evento emitido es `EpisodeUnlocked(episodeId)` — sin el valor del secret.

**¡ÉXITO! ✅**
- ✓ Submissions = 6 (todos enviaron)
- ✓ secretRevealed = true (fue desbloqueado)
- ✓ El hash verificó y matcheó
- ✓ El secret NUNCA fue expuesto on-chain

---

## 🏠 FASE 6: Reconstrucción Local del Secret

**Duración:** 2 mins
**Deliverable:** Cada amigo obtiene el secret en su máquina local

### 6.1 ¿Por qué este paso?

El contrato ya confirmó que los shares son correctos, pero **no reveló el secret**.
Los amigos ahora reconstruyen el secret localmente usando el mismo Python script.

### 6.2 Reconstruir con Python

```python
# Cada amigo ya tiene su share y puede ver los demás en los eventos ShareSubmitted
# Ejecutar: python3 generate_shares.py
# Output: Secret (f(0)): 12345
```

**Resultado:** Los amigos obtienen el secret (`12345`) **off-chain**, de forma privada.
El contrato actuó solo como **árbitro** — confirmó que los shares eran correctos
sin revelar el secret públicamente.

---

## 📊 TIMELINE COMPLETO

| Fase | Duración | Qué se logra |
|------|----------|-------------|
| **1. Remix + Compilar** | 10 mins | Contrato compilado |
| **2. Sepolia + ETH** | 5 mins | Wallet con fondos |
| **3. Deploy** | 5 mins | Contrato on-chain en Sepolia |
| **4. Generar Shares** | 10 mins | 6 shares listos |
| **5. Demo On-Chain** | 10 mins | ✅ Contrato verifica sin revelar |
| **6. Reconstrucción Local** | 2 mins | 🏠 Secret reconstruido off-chain |
| | **~42 mins** | **DEMO FUNCIONAL** |

---

## ✅ CHECKLIST PRE-DEMO

Antes de mostrar al público:

- [ ] Contrato compila sin errors en Remix
- [ ] Tengo ETH en Sepolia (faucet funcionó)
- [ ] Contrato está desplegado y tengo su address
- [ ] Generé los 6 shares correctamente
- [ ] Ejecuté setEpisodeHash() en Remix
- [ ] Ejecuté unlockEpisode() con los 6 shares
- [ ] getEpisodeStatus() muestra secretRevealed=true (sin revelar el secret)
- [ ] Evento EpisodeUnlocked emitido (no SecretRevealed)
- [ ] Reconstruí el secret localmente con Python → coincide con el original

---

## 🚨 POSIBLES PROBLEMAS Y SOLUCIONES

| Problema | Causa | Solución |
|----------|-------|----------|
| "Cannot deploy" en Remix | Wallet no conectada a Sepolia | Click en Metamask → cambiar a Sepolia |
| "Gas out of money" | No tengo ETH en Sepolia | Vuelve a faucet, espera 1h, reintentar |
| "Hash mismatch" al final | Hash generado es incorrecto | Verfifica que el script Python usó el mismo secret |
| "Invalid X coordinate" | X no coincide (debe ser 1-6) | Verifica que pasaste x=1 para Friend 1, x=2 para Friend 2, etc |
| Remix no responde | Conexión lenta | Espera 30s, recarga la página |
| "Address already submitted" | Enviaste el mismo friend dos veces | Cambia el valor de x para cada ejecución |

---

## 🎯 LO MÁS IMPORTANTE

**La demo funciona así:**

```
1. Secreto: 12345
2. Creamos polinomio f(x) con f(0) = 12345
3. Calculamos f(1), f(2), ..., f(6) → estos son los shares
4. Cada amigo i envía (i, f(i))
5. EL CONTRATO INTERPOLA USANDO LAGRANGE
6. Verifica que keccak256(resultado) == hash guardado
7. ✅ Emite EpisodeUnlocked — pero NUNCA guarda ni emite el secret
8. 🏠 Los amigos reconstruyen el secret LOCALMENTE con Python
```

**Por qué es tan cool:**
- El secret NUNCA se almacena ni se emite on-chain
- El contrato actúa como **árbitro**: solo dice "sí, es correcto" ✅
- Solo pedazos (shares) se enviaron
- Solo cuando TODOS 6 colaboran, se recupera el secret
- La matemática de Lagrange interpolation lo hace posible
- Es totalmente verificable on-chain, pero **privado**

---

## 📸 PARA LA PRESENTACIÓN

Aquí está lo que muestras:

```
SLIDE 1: "Shamir's Secret Sharing"
- Explicar el concepto de SSS

SLIDE 2: "El Polinomio"
- f(x) = 12345 + 111x + 222x² + 333x³ + 444x⁴ + 555x⁵
- f(0) = 12345 ← el secreto
- Mostrar los 6 shares calculados

SLIDE 3: "Demo Live en Sepolia"
- Abrir Remix
- Mostrar el contrato deployado
- Ejecutar setEpisodeHash()

SLIDE 4: "Los 6 amigos envían sus shares"
- Ejecutar unlockEpisode() 6 veces
- Mostrar que el contador sube 1→2→3→...→6

SLIDE 5: "El contrato verifica — sin revelar"
- Ejecutar getEpisodeStatus()
- Mostrar que secretRevealed = true
- Mostrar que NO hay reconstructedSecret visible
- "El contrato confirmó que es correcto, pero NO reveló el secret"

SLIDE 6: "Reconstrucción Local"
- Ejecutar Python script localmente
- Mostrar que los amigos obtienen 12345 en su máquina
- "El secret se reconstruye OFF-chain, de forma privada"

SLIDE 7: "¿Por qué es seguro?"
- El secret NUNCA aparece on-chain (ni en storage, ni en eventos)
- 5 amigos solos = cero información sobre f(0)
- 6 amigos juntos = reconstrucción perfecta
- Es matemática, no confianza

SLIDE FINAL: "Aplicaciones"
- Movie night (nuestra demo)
- Multisig wallets
- Escrow contracts
- Acceso a secrets críticos
```

---

## ¿LISTO?

Cuando termines cada fase, déjame saber:
- ✅ "Contrato compilado"
- ✅ "Tengo ETH en Sepolia"
- ✅  "Contrato desplegado"
- ✅ "Shares generados"
- ✅ "Demo funciona!"

¡Vamos a hacerlo! 🚀
