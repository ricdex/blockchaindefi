# Modulo 10: Enterprise Blockchain

## Objetivo

Al completar este modulo seras capaz de:

- Evaluar cuando usar una blockchain privada/consorcio vs una red publica
- Comprender la arquitectura de Hyperledger Besu: nodos, consenso modular, permissioning
- Disenar redes consorcio con IBFT 2.0 y QBFT para diferentes escenarios enterprise
- Entender transacciones privadas con Tessera y privacy groups
- Conocer Hyperledger FireFly como plataforma de orquestacion multiparty
- Disenar arquitecturas hibridas: ejecucion privada + settlement publico
- Aplicar patrones enterprise: supply chain, trade finance, DID corporativo

---

## Prerequisitos

- Modulos 01 a 06 del architect path (consenso, protocolos, seguridad, escalabilidad, cross-chain)
- Modulo 07: Identity and Compliance (DID, KYC, regulacion)
- Entendimiento basico de Docker y networking
- Familiaridad con conceptos enterprise: SLA, governance, compliance
- (Recomendado) developer/11-private-networks para experiencia practica con Besu

---

## Conceptos clave

### 1. Blockchain privada vs publica vs consorcio

```
   ESPECTRO DE BLOCKCHAINS
   ========================

   Publica                Consorcio               Privada
   (permissionless)       (permissioned)          (permissioned)
   +------------------+   +------------------+    +------------------+
   | Cualquiera puede |   | N organizaciones |    | Una organizacion |
   | participar       |   | pre-aprobadas    |    | controla todo    |
   |                  |   | controlan la red |    |                  |
   | Ethereum, Bitcoin|   | Besu IBFT 2.0    |    | Besu single-org  |
   +------------------+   +------------------+    +------------------+

   Descentralizacion    <---------------------------->    Control
   Resistencia censura  <---------------------------->    Privacidad
   Transparencia        <---------------------------->    Compliance
```

```
+---------------------+------------------+------------------+------------------+
| Dimension           | Publica          | Consorcio        | Privada          |
+---------------------+------------------+------------------+------------------+
| Acceso              | Abierto          | Invitacion       | Controlado       |
| Validators          | Cualquiera       | Pre-aprobados    | Internos         |
| Consenso            | PoS/PoW          | BFT (IBFT/QBFT) | BFT/PoA          |
| Throughput          | ~15-30 TPS       | ~100-1000 TPS   | ~1000+ TPS       |
| Finality            | Probabilistica   | Inmediata        | Inmediata        |
| Gas cost            | Mercado ($$)     | Bajo/configurable| Cero/nominal     |
| Privacidad txs      | Publica          | Selectiva        | Total            |
| Gobernanza          | On-chain/social  | Acuerdo consorcio| Unilateral       |
| Compliance          | Dificil          | Configurable     | Total control    |
| Trust model         | Trustless        | Trust entre pares| Trust interna    |
| Casos de uso        | DeFi, NFTs,      | Supply chain,    | Registro interno |
|                     | tokens publicos  | trade finance    | auditable        |
+---------------------+------------------+------------------+------------------+
```

**Cuando usar cada tipo**:

```
   Decision tree:
   ==============

   Necesitas transparencia publica?
       SI --> Blockchain PUBLICA (Ethereum)
       NO --> Necesitas multiples organizaciones?
                 SI --> CONSORCIO (Besu IBFT 2.0)
                 NO --> PRIVADA (Besu single-org)
                         Realmente necesitas blockchain?
                              NO --> Base de datos inmutable (TimescaleDB, etc.)
```

---

### 2. Hyperledger Besu - Arquitectura

Besu es un cliente Ethereum escrito en Java, mantenido por la Linux Foundation (Hyperledger). Ejecuta la EVM y soporta tanto redes publicas como privadas.

#### 2.1 Componentes de un nodo Besu

```
   NODO BESU
   ==========

   +----------------------------------------------------------+
   |                      Besu Node                            |
   |                                                           |
   |  +------------------+  +------------------+               |
   |  | JSON-RPC API     |  | GraphQL API      |               |
   |  | (eth, net, web3, |  | (queries)        |               |
   |  |  ibft, priv)     |  |                  |               |
   |  +--------+---------+  +--------+---------+               |
   |           |                      |                        |
   |  +--------+---------+           |                        |
   |  | Transaction Pool |           |                        |
   |  +--------+---------+           |                        |
   |           |                      |                        |
   |  +--------+----------------------+---------+              |
   |  |              EVM Execution              |              |
   |  +--------+--------------------------------+              |
   |           |                                               |
   |  +--------+---------+  +------------------+               |
   |  | World State      |  | Consensus Engine |               |
   |  | (RocksDB)        |  | IBFT 2.0 / QBFT |               |
   |  +------------------+  | / Clique / Ethash|               |
   |                        +------------------+               |
   |                                                           |
   |  +------------------+                                     |
   |  | P2P Network      |  <-- Comunicacion con otros nodos   |
   |  | (devp2p)         |                                     |
   |  +------------------+                                     |
   +----------------------------------------------------------+
            |
            | (opcional, para txs privadas)
            v
   +------------------+
   |    Tessera        |
   | Private Tx Mgr   |
   +------------------+
```

#### 2.2 Consenso modular

Besu soporta multiples mecanismos de consenso:

```
+----------+--------------------+-------------------+-------------------+
| Consenso | Tolerancia fallas  | Finality          | Uso tipico        |
+----------+--------------------+-------------------+-------------------+
| IBFT 2.0 | Hasta 1/3 nodos    | Inmediata         | Consorcio prod    |
|          | bizantinos         |                   |                   |
+----------+--------------------+-------------------+-------------------+
| QBFT     | Hasta 1/3 nodos    | Inmediata         | Consorcio prod    |
|          | bizantinos         |                   | (sucesor de IBFT) |
+----------+--------------------+-------------------+-------------------+
| Clique   | Hasta 1/2 nodos    | ~N/2 bloques      | Dev/test          |
|          | (crash only)       |                   |                   |
+----------+--------------------+-------------------+-------------------+
| Ethash   | 51% hash power     | Probabilistica    | Red publica       |
|          |                    |                   | (legacy)          |
+----------+--------------------+-------------------+-------------------+
```

#### 2.3 IBFT 2.0 en detalle

```
   IBFT 2.0 CONSENSUS FLOW
   =========================

   Ronda N:

   1. PROPOSER (rotativo) propone bloque
      +----------+
      | Node A   |  --> Propone bloque B_n
      | PROPOSER |
      +----------+
           |
           v  Broadcast PRE-PREPARE
           |
   2. Todos los validators verifican y envian PREPARE
      +----------+   +----------+   +----------+
      | Node B   |   | Node C   |   | Node D   |
      | VALIDATOR|   | VALIDATOR|   | VALIDATOR|
      +----------+   +----------+   +----------+
           |              |              |
           v              v              v
      Envian PREPARE si el bloque es valido
           |
   3. Al recibir 2/3 PREPARE, envian COMMIT
           |
           v
      +------------------------------------------+
      | Si 2/3+1 COMMIT recibidos:               |
      |   -> Bloque FINALIZADO (inmutable)        |
      |   -> No hay forks posibles                |
      | Si timeout sin quorum:                    |
      |   -> Round change, nuevo proposer         |
      +------------------------------------------+

   Tolerancia: N >= 3f + 1
   (4 nodos tolera 1 fallo, 7 tolera 2, 10 tolera 3)
```

---

### 3. Permissioning

Besu ofrece dos niveles de control de acceso a la red:

#### 3.1 Node permissioning

```
   NODE PERMISSIONING
   ====================

   Controla que nodos pueden conectarse a la red.

   +----------------------------------------------------------+
   |  Mecanismos:                                              |
   |                                                           |
   |  1. Local (archivo de config):                            |
   |     permissions-nodes-config-file-enabled=true            |
   |     Lista estatica de enode URLs permitidos               |
   |                                                           |
   |  2. On-chain (smart contract):                            |
   |     NodeIngress contract                                  |
   |     Permite agregar/remover nodos via transacciones       |
   |     Gobernado por admins del consorcio                    |
   +----------------------------------------------------------+

   Nodo no autorizado intenta conectar:
   +----------+                        +----------+
   | Nodo X   | ----> Conexion P2P --> | Nodo A   |
   | (no auth)|                        | (auth)   |
   +----------+                        +----------+
        |                                    |
        X <---- RECHAZADO ---- Verifica allowlist
```

#### 3.2 Account permissioning

```
   ACCOUNT PERMISSIONING
   ======================

   Controla que accounts pueden enviar transacciones.

   +----------------------------------------------------------+
   |  Mecanismos:                                              |
   |                                                           |
   |  1. Local: lista de accounts permitidas                   |
   |  2. On-chain: AccountIngress smart contract               |
   |     - Whitelist de accounts                               |
   |     - Puede restringir por tipo de transaccion            |
   |     - Gobernado por admins                                |
   +----------------------------------------------------------+
```

---

### 4. Transacciones privadas (Tessera)

```
   PRIVATE TRANSACTION FLOW
   =========================

   Participantes: Org A, Org B (en privacy group)
   Observadores: Org C, Org D (NO ven el payload)

   1. Org A envia tx privada
   +----------+     Payload       +----------+
   | Org A    | ----------------> | Tessera A|
   | (sender) |  "transferir 100 | (encripta|
   +----------+   tokens a B"    |  y envia)|
                                  +----+-----+
                                       |
   2. Tessera distribuye              |
                                       v
                   +----------+   +----------+
                   | Tessera B|   | Tessera C|
                   | (recibe) |   | (NO rec.)|
                   +----------+   +----------+

   3. En la blockchain publica del consorcio:
   +----------------------------------------------------------+
   |  Bloque N:                                                |
   |  tx_hash: 0xABC...  (el hash es publico)                 |
   |  payload: HASH_ONLY  (el contenido NO es publico)        |
   |                                                           |
   |  Solo Org A y Org B pueden ver:                           |
   |  - El contenido real de la transaccion                    |
   |  - El estado resultante                                   |
   |                                                           |
   |  Org C y Org D ven:                                       |
   |  - Que hubo una tx privada (hash)                         |
   |  - NO ven el contenido ni el resultado                    |
   +----------------------------------------------------------+
```

---

### 5. Hyperledger FireFly

FireFly es una plataforma de orquestacion que abstrae la complejidad de aplicaciones multiparty sobre blockchain.

#### 5.1 Arquitectura FireFly

```
   FIREFLY STACK
   ==============

   +----------------------------------------------------------+
   |                    FireFly Core                            |
   |                                                           |
   |  +------------------+  +------------------+               |
   |  | REST API         |  | Event Streams    |               |
   |  | - Tokens         |  | - WebSocket      |               |
   |  | - Messages       |  | - Webhooks       |               |
   |  | - Data           |  |                  |               |
   |  | - Organizations  |  |                  |               |
   |  +--------+---------+  +--------+---------+               |
   |           |                      |                        |
   |  +--------+----------------------+---------+              |
   |  |           Plugin Architecture           |              |
   |  +--------+--------------------------------+              |
   |           |              |              |                  |
   |  +--------+----+ +------+------+ +-----+------+          |
   |  | Blockchain  | | Shared Data | | Identity   |          |
   |  | Connector   | | Exchange    | | Manager    |          |
   |  | (ethconnect)| | (IPFS/S3)  | |            |          |
   |  +------+------+ +------+------+ +------+-----+          |
   +---------|---------------|---------------|------------------+
             |               |               |
             v               v               v
   +----------+     +----------+     +----------+
   | Besu /   |     | IPFS /   |     | DID      |
   | Ethereum |     | Cloud    |     | Registry |
   +----------+     | Storage  |     +----------+
                    +----------+
```

#### 5.2 Capacidades principales

```
+---------------------+--------------------------------------------------+
| Capacidad           | Descripcion                                      |
+---------------------+--------------------------------------------------+
| Token management    | Crear, transferir y quemar tokens (fungibles y   |
|                     | no-fungibles) via API REST                       |
+---------------------+--------------------------------------------------+
| Messaging           | Enviar mensajes on-chain y off-chain entre       |
|                     | organizaciones con confirmacion de entrega       |
+---------------------+--------------------------------------------------+
| Data exchange       | Compartir datos estructurados con hash on-chain  |
|                     | y payload off-chain (IPFS, S3, etc.)             |
+---------------------+--------------------------------------------------+
| Organization ID     | Registro de organizaciones con DID, claims y     |
|                     | verificacion mutua entre participantes           |
+---------------------+--------------------------------------------------+
| Event streams       | Suscripcion a eventos blockchain con delivery    |
|                     | garantizado (at-least-once) via WebSocket/webhook|
+---------------------+--------------------------------------------------+
| Custom contracts    | Deploy y invocacion de smart contracts custom    |
|                     | con ABI management automatico                    |
+---------------------+--------------------------------------------------+
```

#### 5.3 FireFly vs escribir integracion directa

```
   Sin FireFly:                        Con FireFly:
   ============                        ===========

   App A ─┐                            App A ─┐
          ├─ Besu RPC                          ├─ FireFly REST API
   App B ─┤  + IPFS API                App B ─┤  (unificada)
          ├─ Custom event listener             ├─
   App C ─┘  + Identity management     App C ─┘
          + Error handling
          + Retry logic                FireFly maneja:
          + Idempotency               - Blockchain interaction
          + Nonce management           - Data storage
                                       - Event delivery
   Cada app reimplementa               - Nonce management
   la misma logica                     - Idempotency
                                       - Organization identity
```

---

### 6. Patrones enterprise

#### 6.1 Supply chain

```
   TRAZABILIDAD SUPPLY CHAIN
   ==========================

   Manufacturer        Logistics          Distributor        Retailer
   +----------+        +----------+       +----------+       +----------+
   | Crea     |  tx    | Registra |  tx   | Verifica |  tx   | Vende    |
   | producto |------->| envio    |------>| recepcion|------>| al       |
   | token ID |        | updates  |       | calidad  |       | cliente  |
   +----------+        +----------+       +----------+       +----------+
        |                   |                  |                  |
        v                   v                  v                  v
   +-------------------------------------------------------------|----+
   |                   Besu Consortium (IBFT 2.0)                      |
   |                                                                    |
   |  Smart Contract: SupplyChainTracker                               |
   |  - registerProduct(id, metadata)                                   |
   |  - updateStatus(id, status, location, timestamp)                  |
   |  - transferCustody(id, from, to)                                  |
   |  - getHistory(id) -> Event[]                                      |
   |                                                                    |
   |  Datos sensibles (precios, contratos):                            |
   |  -> Transacciones privadas entre partes involucradas              |
   |                                                                    |
   |  Datos publicos (ubicacion, status):                              |
   |  -> Transacciones normales (visibles a todo el consorcio)         |
   +--------------------------------------------------------------------+
```

#### 6.2 Trade finance

```
   LETTER OF CREDIT - BLOCKCHAIN
   ==============================

   Buyer            Buyer's Bank       Seller's Bank       Seller
   +------+         +----------+       +----------+        +------+
   |      | 1.Apply |          |2.Issue|          |3.Advise|      |
   |      |-------->|          |------>|          |------->|      |
   |      |         |          |       |          |        |      |
   |      |         |          |       |          |4.Ship  |      |
   |      |         |          |       |          |<-------|      |
   |      |         |          |  5.Present docs  |        |      |
   |      |         |   6.Verify & Pay            |        |      |
   |      |         |<--------------------------->|        |      |
   +------+         +----------+       +----------+        +------+

   En blockchain consorcio:
   - Smart contract gestiona el ciclo de vida del LC
   - Documentos hasheados on-chain, originales off-chain
   - Pagos automaticos al cumplir condiciones
   - Auditoria completa e inmutable
   - Privacidad: solo partes involucradas ven detalles financieros
```

#### 6.3 DID enterprise

```
   DID EN RED PRIVADA
   ====================

   Patron: Anchoring hibrido

   RED PRIVADA (Besu consorcio)         RED PUBLICA (Ethereum/L2)
   +---------------------------+        +---------------------------+
   | DID Registry completo     |        | Merkle root periodico     |
   | - DID Documents           |        | del estado DID            |
   | - Credential status       |        |                           |
   | - Revocation lists        |        | Verificable por cualquiera|
   | - Full resolution         |        | sin acceso a red privada  |
   +---------------------------+        +---------------------------+
              |                                    ^
              | Periodicamente                     |
              +--- Calcula merkle root ----------->+
              |    del estado actual
              |
   Ventajas:
   - Operaciones rapidas y baratas en red privada
   - Verificacion publica via merkle proof
   - Privacidad de datos sensibles
   - Compliance con regulaciones enterprise
```

---

### 7. Arquitecturas hibridas

El patron mas poderoso combina blockchain privada y publica:

```
   ARQUITECTURA HIBRIDA
   =====================

   Capa Privada (Besu consorcio)        Capa Publica (Ethereum/L2)
   ================================     ================================
   | Ejecucion de logica de negocio|     | Settlement y verificacion    |
   | - Alta throughput (~500 TPS)  |     | - Finality publica           |
   | - Gas gratis/nominal          |     | - Transparencia              |
   | - Transacciones privadas      |     | - Interop con DeFi           |
   | - Compliance total            |     | - Resistencia a censura      |
   ================================     ================================
              |                                    ^
              | Anchoring periodico:               |
              | - State roots                      |
              | - Merkle proofs                    |
              | - Settlement de tokens             |
              +------------------------------------>

   Casos de uso:
   +----------------------------------------------------------+
   | 1. Token privado con bridge a L2:                        |
   |    - Emision y transferencias en red privada             |
   |    - Lock & mint en L2 para trading publico              |
   |                                                           |
   | 2. DID privado con verificacion publica:                 |
   |    - Registro completo en red privada                    |
   |    - Merkle root en L2 para verificacion externa         |
   |                                                           |
   | 3. Supply chain con certificacion publica:               |
   |    - Tracking interno en red privada                     |
   |    - Certificados de origen verificables on-chain        |
   +----------------------------------------------------------+
```

---

## Ejercicio de diseno

### Disenar un sistema de trazabilidad supply chain para 4 organizaciones

**Escenario**: Cuatro organizaciones (Fabricante, Transportista, Distribuidor, Retailer) necesitan un sistema compartido de trazabilidad de productos. Cada organizacion debe poder:
- Registrar eventos sobre productos que pasan por sus manos
- Ver el historial completo de productos
- Mantener datos comerciales privados (precios, contratos, margenes)
- Proporcionar certificados verificables al consumidor final

**Requisitos**:
1. Datos de trazabilidad visibles a todo el consorcio
2. Datos comerciales privados entre las partes involucradas en cada transaccion
3. Certificados de origen verificables publicamente (sin necesidad de acceso al consorcio)
4. Incorporacion de nuevos miembros al consorcio sin disrupcion
5. Tolerancia a la falla de 1 organizacion (la red sigue funcionando)
6. Cumplimiento con regulaciones de trazabilidad alimentaria (ej: EU Food Safety)

**Entregables del ejercicio** (documento de diseno):

1. **Topologia de red**:
   - Cuantos nodos por organizacion y por que
   - Mecanismo de consenso elegido y configuracion
   - Diagrama de red con nodos, Tessera, y conectividad

2. **Modelo de datos**:
   - Smart contracts: que datos van on-chain
   - Datos off-chain: que se almacena fuera y donde (IPFS, base de datos, FireFly)
   - Privacy groups: que transacciones son privadas y entre quienes

3. **Flujo de operacion**:
   - Paso a paso: un producto desde fabricacion hasta venta
   - Que transacciones se ejecutan en cada etapa
   - Como se gestionan las transacciones privadas (precios, contratos)

4. **Verificacion publica**:
   - Como un consumidor verifica el origen de un producto
   - Anchoring a red publica: que datos, con que frecuencia
   - QR code -> verificacion: diagrama de flujo

5. **Gobernanza del consorcio**:
   - Como se agregan nuevos miembros
   - Como se resuelven disputas
   - Como se actualizan smart contracts
   - Voting mechanism para cambios en la red

6. **Seguridad y compliance**:
   - Threat model: que puede salir mal
   - Permissioning: nodos y accounts
   - Backup y disaster recovery
   - Cumplimiento regulatorio

---

## Trade-offs y decisiones

### Centralizacion vs Control

```
+---------------------+-------------------+-------------------+
|                     | Red publica       | Red consorcio     |
+---------------------+-------------------+-------------------+
| Confianza requerida | Ninguna (trustless)| Entre miembros   |
| Censura posible     | Muy dificil       | Si (mayoria)     |
| Punto de falla      | Ninguno central   | Consorcio mismo  |
| Throughput          | Limitado          | Configurable     |
| Regulacion          | Dificil cumplir   | Facil cumplir    |
+---------------------+-------------------+-------------------+

Pregunta clave: Confias en los otros miembros del consorcio?
Si NO -> red publica o hibrida
Si SI -> consorcio puro es suficiente
```

### Privacidad vs Transparencia

```
Todo publico:
+ Simple, auditable, composable
- No viable para datos comerciales sensibles

Todo privado:
+ Control total de datos
- No verificable externamente, pierde beneficio de blockchain

Hibrido (recomendado para enterprise):
+ Datos sensibles privados, certificaciones publicas
+ Verificable externamente via merkle proofs
- Mayor complejidad de arquitectura
```

### Throughput vs Descentralizacion

```
Mas validators:
+ Mas descentralizado, mas resiliente
- Mas latencia en consenso, menos throughput

Menos validators:
+ Mas rapido, mas throughput
- Mas centralizado, menos resiliente

IBFT 2.0 sweet spots:
- 4 validators: tolera 1 fallo, buena performance
- 7 validators: tolera 2 fallos, balance optimo
- 10+ validators: alta resiliencia, menor throughput
```

### Besu vs Fabric vs Corda

```
+------------------+------------------+------------------+------------------+
| Dimension        | Besu             | Fabric           | Corda            |
+------------------+------------------+------------------+------------------+
| Modelo ejecucion | EVM              | Chaincode (Go/JS)| JVM (Kotlin)     |
| Smart contracts  | Solidity (EVM)   | Go/JavaScript    | Kotlin/Java      |
| Consenso         | IBFT/QBFT/Clique | Raft/BFT         | Notary-based     |
| Privacidad       | Tessera (groups) | Channels/PDC     | Por defecto      |
| Interop publico  | Nativa (EVM)     | Limitada         | Limitada         |
| Tooling Ethereum | Compatible       | Ecosistema propio| Ecosistema propio|
| Tokenizacion     | ERC standards    | Custom           | Custom           |
+------------------+------------------+------------------+------------------+

Cuando elegir Besu:
- Ya tienes conocimiento de Ethereum/Solidity
- Necesitas interoperabilidad con redes publicas Ethereum
- Quieres usar tooling existente (Foundry, Hardhat, OpenZeppelin)
- Tokenizacion es un requisito (ERC-20, ERC-721 funcionan nativamente)
```

---

## Recursos

### Hyperledger Besu
- Besu Documentation: besu.hyperledger.org
- Besu GitHub: github.com/hyperledger/besu
- IBFT 2.0 Specification: eips.ethereum.org/EIPS/eip-650
- Besu Private Transactions: besu.hyperledger.org/private-networks/concepts/privacy

### Hyperledger FireFly
- FireFly Documentation: hyperledger.github.io/firefly
- FireFly GitHub: github.com/hyperledger/firefly
- FireFly CLI: github.com/hyperledger/firefly-cli

### Enterprise blockchain
- Enterprise Ethereum Alliance: entethalliance.org
- "Blockchain for Enterprise" - Hyperledger Foundation
- "Enterprise Blockchain Patterns" - AWS Whitepaper

### Papers y standards
- EEA Client Specification
- IBFT 2.0 Consensus Protocol
- "Performance Analysis of IBFT 2.0" - IEEE
- ISO/TC 307 Blockchain Standards

---

## Checkpoint

Antes de considerar este modulo completo, verifica que puedes:

- [ ] Explicar cuando usar blockchain publica vs consorcio vs privada con criterios claros
- [ ] Describir la arquitectura de un nodo Besu y sus componentes principales
- [ ] Explicar el flujo de consenso IBFT 2.0: pre-prepare, prepare, commit, round change
- [ ] Calcular la tolerancia a fallas de una red IBFT 2.0 dado el numero de validators
- [ ] Disenar los privacy groups para un escenario enterprise con datos sensibles
- [ ] Explicar el flujo completo de una transaccion privada con Tessera
- [ ] Describir las capacidades de FireFly y cuando usarlo vs integracion directa
- [ ] Disenar una arquitectura hibrida (privada + publica) con anchoring
- [ ] Comparar Besu vs Fabric vs Corda con trade-offs claros para un escenario dado
- [ ] Completar el ejercicio de diseno del sistema de trazabilidad con todos los componentes
- [ ] Disenar el modelo de gobernanza de un consorcio blockchain
- [ ] Evaluar trade-offs entre centralizacion, privacidad y throughput
