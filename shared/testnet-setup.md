# Guia de Testnets y Configuracion

Como obtener ETH de prueba, configurar RPC y desplegar contratos en redes de test. Esta guia cubre todo lo necesario para interactuar con testnets publicas desde Foundry.

> **Nota importante**: este repositorio NO requiere mainnet ETH. Todo se puede completar con Anvil (nodo local), testnets gratuitas, o una red Besu privada (ver [developer/11-private-networks](../developer/11-private-networks/)).

---

## Por que necesitas una testnet

| Escenario | Herramienta | Costo |
|-----------|-------------|-------|
| Tests unitarios y de integracion | Anvil (local) | Gratis, sin setup |
| Verificar comportamiento en red real | Testnet (Sepolia) | Gratis (faucet) |
| Probar una L2 y el bridge L1 → L2 | Arbitrum Sepolia | Gratis (bridge desde Sepolia) |
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

### Hoodi

Testnet para testing de infraestructura y staking. Reemplazo a Holesky, que quedo deprecada en 2025.

```
Nombre:     Hoodi
Chain ID:   560048
Moneda:     HoodiETH (sin valor real)
Consenso:   Proof of Stake
Block time: ~12 segundos
Explorer:   https://hoodi.etherscan.io
```

### Arbitrum Sepolia (L2 de prueba)

Testnet de **Arbitrum**. Es una L2 que se asienta en **Sepolia**, igual que Arbitrum One se asienta en Ethereum Mainnet. Se usa en el [laboratorio L1 → L2 del modulo developer/05](../developer/05-oracles-and-bridges/).

```
Nombre:     Arbitrum Sepolia
Chain ID:   421614
Moneda:     ETH (ETH nativo de Arbitrum Sepolia, sin valor real)
Tipo:       Optimistic rollup, se asienta en Sepolia (chain ID 11155111)
Block time: ~250 ms
RPC:        https://sepolia-rollup.arbitrum.io/rpc
Explorer:   https://sepolia.arbiscan.io
Bridge:     https://bridge.arbitrum.io (activar modo testnet)
```

> **Importante**: el SepoliaETH y el ETH de Arbitrum Sepolia son **balances distintos en redes distintas**, aunque tu direccion sea la misma. Para tener ETH en Arbitrum Sepolia hay dos caminos: hacer un **bridge** desde Sepolia (recomendado, porque es parte del aprendizaje) o usar un faucet especifico de Arbitrum Sepolia.

**Recomendacion**: usa **Sepolia** para ejercicios de L1 y **Arbitrum Sepolia** para los de L2.

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
cast balance $TU_ADDRESS --rpc-url https://ethereum-sepolia-rpc.publicnode.com
```

---

## Configurar MetaMask

MetaMask es una wallet: guarda tu clave y firma transacciones. **No "esta" en ninguna red**: habla con la red que elijas en el selector, a traves de un RPC.

1. Crea una cuenta **dedicada a pruebas**.
2. Sepolia ya viene incluida: menu de redes → *Show test networks*.
3. Agrega Arbitrum Sepolia desde [chainlist.org/chain/421614](https://chainlist.org/chain/421614) o a mano (*Add network manually*) con los datos de la seccion anterior.
4. (Opcional) Agrega Anvil: RPC `http://127.0.0.1:8545`, chain ID `31337`.

Al cambiar de red, tu direccion **no cambia**, pero el balance si. Cada red tiene su propio estado (ver [developer/01, seccion 0](../developer/01-solidity-fundamentals/)).

> Si MetaMask muestra un balance inesperado, lo primero que hay que revisar es **en que red estas**. Es el error mas comun.

---

## Configurar RPC

Necesitas un endpoint RPC para comunicarte con la testnet. Opciones:

### RPC publico (sin registro)

```
Sepolia:          https://ethereum-sepolia-rpc.publicnode.com
Hoodi:            https://ethereum-hoodi-rpc.publicnode.com
Arbitrum Sepolia: https://sepolia-rollup.arbitrum.io/rpc
Ethereum Mainnet: https://ethereum-rpc.publicnode.com   (solo lectura en este curso)
Arbitrum One:     https://arb1.arbitrum.io/rpc           (solo lectura en este curso)
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
arbitrum_sepolia = "https://sepolia-rollup.arbitrum.io/rpc"
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
- Verifica que el saldo esta **en la red donde estas enviando**: el ETH de Sepolia no paga gas en Arbitrum Sepolia, y viceversa (`cast chain-id --rpc-url $RPC` te dice con que red hablas)
- Verifica que el RPC apunta a Sepolia (chain ID 11155111)
- Solicita mas ETH de un faucet

### Error "nonce too low"

```bash
# El nonce se desincronizo. Verificar el nonce correcto:
cast nonce $TU_ADDRESS --rpc-url $SEPOLIA_RPC_URL
```

### RPC no responde

- Verifica tu API key si usas Alchemy/Infura
- Prueba el RPC publico como fallback: `https://ethereum-sepolia-rpc.publicnode.com`
- Revisa si el proveedor tiene un status page

---

## Recursos

- [Ethereum Testnets Overview](https://ethereum.org/en/developers/docs/networks/#ethereum-testnets)
- [Foundry Book - Deploying](https://book.getfoundry.sh/forge/deploying)
- [Sepolia Etherscan](https://sepolia.etherscan.io)
- [Hoodi Etherscan](https://hoodi.etherscan.io)
- [Arbitrum Sepolia Arbiscan](https://sepolia.arbiscan.io)
- [Arbitrum Docs - Chain info (RPCs y chain IDs)](https://docs.arbitrum.io/for-devs/dev-tools-and-resources/chain-info)
- [Chainlist](https://chainlist.org) - agregar redes a MetaMask por chain ID
