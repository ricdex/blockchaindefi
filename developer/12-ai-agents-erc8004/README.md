# Modulo 12: AI Agents On-Chain (ERC-8004)

## Objetivo

Al completar este modulo seras capaz de:

- Entender ERC-8004 (Trustless Agents) y su arquitectura de tres registries
- Implementar un Identity Registry basado en ERC-721 para registro de agentes IA
- Implementar un Reputation Registry para feedback de clientes
- Implementar un Validation Registry para verificacion independiente
- Comprender los modelos de confianza: reputacion, cripto-economico, TEE
- Entender la interaccion entre agentes IA y protocolos on-chain (A2A, MCP)
- Identificar vulnerabilidades: Sybil attacks, reputation manipulation, agent impersonation
- Desplegar y operar un ecosistema de agentes IA en blockchain

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (tipos, storage, events, modifiers)
- Modulo 02: Tokens and Standards (ERC-721, ERC-1155)
- Modulo 04: Security Patterns (access control, firmas)
- Modulo 08: Identity, DID and SBT (identidad descentralizada, credenciales)
- Foundry instalado y funcional
- Conocimiento basico de que es un agente de IA (LLM-powered agent)

---

## Conceptos clave

### 1. AI Agents On-Chain: el problema

Los agentes de IA (LLM-powered) estan empezando a operar autonomamente: ejecutan transacciones, interactuan con APIs, toman decisiones financieras. Pero hay un problema fundamental de confianza:

```
EL PROBLEMA:

  +----------+                    +----------+
  | Agent A  |  "Soy confiable"  | Agent B  |
  | (claims) |  ----------------> | (como    |
  |          |                    |  verifico?)|
  +----------+                    +----------+

  Sin verificacion on-chain:
  - Cualquiera puede decir que es un agente "bueno"
  - No hay historial verificable
  - No hay accountability
  - No hay mecanismo de reputacion
  - Composabilidad imposible entre agentes

  Con ERC-8004:
  - Identidad verificable (ERC-721)
  - Reputacion acumulada (feedback de clientes)
  - Validacion independiente (validators externos)
  - Composabilidad: agentes leen reputacion de otros agentes
```

### 2. ERC-8004: Trustless Agents

Estandar propuesto por MetaMask, Ethereum Foundation, Google y Coinbase. Define tres registries independientes:

```
ARQUITECTURA ERC-8004:

  +---------------------------------------------------+
  |              Identity Registry (ERC-721)            |
  |                                                     |
  |  Cada agente = 1 NFT                               |
  |  - agentId: identificador unico                    |
  |  - agentURI: apunta a registration file (JSON)     |
  |  - metadata: key-value extensible                  |
  |  - agentWallet: wallet operativa (con firma EIP-712)|
  |  - Transferible (cambio de ownership)              |
  +---------------------------------------------------+
           |                         |
           v                         v
  +--------------------+    +--------------------+
  | Reputation Registry|    | Validation Registry|
  |                    |    |                    |
  | Feedback de        |    | Verificacion por   |
  | clientes           |    | validators         |
  |                    |    | independientes     |
  | - value + decimals |    |                    |
  | - tags (categoria) |    | - request/response |
  | - revocacion       |    | - score 0-100      |
  | - responses        |    | - tags             |
  | - anti-Sybil       |    | - stake/zkML/TEE   |
  | (filtro por client)|    | (incentivos ext.)  |
  +--------------------+    +--------------------+
```

### 3. Agent Registration File

Cada agente tiene un URI que apunta a un archivo JSON con su informacion publica:

```
REGISTRATION FILE (JSON):

{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "Trading Agent Alpha",
  "description": "Autonomous DeFi trading agent",
  "image": "ipfs://Qm.../icon.png",
  "services": [
    {
      "name": "swap-optimizer",
      "endpoint": "https://agent.example.com/swap",
      "version": "2.1.0"
    }
  ],
  "registrations": [
    {
      "agentId": 42,
      "agentRegistry": "eip155:1:0x1234...5678"
    }
  ],
  "supportedTrust": ["reputation", "validation"]
}

CAMPOS OBLIGATORIOS: name, description, image, services
CAMPOS OPCIONALES: active, x402Support, registrations, supportedTrust
```

### 4. Modelos de confianza (Trust Models)

```
TRES MODELOS DE CONFIANZA:

  1. REPUTATION (feedback de clientes)
     +--------+     feedback(+5)      +---------+
     | Client |--------------------->| Agent   |
     +--------+                      | (agentId)|
                                     +---------+
     - Feedback con value/decimals/tags
     - Acumulativo (multiples reviews)
     - Anti-Sybil: getSummary requiere lista de clientes conocidos

  2. CRYPTO-ECONOMIC (stake / slashing)
     +--------+     stake ETH         +---------+
     | Agent  |--------------------->| Staking |
     +--------+                      | Contract|
                                     +---------+
     - Agente deposita colateral
     - Si se porta mal -> slashing
     - Externo a ERC-8004 (solo registra validaciones)

  3. TEE / ZK-ML (verificacion tecnica)
     +--------+     request           +---------+
     | Agent  |--------------------->| Validator|
     +--------+                      | (TEE/zkML)|
         ^                           +---------+
         |     response(score=92)         |
         +--------------------------------+
     - Validator verifica que el agente ejecuta el modelo correcto
     - Score 0-100
     - Independiente del feedback de clientes
```

### 5. A2A Protocol y MCP

```
PROTOCOLOS DE COMUNICACION DE AGENTES:

  A2A (Agent-to-Agent Protocol - Google):
  - Protocolo para que agentes descubran y se comuniquen entre si
  - "Agent Card" = metadata del agente (similar al registration file)
  - Transport: HTTP, WebSocket
  - ERC-8004 complementa A2A con identidad y reputacion on-chain

  MCP (Model Context Protocol - Anthropic):
  - Protocolo para conectar modelos de IA con herramientas y datos
  - "Tools" = funciones que el agente puede llamar
  - Transport: stdio, HTTP
  - ERC-8004 puede registrar endpoints MCP como services

  COMPLEMENTARIEDAD:
  +------------------------------------------+
  |         Capa de comunicacion              |
  |  A2A (agent-to-agent)                    |
  |  MCP (model-to-tools)                    |
  +------------------------------------------+
  |         Capa de confianza (on-chain)      |
  |  ERC-8004 Identity Registry              |
  |  ERC-8004 Reputation Registry            |
  |  ERC-8004 Validation Registry            |
  +------------------------------------------+
  |         Capa de ejecucion                 |
  |  Smart contracts, DeFi protocols          |
  +------------------------------------------+
```

---

## Ejercicio practico: Agent Ecosystem

### Descripcion

Implementa un ecosistema completo de agentes IA on-chain usando ERC-8004. El sistema tiene tres contratos:
1. **AgentRegistry**: Identity Registry (ERC-721) para registro de agentes
2. **AgentReputation**: Reputation Registry para feedback de clientes
3. **AgentValidation**: Validation Registry para verificacion independiente

### Arquitectura

```
+-------------------------------------------------------------------+
|                     Agent Ecosystem (ERC-8004)                      |
|                                                                     |
|  +------------------+                                               |
|  | AgentRegistry    |  (Identity Registry - ERC-721)                |
|  | - register()     |  Mint NFT al registrar agente                |
|  | - setAgentURI()  |  URI -> registration file                    |
|  | - setMetadata()  |  Key-value extensible                        |
|  | - setAgentWallet |  Wallet operativa (EIP-712 verified)         |
|  +--------+---------+                                               |
|           |                                                         |
|    +------+------+                                                  |
|    |             |                                                  |
|    v             v                                                  |
|  +------------------+    +------------------+                       |
|  | AgentReputation  |    | AgentValidation  |                       |
|  | - giveFeedback() |    | - request()      |                       |
|  | - revokeFeedback |    | - response()     |                       |
|  | - appendResponse |    | - getSummary()   |                       |
|  | - getSummary()   |    | - score 0-100    |                       |
|  +------------------+    +------------------+                       |
+-------------------------------------------------------------------+

FLUJO COMPLETO:

  1. Agente se registra: register(uri, metadata) -> agentId (NFT)
  2. Agente configura wallet: setAgentWallet(id, wallet, deadline, sig)
  3. Clientes interactuan y dan feedback: giveFeedback(agentId, +5, ...)
  4. Agente solicita validacion: validationRequest(validator, agentId, ...)
  5. Validator responde: validationResponse(hash, 92, ...)
  6. Otros agentes consultan: getSummary(agentId, clients, tag1, tag2)
```

### Archivos

- `contracts/interfaces/IIdentityRegistry.sol` - Interface Identity Registry
- `contracts/interfaces/IReputationRegistry.sol` - Interface Reputation Registry
- `contracts/interfaces/IValidationRegistry.sol` - Interface Validation Registry
- `contracts/AgentRegistry.sol` - Implementacion Identity Registry
- `contracts/AgentReputation.sol` - Implementacion Reputation Registry
- `contracts/AgentValidation.sol` - Implementacion Validation Registry
- `test/AgentRegistry.t.sol` - Tests del Identity Registry
- `test/AgentReputation.t.sol` - Tests del Reputation Registry
- `test/AgentValidation.t.sol` - Tests del Validation Registry

---

## Como ejecutar

### Paso 0: Inicializar el proyecto Foundry

Si el proyecto no tiene `foundry.toml` ni `lib/` (estado limpio):

```bash
cd developer/12-ai-agents-erc8004

cp README.md README.md.bak
forge init --no-git --force
mv README.md.bak README.md
rm -rf src/ script/
rm -f test/Counter.t.sol

git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std
rm -rf lib/forge-std/.git
```

Edita `foundry.toml`:

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
```

### Paso 1: Compilar y testear

```bash
forge build
forge test -vv
```

### Paso 2: Deploy en Anvil

**Terminal 1: Levantar Anvil**

```bash
anvil
```

**Terminal 2: Configurar variables y desplegar**

```bash
export PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export RPC=http://localhost:8545
```

**1. Desplegar AgentRegistry (Identity Registry - ERC-721):**

```bash
forge create contracts/AgentRegistry.sol:AgentRegistry \
  --rpc-url $RPC \
  --private-key $PK \
  --broadcast \
  --constructor-args "Trustless Agents" "AGENT"
```

Desglose del comando:

```
forge create contracts/AgentRegistry.sol:AgentRegistry
│            │                           │
│            │                           └─ Nombre del contrato (linea 79)
│            └─ Ruta al archivo .sol
└─ Comando de Foundry para desplegar

  --broadcast                 Envia la transaccion a la red (sin esto, solo simula)

  --constructor-args "Trustless Agents" "AGENT"
                     │                  │
                     │                  └─ _symbol (linea 79: string memory _symbol)
                     └─ _name (linea 79: string memory _name)

Ejecuta el constructor (lineas 79-82 de AgentRegistry.sol):
1. Guarda name = "Trustless Agents" (linea 80)
2. Guarda symbol = "AGENT" (linea 81)
   Cada agente registrado sera un NFT (ERC-721) con un agentId unico
```

Del output, copiar `Deployed to:`:

```bash
export REGISTRY=0x...  # Deployed to del output
```

**2. Desplegar AgentReputation (Reputation Registry):**

```bash
forge create contracts/AgentReputation.sol:AgentReputation \
  --rpc-url $RPC \
  --private-key $PK \
  --broadcast \
  --constructor-args $REGISTRY
```

Desglose del comando:

```
  --constructor-args $REGISTRY
                     │
                     └─ _identityRegistry (linea 66: address _identityRegistry)

Ejecuta el constructor (lineas 66-68 de AgentReputation.sol):
1. Guarda identityRegistry = AgentRegistry($REGISTRY) (linea 67)
   Vincula al AgentRegistry para verificar que los agentIds existen
```

```bash
export REPUTATION=0x...  # Deployed to del output
```

**3. Desplegar AgentValidation (Validation Registry):**

```bash
forge create contracts/AgentValidation.sol:AgentValidation \
  --rpc-url $RPC \
  --private-key $PK \
  --broadcast \
  --constructor-args $REGISTRY
```

Desglose del comando:

```
  --constructor-args $REGISTRY
                     │
                     └─ _identityRegistry (linea 58: address _identityRegistry)

Ejecuta el constructor (lineas 58-60 de AgentValidation.sol):
1. Guarda identityRegistry = AgentRegistry($REGISTRY) (linea 59)
   Vincula al AgentRegistry para verificar que los agentIds existen
```

```bash
export VALIDATION=0x...  # Deployed to del output
```

### Paso 3: Flujo completo en Anvil

```bash
# 1. Registrar un agente (mint NFT) -> retorna agentId
cast send $REGISTRY "register(string)" \
  "https://agent.example.com/registration.json" \
  --private-key $PK --rpc-url $RPC

# Verificar agentId = 1
cast call $REGISTRY "totalSupply()(uint256)" --rpc-url $RPC
# 1

# 2. Un cliente da feedback positivo al agente
export CLIENT_PK=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export CLIENT=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

cast send $REPUTATION "giveFeedback(uint256,int256,uint8,bytes32)" \
  1 5 0 0x0000000000000000000000000000000000000000000000000000000000000000 \
  --private-key $CLIENT_PK --rpc-url $RPC

# 3. Un validator solicita validacion
export VALIDATOR_PK=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

cast send $VALIDATION "validationRequest(address,uint256,bytes32)" \
  $DEPLOYER 1 0x0000000000000000000000000000000000000000000000000000000000000000 \
  --private-key $VALIDATOR_PK --rpc-url $RPC
```

---

## Vulnerabilidades relevantes

### 1. Sybil Attacks en Reputacion

```
PROBLEMA:

  Un atacante crea multiples wallets para inflar la reputacion de su agente:

  Atacante
  +--------+  wallet_1 -> giveFeedback(agentId, +10)
  |        |  wallet_2 -> giveFeedback(agentId, +10)
  | Sybil  |  wallet_3 -> giveFeedback(agentId, +10)
  |        |  ...
  +--------+  wallet_n -> 5-star reviews falsos

  MITIGACION EN ERC-8004:
  - getSummary() requiere una lista explicita de clientAddresses
  - El consumidor decide CUALES clientes son confiables
  - Agregacion compleja se hace off-chain (ML, grafos sociales)
  - Complementar con proof-of-personhood o staking

  PATRON ANTI-SYBIL:
  +--------+     "Dame summary de estos 5 clientes"     +---------+
  | DApp   |------------------------------------------>| Reputation|
  | (sabe  |     [addr1, addr2, addr3, addr4, addr5]   | Registry |
  |  cuales|                                            +---------+
  |  son   |     count=4, avgValue=4.2                        |
  |  reales|<-------------------------------------------------+
  +--------+
```

### 2. Agent Impersonation

```
PROBLEMA:

  Un atacante registra un agente con URI y metadata imitando a un agente legitimo:

  +--------+  register("https://fake-agent.com/real-name.json")
  | Fake   |  Metadata dice: "Soy el AgentX oficial"
  | Agent  |  Pero es un scam
  +--------+

  MITIGACION:
  - agentWallet requiere firma EIP-712 del wallet real
  - Verificar que el registration file esta hosteado en dominio oficial
  - Cross-reference con validaciones existentes
  - Verificar agentId especifico, no solo el nombre
```

### 3. Reputation Manipulation via Responses

```
PROBLEMA:

  Un agente recibe feedback negativo y abusa del sistema de responses
  para "enterrar" reviews negativos con respuestas spam:

  Client -> giveFeedback(agentId, -5, "scam")
  Agent  -> appendResponse(... "not true" ...)  x100

  MITIGACION:
  - Las responses no cambian el value del feedback
  - getSummary ignora responses, solo agrega values
  - Off-chain UIs pueden mostrar responses pero sin afectar el score
```

### 4. Validation Collusion

```
PROBLEMA:

  Un agente se valida con un validator que controla:

  +--------+     request        +----------+
  | Agent  |------------------>| Validator |  (mismo owner!)
  | (owner)| <----- 100/100 ---| (collude) |
  +--------+                   +----------+

  MITIGACION:
  - getSummary() requiere lista explicita de validatorAddresses
  - El consumidor decide CUALES validators son confiables
  - Incentivos y slashing son externos al registry
  - Validators reputados tienen mas peso
```

### 5. Agent Wallet Key Compromise

```
PROBLEMA:

  Si la private key del agentWallet es comprometida, el atacante puede
  operar en nombre del agente:

  +--------+     key leaked      +----------+
  | Agent  |                     | Attacker |
  | Wallet |---> private key --->| (opera   |
  +--------+                     |  como    |
                                 |  agente) |
                                 +----------+

  MITIGACION:
  - Owner puede llamar unsetAgentWallet() para revocar
  - Transferir NFT automaticamente limpia el wallet
  - Usar smart contract wallets (ERC-4337) con recovery
  - Monitoreo off-chain de actividad sospechosa
```

---

## Recursos

- [ERC-8004: Trustless Agents](https://eips.ethereum.org/EIPS/eip-8004)
- [A2A Protocol (Google)](https://github.com/google/A2A)
- [Model Context Protocol (Anthropic)](https://modelcontextprotocol.io/)
- [ERC-721: Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [EIP-712: Typed Structured Data Hashing](https://eips.ethereum.org/EIPS/eip-712)
- [ERC-1271: Standard Signature Validation](https://eips.ethereum.org/EIPS/eip-1271)
- [Guia de Estandares ERC](../../shared/erc-standards.md) — Referencia rapida de todos los ERCs relevantes

---

## Checkpoint

Antes de considerar este modulo completado, verifica que puedes:

- [ ] Explicar que problema resuelve ERC-8004 y por que es necesario para AI agents
- [ ] Describir los tres registries: Identity, Reputation, Validation
- [ ] Explicar el formato del Agent Registration File y sus campos obligatorios
- [ ] Describir los tres modelos de confianza: reputacion, cripto-economico, TEE
- [ ] Explicar como A2A y MCP complementan a ERC-8004
- [ ] Explicar el mecanismo anti-Sybil de getSummary (filtro por client list)
- [ ] Describir el flujo de agentWallet con firma EIP-712
- [ ] Tu AgentRegistry compila y pasa todos los tests
- [ ] Tu AgentReputation compila y pasa todos los tests
- [ ] Tu AgentValidation compila y pasa todos los tests
- [ ] Puedes explicar el flujo completo: registrar -> feedback -> validar -> consultar
- [ ] Entiendes las vulnerabilidades: Sybil, impersonation, collusion, key compromise
