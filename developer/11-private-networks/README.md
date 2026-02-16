# Modulo 11: Private Networks (Besu + FireFly)

## Objetivo

Al completar este modulo seras capaz de:

- Entender las diferencias entre redes publicas, privadas y consorcio
- Configurar y levantar una red Hyperledger Besu de 4 nodos con consenso IBFT 2.0
- Desplegar smart contracts en una red privada usando Foundry
- Entender transacciones privadas con Tessera y privacy groups
- Configurar Hyperledger FireFly y usar su API para tokens y messaging
- Identificar vulnerabilidades y riesgos especificos de redes privadas
- Comparar la experiencia de desarrollo entre red publica, privada y local (Anvil)

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (tipos, funciones, storage)
- Modulo 02: Tokens and Standards (ERC-20 basico)
- Docker y Docker Compose instalados y funcionando
- Foundry instalado (`forge`, `cast`, `anvil`)
- (Recomendado) haber completado al menos un deploy en Anvil

---

## Conceptos clave

### 1. Redes publicas vs privadas vs consorcio

```
TIPOS DE REDES BLOCKCHAIN:

  Publica (Ethereum)         Consorcio (Besu IBFT)       Privada (single org)
  +------------------+       +------------------+        +------------------+
  | Cualquiera puede |       | Solo orgs invitadas|       | Una organizacion |
  | leer y escribir  |       | pueden validar    |       | controla todo    |
  |                  |       |                   |        |                  |
  | Permissionless   |       | Permissioned      |       | Permissioned     |
  | PoS consensus    |       | BFT consensus     |       | PoA/BFT          |
  +------------------+       +------------------+        +------------------+

  Descentralizacion ------> Control
  Transparencia     ------> Privacidad

  Ejemplos:
  - Publica: Ethereum mainnet, Sepolia testnet
  - Consorcio: Red bancaria con 4 bancos validando
  - Privada: Sistema de inventario interno de una empresa
```

```
TABLA COMPARATIVA:

+------------------+------------------+------------------+------------------+
| Dimension        | Publica          | Consorcio        | Privada          |
+------------------+------------------+------------------+------------------+
| Quien valida     | Cualquiera       | Nodos autorizados| Nodos internos   |
| Throughput       | ~15-30 TPS       | ~100-1000 TPS   | ~1000+ TPS       |
| Finality         | ~12s + confirms  | ~2s (inmediata)  | ~2s (inmediata)  |
| Gas              | Mercado ($$)     | Configurable     | Cero/nominal     |
| Privacidad       | Todo publico     | Selectiva        | Total            |
| Ideal para       | DeFi, NFTs,      | Supply chain,    | Registros        |
|                  | identidad abierta| trade finance    | internos         |
+------------------+------------------+------------------+------------------+
```

### 2. Hyperledger Besu

Besu es un cliente Ethereum open-source mantenido por Hyperledger (Linux Foundation). Ejecuta la EVM, lo que significa que **todo lo que funciona en Ethereum funciona en Besu**: Solidity, Foundry, OpenZeppelin, etc.

```
BESU NODE ARCHITECTURE:

  +----------------------------------------------------------+
  |                      Besu Node                            |
  |                                                           |
  |  +------------------+                                     |
  |  | JSON-RPC API     |  <-- Mismo API que Ethereum         |
  |  | eth_, net_, web3_|      (Foundry, MetaMask, etc.)      |
  |  | ibft_ (extra)    |                                     |
  |  +--------+---------+                                     |
  |           |                                               |
  |  +--------+---------+  +------------------+               |
  |  | EVM Execution    |  | Consensus Engine |               |
  |  | (igual que ETH)  |  | IBFT 2.0         |               |
  |  +------------------+  +------------------+               |
  |                                                           |
  |  +------------------+                                     |
  |  | P2P Network      |  <-- Conecta con otros nodos Besu  |
  |  +------------------+                                     |
  +----------------------------------------------------------+
```

### 3. Consenso IBFT 2.0 (Istanbul BFT)

IBFT 2.0 es un protocolo de consenso Byzantine Fault Tolerant. Garantiza que la red funcione correctamente incluso si hasta 1/3 de los nodos son maliciosos o estan caidos.

```
IBFT 2.0 CONSENSUS FLOW:

  4 nodos validators (tolera 1 fallo):

  Round N:
  1. Node A (proposer, rotativo) propone bloque
     +----------+
     | Node A   |  --> "Propongo bloque #42"
     | PROPOSER |
     +----------+
          |
          v  PRE-PREPARE (broadcast)
          |
  2. Los otros validators verifican y responden PREPARE
     +----------+   +----------+   +----------+
     | Node B   |   | Node C   |   | Node D   |
     +----------+   +----------+   +----------+
     "Bloque OK"    "Bloque OK"    "Bloque OK"
          |              |              |
          v              v              v
  3. Al recibir 2/3 PREPARE -> envian COMMIT
          |
          v
  4. Con 2/3+1 COMMIT recibidos:
     BLOQUE FINALIZADO (inmediato, sin forks posibles)

  Formula: N >= 3f + 1
  4 nodos -> tolera 1 fallo
  7 nodos -> tolera 2 fallos
```

### 4. Transacciones privadas (Tessera)

Besu soporta transacciones privadas mediante Tessera, un manager que encripta y distribuye payloads solo a los participantes autorizados.

```
PRIVATE TRANSACTION FLOW:

  Org A quiere enviar tx privada a Org B (Org C y D no ven el contenido):

  +----------+     Payload       +----------+
  | Org A    | ----------------> | Tessera A|
  | (sender) |  "transfer 100"  | (encripta)|
  +----------+                   +----+-----+
                                      |
                                      v
                  +----------+   +----------+
                  | Tessera B|   | Tessera C|
                  | RECIBE   |   | NO recibe|
                  | payload  |   | payload  |
                  +----------+   +----------+

  En la blockchain del consorcio:
  - Todos ven que hubo una transaccion (hash)
  - Solo Org A y Org B ven el contenido
  - El estado resultante solo existe en Org A y Org B
```

### 5. Hyperledger FireFly

FireFly es una plataforma que simplifica la construccion de aplicaciones multiparty. En vez de escribir integracion directa con Besu, usas APIs REST.

```
FIREFLY SIMPLIFICA:

  Sin FireFly:                     Con FireFly:
  =============                    ===========
  - Manejar nonces                 POST /api/v1/tokens/transfer
  - Encodear ABI calls             POST /api/v1/messages/broadcast
  - Manejar eventos                GET  /api/v1/events (WebSocket)
  - Retry logic
  - Error handling                 FireFly maneja TODO eso internamente
  - Idempotency
```

---

## Ejercicio practico: Red Besu + Smart Contracts + FireFly

### Parte 1: Levantar red Besu (4 nodos IBFT 2.0)

```bash
# 1. Ir al directorio de docker
cd developer/11-private-networks/docker

# 2. Levantar la red
docker-compose up -d

# 3. Verificar que los 4 nodos estan corriendo
docker-compose ps

# 4. Verificar que la red produce bloques
curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" \
  http://localhost:8545

# 5. Verificar validators
curl -s -X POST --data '{"jsonrpc":"2.0","method":"ibft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" \
  http://localhost:8545

# 6. Verificar peers
curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  -H "Content-Type: application/json" \
  http://localhost:8545
# Deberia retornar 3 (cada nodo ve a los otros 3)
```

### Parte 2: Desplegar SimpleToken.sol

```bash
# 1. Compilar contratos (desde el root del modulo)
cd developer/11-private-networks
forge build

# 2. Ejecutar tests en local primero
forge test -vvv

# 3. Desplegar a la red Besu
# La cuenta pre-fondeada del genesis tiene esta private key:
# 0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3
forge create contracts/SimpleToken.sol:SimpleToken \
  --constructor-args "PrivateToken" "PVTK" 1000000000000000000000000 \
  --rpc-url http://localhost:8545 \
  --private-key 0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3

# 4. Verificar el deploy
cast call $TOKEN_ADDRESS "name()(string)" --rpc-url http://localhost:8545
cast call $TOKEN_ADDRESS "symbol()(string)" --rpc-url http://localhost:8545
cast call $TOKEN_ADDRESS "totalSupply()(uint256)" --rpc-url http://localhost:8545

# 5. Transferir tokens
cast send $TOKEN_ADDRESS "transfer(address,uint256)" \
  0x0000000000000000000000000000000000000001 1000000000000000000 \
  --rpc-url http://localhost:8545 \
  --private-key 0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3
```

### Parte 3: Configurar FireFly

```bash
# 1. Instalar FireFly CLI
# (requiere Go 1.21+)
go install github.com/hyperledger/firefly-cli/ff@latest

# 2. Crear stack con Besu
ff init my-stack \
  --blockchain-provider ethereum \
  --blockchain-connector ethconnect \
  --blockchain-node besu

# 3. Levantar
ff start my-stack

# 4. Verificar
ff info my-stack
# Abre el FireFly Explorer (UI) en el URL indicado

# 5. Crear un token pool via API
curl -X POST http://localhost:5000/api/v1/tokens/pools \
  -H "Content-Type: application/json" \
  -d '{"name":"consortium-token","type":"fungible"}'

# 6. Mintear tokens
curl -X POST http://localhost:5000/api/v1/tokens/mint \
  -H "Content-Type: application/json" \
  -d '{"pool":"consortium-token","amount":"1000"}'

# 7. Enviar mensaje broadcast
curl -X POST http://localhost:5000/api/v1/messages/broadcast \
  -H "Content-Type: application/json" \
  -d '{"data":[{"value":"Hello from the consortium!"}]}'

# 8. Ver mensajes recibidos
curl http://localhost:5000/api/v1/messages
```

### Parte 4: Transacciones privadas (conceptual)

El contrato `PrivateGreeter.sol` ilustra el concepto de datos que solo deben ser visibles para participantes especificos. En un entorno Besu con Tessera configurado:

```bash
# Desplegar como transaccion privada (requiere Tessera configurado)
# Este comando es conceptual - requiere stack completo con Tessera
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "eea_sendRawTransaction",
    "params": ["SIGNED_TX_WITH_PRIVACY_GROUP"],
    "id": 1
  }'

# Solo los nodos en el privacy group pueden:
# - Ver el contenido de la transaccion
# - Leer el estado del contrato
# - Interactuar con el contrato
```

> **Nota**: configurar Tessera completo requiere keys y un stack mas elaborado. El ejercicio principal (Partes 1-3) funciona sin Tessera. La Parte 4 es conceptual para entender el modelo.

---

## Vulnerabilidades relevantes

### 1. Colusion de validators

```
PROBLEMA:

  En IBFT 2.0 con 4 nodos, si 2 nodos colucionan:
  - Pueden censurar transacciones (no incluirlas en bloques)
  - Pueden manipular el orden de transacciones
  - NO pueden crear transacciones falsas (necesitan 3 de 4)

  +----------+   +----------+   +----------+   +----------+
  | Node A   |   | Node B   |   | Node C   |   | Node D   |
  | HONESTO  |   | MALICIOSO|   | MALICIOSO|   | HONESTO  |
  +----------+   +----------+   +----------+   +----------+

  Con 2 de 4 maliciosos, NO se cumple N >= 3f + 1 (4 >= 3*2+1 = 7, FALSO)
  La red puede detenerse (no puede alcanzar consenso).

  MITIGACION:
  - Mas validators (7+ para tolerar 2 fallos)
  - Monitoreo de comportamiento de validators
  - Acuerdos legales entre miembros del consorcio
  - Rotacion de proposer para detectar censura
```

### 2. Metadata leakage en transacciones privadas

```
PROBLEMA:

  Aunque el contenido de una tx privada esta encriptado,
  la metadata es visible para todos los nodos:

  Visible para todos:
  - Que hubo una transaccion privada (hash)
  - Timestamp
  - Quien la envio (address del sender)
  - Tamano aproximado del payload

  Esto permite inferir:
  - Patrones de actividad entre organizaciones
  - Frecuencia de interaccion
  - Tamano de operaciones

  MITIGACION:
  - Traffic padding (transacciones dummy)
  - Batching de transacciones
  - Routing indirecto
```

### 3. API sin autenticacion

```
PROBLEMA:

  Por defecto, Besu expone JSON-RPC sin autenticacion.
  Cualquiera con acceso a la red puede:
  - Enviar transacciones
  - Leer el estado de contratos
  - Proponer cambios de validators

  MITIGACION:
  - Habilitar autenticacion JWT en Besu
  - Firewall: restringir acceso al puerto RPC
  - TLS para comunicacion entre nodos
  - NUNCA exponer JSON-RPC a internet sin auth

  Configuracion:
  --rpc-http-authentication-enabled=true
  --rpc-http-authentication-jwt-public-key-file=<path>
```

### 4. Genesis file expuesto

```
PROBLEMA:

  El genesis.json contiene:
  - Chain ID
  - Cuentas pre-fondeadas y sus balances
  - Configuracion de consenso

  En este repositorio, las claves en genesis.json son de EJEMPLO.
  NUNCA usar las mismas claves en un entorno real.

  MITIGACION:
  - Generar nuevas claves para cada red
  - No commitear claves privadas reales
  - Usar secret management (Vault, AWS Secrets Manager)
```

---

## Recursos

- [Hyperledger Besu Documentation](https://besu.hyperledger.org)
- [Besu Private Networks Tutorial](https://besu.hyperledger.org/private-networks/tutorials)
- [IBFT 2.0 Consensus](https://besu.hyperledger.org/private-networks/how-to/configure/consensus/ibft)
- [Hyperledger FireFly Documentation](https://hyperledger.github.io/firefly)
- [FireFly CLI Quick Start](https://hyperledger.github.io/firefly/gettingstarted)
- [Foundry Book](https://book.getfoundry.sh/)
- [Genesis File Configuration](https://besu.hyperledger.org/private-networks/reference/genesis-items)
- [Tessera Documentation](https://docs.tessera.consensys.net)

---

## Checkpoint

Antes de continuar, verifica que puedes:

- [ ] Explicar las diferencias entre red publica, consorcio y privada
- [ ] Describir como funciona el consenso IBFT 2.0 (pre-prepare, prepare, commit)
- [ ] Calcular cuantos fallos tolera una red IBFT 2.0 dado N validators
- [ ] Levantar la red Besu de 4 nodos con docker-compose
- [ ] Desplegar un contrato ERC-20 en la red Besu usando Foundry
- [ ] Interactuar con el contrato desplegado usando `cast`
- [ ] Explicar como funcionan las transacciones privadas con Tessera
- [ ] Describir que hace FireFly y como simplifica el desarrollo multiparty
- [ ] Identificar los riesgos de seguridad en redes privadas (colusion, metadata leak, API sin auth)
- [ ] Todos los tests pasan con `forge test`
