# Guia de Herramientas (Tooling)

Referencia practica de las herramientas usadas a lo largo de esta ruta de aprendizaje. Foundry es el framework principal; el resto son complementos para seguridad, prototipado y librerias.

---

## Foundry

Framework de desarrollo para Ethereum escrito en Rust. Rapido, nativo de Solidity para tests, y con herramientas de linea de comandos potentes.

### Instalacion

```bash
# Instalar foundryup (gestor de versiones de Foundry)
curl -L https://foundry.paradigm.xyz | bash

# Ejecutar foundryup para instalar forge, cast y anvil
foundryup
```

Verificar la instalacion:

```bash
forge --version
cast --version
anvil --version
```

### forge - Compilacion y testing

```bash
# Crear un proyecto nuevo
forge init my-project
cd my-project

# Compilar contratos
forge build

# Ejecutar tests
forge test

# Tests con verbosidad (ver traces de transacciones)
forge test -vvvv

# Ejecutar un test especifico
forge test --match-test testSwapExactInput

# Ejecutar tests de un contrato especifico
forge test --match-contract AMMTest

# Cobertura de tests
forge coverage

# Cobertura con reporte detallado
forge coverage --report lcov
```

### forge script - Despliegue y scripting

```bash
# Ejecutar un script de despliegue en local
forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast

# Despliegue en testnet (requiere private key)
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

Estructura tipica de un script de despliegue:

```solidity
// script/Deploy.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyContract} from "../src/MyContract.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        new MyContract();
        vm.stopBroadcast();
    }
}
```

### cast - Interaccion con la blockchain

```bash
# Leer un valor publico de un contrato
cast call $CONTRACT_ADDRESS "totalSupply()(uint256)" --rpc-url $RPC_URL

# Enviar una transaccion
cast send $CONTRACT_ADDRESS "transfer(address,uint256)" $TO $AMOUNT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL

# Convertir entre unidades
cast to-wei 1.5 ether        # 1500000000000000000
cast from-wei 1000000000000000000  # 1.000000000000000000

# Decodificar calldata
cast 4byte-decode 0xa9059cbb000000...

# Obtener informacion de un bloque
cast block latest --rpc-url $RPC_URL

# Obtener el balance de una cuenta
cast balance $ADDRESS --rpc-url $RPC_URL

# Buscar eventos
cast logs --from-block 18000000 --to-block latest \
  --address $CONTRACT_ADDRESS \
  "Transfer(address,address,uint256)" \
  --rpc-url $RPC_URL
```

---

## Anvil - Nodo local

Anvil es el nodo local de Foundry. Levanta una instancia de Ethereum en memoria, ideal para desarrollo y testing.

### Uso basico

```bash
# Levantar nodo local (puerto 8545 por defecto)
anvil

# Levantar con un numero especifico de cuentas
anvil --accounts 20

# Levantar con un balance inicial personalizado
anvil --balance 10000
```

### Forking de mainnet

Permite interactuar con el estado real de mainnet en un entorno local. Indispensable para testear integraciones con protocolos existentes (Uniswap, Aave, etc.).

```bash
# Fork de Ethereum mainnet
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY

# Fork desde un bloque especifico (reproducibilidad)
anvil --fork-url $RPC_URL --fork-block-number 18500000
```

### Comandos utiles durante el fork

```bash
# Avanzar el tiempo (util para tests con timelocks)
cast rpc anvil_increaseTime 86400   # avanzar 1 dia
cast rpc anvil_mine 1               # minar un bloque

# Impersonar una cuenta (actuar como cualquier address)
cast rpc anvil_impersonateAccount $WHALE_ADDRESS

# Setear balance de una cuenta
cast rpc anvil_setBalance $ADDRESS 0xDE0B6B3A7640000  # 1 ETH en hex
```

---

## Hardhat

Framework alternativo basado en JavaScript/TypeScript. No es el framework principal de este repositorio pero vale la pena conocerlo.

### Cuando usar Hardhat en vez de Foundry

- Proyectos con frontend integrado que ya usan un stack JS/TS completo
- Equipos donde todos tienen experiencia en JS pero no en Solidity puro para tests
- Plugins especificos que solo existen en el ecosistema Hardhat (algunos verificadores, integraciones)
- Tareas de scripting complejas que se benefician de librerias npm

### Instalacion rapida

```bash
npm init -y
npm install --save-dev hardhat
npx hardhat init
```

> En este repositorio usamos Foundry para todo. Si necesitas Hardhat para algo especifico, puedes coexistir ambos en el mismo proyecto con `hardhat-foundry`.

---

## Slither - Analisis estatico

Herramienta de analisis estatico para Solidity desarrollada por Trail of Bits. Detecta vulnerabilidades comunes, problemas de optimizacion y malas practicas sin ejecutar el codigo.

### Instalacion

```bash
# Requiere Python 3.8+
pip3 install slither-analyzer

# Verificar
slither --version
```

### Uso basico

```bash
# Analizar todos los contratos de un proyecto Foundry
slither .

# Analizar un contrato especifico
slither src/MyContract.sol

# Filtrar por severidad
slither . --filter-paths "test|script" --exclude-informational

# Generar reporte en formato JSON
slither . --json slither-report.json

# Listar detectores disponibles
slither --list-detectors
```

### Detectores mas relevantes

| Detector | Que encuentra |
|----------|--------------|
| `reentrancy-eth` | Reentrancy que drena ETH |
| `reentrancy-no-eth` | Reentrancy sin transferencia de ETH |
| `uninitialized-state` | Variables de estado sin inicializar |
| `arbitrary-send-eth` | Envio de ETH a direcciones arbitrarias |
| `suicidal` | Contratos que pueden ser destruidos |
| `locked-ether` | ETH que queda atrapado sin forma de retirarlo |

### Integracion con CI

```bash
# En un pipeline de CI, hacer que falle si hay findings de severidad alta
slither . --filter-paths "test|script" --exclude-low --exclude-informational --fail-on high
```

---

## Mythril - Ejecucion simbolica

Herramienta de seguridad que usa ejecucion simbolica y SMT solving para encontrar vulnerabilidades que el analisis estatico no detecta. Mas lenta que Slither pero encuentra bugs mas profundos.

### Instalacion

```bash
# Via pip
pip3 install mythril

# Via Docker (recomendado para evitar conflictos de dependencias)
docker pull mythril/myth

# Verificar
myth version
```

### Uso basico

```bash
# Analizar un contrato compilado
myth analyze src/MyContract.sol

# Analizar con mas profundidad (mas tiempo, mas cobertura)
myth analyze src/MyContract.sol --execution-timeout 300

# Analizar bytecode directamente
myth analyze --bin-runtime $BYTECODE

# Formato de salida JSON
myth analyze src/MyContract.sol -o json
```

### Con Docker

```bash
# Montar el directorio del proyecto
docker run -v $(pwd):/project mythril/myth analyze /project/src/MyContract.sol
```

### Que busca Mythril

- Integer overflow/underflow (relevante pre-Solidity 0.8)
- Reentrancy
- Dependencia de timestamp
- Delegatecall a direcciones controlables
- Ether atrapado
- Acceso no autorizado a `selfdestruct`

> Mythril es complementario a Slither. Se recomienda ejecutar ambos: Slither para deteccion rapida y amplia, Mythril para analisis profundo de paths criticos.

---

## Remix IDE

IDE web para Solidity. No requiere instalacion.

### Cuando usarlo

- Prototipado rapido de una idea (sin setup de proyecto)
- Depurar una transaccion especifica con el debugger integrado
- Ensenar o aprender conceptos basicos de Solidity
- Desplegar contratos simples a testnet sin scripts

### Acceso

Abrir [https://remix.ethereum.org](https://remix.ethereum.org) en el navegador.

> Para desarrollo serio y testing, usar Foundry. Remix es util como herramienta complementaria de exploracion.

---

## OpenZeppelin Contracts

Libreria de smart contracts auditados y estandarizados. Base para la mayoria de proyectos en produccion.

### Instalacion en Foundry

```bash
# Instalar via forge
forge install OpenZeppelin/openzeppelin-contracts

# Agregar remapping en foundry.toml o remappings.txt
# @openzeppelin/=lib/openzeppelin-contracts/
```

En `foundry.toml`:

```toml
[profile.default]
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/"
]
```

### Uso en contratos

```solidity
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MyToken is ERC20, Ownable, ReentrancyGuard {
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {}
}
```

### Contratos mas usados

| Contrato | Uso |
|----------|-----|
| `ERC20` | Token fungible |
| `ERC721` | NFT |
| `ERC1155` | Multi-token |
| `ERC4626` | Vault tokenizado |
| `Ownable` | Control de acceso simple |
| `AccessControl` | Control de acceso basado en roles |
| `ReentrancyGuard` | Proteccion contra reentrancy |
| `Pausable` | Pausa de emergencia |
| `Governor` | Gobernanza on-chain |
| `TimelockController` | Timelock para ejecucion de propuestas |

---

## Chainlink Contracts

Libreria oficial de Chainlink para integrar oracles, price feeds, VRF (aleatoriedad verificable) y automation.

### Instalacion en Foundry

```bash
forge install smartcontractkit/chainlink

# Remapping
# @chainlink/=lib/chainlink/
```

### Uso tipico: Price Feed

```solidity
import {AggregatorV3Interface} from
    "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceConsumer {
    AggregatorV3Interface internal priceFeed;

    constructor(address feedAddress) {
        priceFeed = AggregatorV3Interface(feedAddress);
    }

    function getLatestPrice() public view returns (int256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }
}
```

### Direcciones de feeds comunes (Ethereum mainnet)

| Par | Direccion |
|-----|-----------|
| ETH/USD | `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419` |
| BTC/USD | `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c` |
| USDC/USD | `0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6` |

> Las direcciones cambian por red. Consultar [docs.chain.link](https://docs.chain.link/data-feeds/price-feeds/addresses) para la lista completa.

---

## Extensiones recomendadas para VS Code

| Extension | Uso |
|-----------|-----|
| **Solidity (Juan Blanco)** | Syntax highlighting, compilacion, linting basico para Solidity |
| **Solidity (Nomic Foundation)** | Soporte avanzado con integration de Hardhat y LSP |
| **Even Better TOML** | Soporte para archivos `foundry.toml` |
| **Error Lens** | Muestra errores y warnings inline en el editor |
| **GitLens** | Historial de git mejorado, blame inline |
| **Todo Tree** | Rastrea TODOs y FIXMEs en el proyecto |

### Configuracion recomendada para Solidity

En `.vscode/settings.json`:

```json
{
    "solidity.packageDefaultDependenciesContractsDirectory": "src",
    "solidity.packageDefaultDependenciesDirectory": "lib",
    "editor.formatOnSave": true,
    "[solidity]": {
        "editor.defaultFormatter": "JuanBlanco.solidity"
    }
}
```

---

## Resumen de flujo de trabajo

```
1. forge init my-project          # Crear proyecto
2. Escribir contratos en src/     # Desarrollar
3. Escribir tests en test/        # Testear
4. forge test -vvvv               # Ejecutar tests
5. forge coverage                 # Verificar cobertura
6. slither .                      # Analisis estatico
7. myth analyze src/Contract.sol  # Ejecucion simbolica (contratos criticos)
8. forge script --broadcast       # Desplegar
```

---

## Hyperledger Besu

Cliente Ethereum para redes privadas y consorcio. Soporta EVM, consenso IBFT 2.0/QBFT, y transacciones privadas.

### Instalacion via Docker (recomendado)

```bash
# Verificar que Docker esta instalado
docker --version
docker-compose --version

# Descargar imagen de Besu
docker pull hyperledger/besu:latest

# Verificar
docker run --rm hyperledger/besu:latest --version
```

### Levantar red IBFT 2.0 de 4 nodos

El modulo [developer/11-private-networks](../developer/11-private-networks/) incluye un `docker-compose.yml` listo para usar:

```bash
cd developer/11-private-networks/docker
docker-compose up -d

# Verificar que los 4 nodos estan corriendo
docker-compose ps

# Ver logs de un nodo
docker-compose logs -f node1
```

### Comandos utiles

```bash
# Verificar que la red esta produciendo bloques
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" \
  http://localhost:8545

# Listar validators activos
curl -X POST --data '{"jsonrpc":"2.0","method":"ibft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" \
  http://localhost:8545

# Ver peers conectados
curl -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  -H "Content-Type: application/json" \
  http://localhost:8545
```

### Configurar Foundry para Besu

```toml
# En foundry.toml
[rpc_endpoints]
besu = "http://localhost:8545"
```

```bash
# Desplegar contrato a red Besu local
forge create src/MyContract.sol:MyContract \
  --rpc-url http://localhost:8545 \
  --private-key 0xTU_PRIVATE_KEY_DEL_GENESIS
```

> Las cuentas pre-fondeadas y sus private keys estan en el `genesis.json` de la red. Ver [developer/11-private-networks](../developer/11-private-networks/) para detalles.

---

## Hyperledger FireFly

Plataforma de orquestacion multiparty para aplicaciones Web3 enterprise. Proporciona APIs REST unificadas para tokens, messaging y data exchange.

### Instalacion del CLI

```bash
# Instalar FireFly CLI (requiere Go 1.21+)
go install github.com/hyperledger/firefly-cli/ff@latest

# Verificar
ff version

# Alternativa: descargar binario desde GitHub Releases
# https://github.com/hyperledger/firefly-cli/releases
```

### Crear y levantar stack

```bash
# Crear stack con Besu como blockchain
ff init my-stack --blockchain-provider ethereum --blockchain-connector ethconnect --blockchain-node besu

# Levantar el stack
ff start my-stack

# Ver estado
ff info my-stack
```

### API principales

Una vez levantado, FireFly expone una API REST (por defecto en `http://localhost:5000`):

```bash
# Listar organizaciones registradas
curl http://localhost:5000/api/v1/network/organizations

# Crear token pool (fungible)
curl -X POST http://localhost:5000/api/v1/tokens/pools \
  -H "Content-Type: application/json" \
  -d '{"name":"my-token","type":"fungible","config":{}}'

# Enviar mensaje broadcast (a todas las orgs)
curl -X POST http://localhost:5000/api/v1/messages/broadcast \
  -H "Content-Type: application/json" \
  -d '{"data":[{"value":"Hello from Org1"}]}'

# Enviar mensaje privado (a una org especifica)
curl -X POST http://localhost:5000/api/v1/messages/private \
  -H "Content-Type: application/json" \
  -d '{"group":{"members":[{"identity":"org2"}]},"data":[{"value":"Private msg"}]}'
```

> Para el ejercicio completo de FireFly, ver [developer/11-private-networks](../developer/11-private-networks/).

---

## Testnets y Faucets

Para desplegar contratos en redes de prueba publicas (Sepolia, Holesky), necesitas testnet ETH gratuito.

La guia completa esta en [shared/testnet-setup.md](testnet-setup.md). Resumen rapido:

| Testnet | Chain ID | Faucet recomendado |
|---------|----------|--------------------|
| Sepolia | 11155111 | Google Cloud Faucet, Alchemy Faucet |
| Holesky | 17000 | Holesky PoW Faucet |

```bash
# Configurar en foundry.toml
# [rpc_endpoints]
# sepolia = "${SEPOLIA_RPC_URL}"

# Desplegar a Sepolia
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast --verify
```

> **Nota**: este repositorio NO requiere mainnet ETH. Todo se completa con Anvil (local), testnets gratuitas, o Besu (red privada local).
