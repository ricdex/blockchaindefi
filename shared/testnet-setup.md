# Guia de Testnets y Configuracion

Como obtener ETH de prueba, configurar RPC y desplegar contratos en redes de test. Esta guia cubre todo lo necesario para interactuar con testnets publicas desde Foundry.

> **Nota importante**: este repositorio NO requiere mainnet ETH. Todo se puede completar con Anvil (nodo local), testnets gratuitas, o una red Besu privada (ver [developer/11-private-networks](../developer/11-private-networks/)).

---

## Por que necesitas una testnet

| Escenario | Herramienta | Costo |
|-----------|-------------|-------|
| Tests unitarios y de integracion | Anvil (local) | Gratis, sin setup |
| Verificar comportamiento en red real | Testnet (Sepolia) | Gratis (faucet) |
| Red privada / enterprise | Besu IBFT 2.0 | Gratis (Docker local) |
| Produccion | Mainnet | ETH real |

La mayoria de los ejercicios de este repositorio se completan con **Anvil** (nodo local). Solo necesitas testnet ETH cuando quieras:
- Verificar que un deploy funciona en una red real con otros nodos
- Probar integracion con contratos ya desplegados en testnet
- Practicar el flujo completo de deploy + verify

---

## Testnets recomendadas

### Sepolia (recomendada)

Red de prueba principal de Ethereum. Proof of Stake, estable y bien soportada.

```
Nombre:     Sepolia
Chain ID:   11155111
Moneda:     SepoliaETH (sin valor real)
Consenso:   Proof of Stake
Block time: ~12 segundos
Explorer:   https://sepolia.etherscan.io
```

### Holesky

Testnet para testing de infraestructura y staking. Mas grande que Sepolia, util para pruebas de escala.

```
Nombre:     Holesky
Chain ID:   17000
Moneda:     HoleskyETH (sin valor real)
Consenso:   Proof of Stake
Block time: ~12 segundos
Explorer:   https://holesky.etherscan.io
```

**Recomendacion**: usa **Sepolia** para ejercicios de este repositorio. Es la testnet mas soportada por faucets y herramientas.

---

## Paso a paso: obtener testnet ETH

### 1. Crear wallet (si no tienes una)

```bash
# Opcion A: generar wallet con cast (Foundry)
cast wallet new

# Opcion B: usar una wallet existente de MetaMask
# Exportar private key desde MetaMask > Account Details > Export Private Key
```

> **Seguridad**: usa una wallet dedicada para testnets. NUNCA uses la misma private key que en mainnet.

### 2. Obtener SepoliaETH de un faucet

| Faucet | Requisito | Cantidad | URL |
|--------|-----------|----------|-----|
| Google Cloud Faucet | Cuenta Google | 0.05 ETH | cloud.google.com/application/web3/faucet/ethereum/sepolia |
| Alchemy Faucet | Cuenta Alchemy (gratis) | 0.5 ETH/dia | sepoliafaucet.com |
| Infura Faucet | Cuenta Infura (gratis) | 0.5 ETH/dia | infura.io/faucet/sepolia |
| QuickNode Faucet | Cuenta QuickNode (gratis) | Variable | faucet.quicknode.com/ethereum/sepolia |

**Procedimiento general**:
1. Copia tu address publica (0x...)
2. Ve a uno de los faucets
3. Pega tu address y solicita ETH
4. Espera 1-2 minutos
5. Verifica en `https://sepolia.etherscan.io/address/TU_ADDRESS`

> Si un faucet esta caido, prueba otro. Los faucets se saturan en periodos de alta demanda.

### 3. Verificar balance

```bash
cast balance $TU_ADDRESS --rpc-url https://rpc.sepolia.org
```

---

## Configurar RPC

Necesitas un endpoint RPC para comunicarte con la testnet. Opciones:

### RPC publico (sin registro)

```
Sepolia:  https://rpc.sepolia.org
Holesky:  https://rpc.holesky.ethpandaops.io
```

Limitaciones: rate limiting, puede ser lento, no recomendado para deploys frecuentes.

### RPC con proveedor (gratis con registro)

| Proveedor | Plan gratis | Como obtener |
|-----------|-------------|--------------|
| Alchemy | 300M compute units/mes | Crear cuenta en alchemy.com, crear app Sepolia |
| Infura | 100K requests/dia | Crear cuenta en infura.io, crear proyecto |
| QuickNode | 10M API credits/mes | Crear cuenta en quicknode.com |

**Recomendacion**: registra una cuenta gratuita en Alchemy o Infura para tener un RPC confiable.

---

## Configurar Foundry para testnet

### 1. Archivo `.env`

```bash
# .env (NUNCA commitear este archivo)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/TU_API_KEY
PRIVATE_KEY=0xTU_PRIVATE_KEY_DE_TESTNET
ETHERSCAN_API_KEY=TU_ETHERSCAN_API_KEY
```

> Agrega `.env` a tu `.gitignore` si no esta ya.

### 2. Configuracion en `foundry.toml`

```toml
[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"
local = "http://localhost:8545"
besu = "http://localhost:8545"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}", url = "https://api-sepolia.etherscan.io/api" }
```

### 3. Cargar variables de entorno

```bash
# Cargar .env en la sesion actual
source .env
```

### 4. Desplegar a testnet

```bash
# Deploy con forge script
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# Deploy directo con forge create
forge create src/MyContract.sol:MyContract \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### 5. Verificar el deploy

```bash
# Verificar que el contrato responde
cast call $CONTRACT_ADDRESS "name()(string)" --rpc-url $SEPOLIA_RPC_URL
```

---

## Comparativa: Anvil vs Testnet vs Besu

```
+------------------+------------------+------------------+------------------+
| Caracteristica   | Anvil (local)    | Testnet (Sepolia)| Besu (privada)   |
+------------------+------------------+------------------+------------------+
| Setup            | Instantaneo      | Registro faucet  | Docker compose   |
| Costo            | Gratis           | Gratis (faucet)  | Gratis (local)   |
| Velocidad        | Instantaneo      | ~12s por bloque  | ~2s por bloque   |
| Persistencia     | Solo en sesion   | Permanente       | Mientras corra   |
| Otros nodos      | No               | Si (red publica) | Si (red local)   |
| Ideal para       | Unit tests       | Integration test | Enterprise/DID   |
| Privacidad txs   | N/A              | No               | Si (con Tessera) |
+------------------+------------------+------------------+------------------+
```

---

## Troubleshooting

### Faucet no entrega ETH

- **Causa comun**: wallet nueva sin historial. Algunos faucets requieren actividad previa.
- **Solucion**: prueba otro faucet de la tabla. Google Cloud Faucet suele ser el mas accesible.

### Transaccion pendiente (stuck)

```bash
# Ver nonce actual de tu cuenta
cast nonce $TU_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Si tienes un tx stuck, enviar tx con mismo nonce y mas gas
cast send $TU_ADDRESS --value 0 \
  --nonce $NONCE_STUCK \
  --gas-price $(cast gas-price --rpc-url $SEPOLIA_RPC_URL | awk '{print $1 * 2}') \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL
```

### Error "insufficient funds"

- Verifica que tienes SepoliaETH (no mainnet ETH)
- Verifica que el RPC apunta a Sepolia (chain ID 11155111)
- Solicita mas ETH de un faucet

### Error "nonce too low"

```bash
# El nonce se desincronizo. Verificar el nonce correcto:
cast nonce $TU_ADDRESS --rpc-url $SEPOLIA_RPC_URL
```

### RPC no responde

- Verifica tu API key si usas Alchemy/Infura
- Prueba el RPC publico como fallback: `https://rpc.sepolia.org`
- Revisa si el proveedor tiene un status page

---

## Recursos

- [Ethereum Testnets Overview](https://ethereum.org/en/developers/docs/networks/#ethereum-testnets)
- [Foundry Book - Deploying](https://book.getfoundry.sh/forge/deploying)
- [Sepolia Etherscan](https://sepolia.etherscan.io)
- [Holesky Etherscan](https://holesky.etherscan.io)
