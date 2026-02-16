# Modulo 07: Governance and DAOs

## Objetivo

Al completar este modulo seras capaz de:

- Entender los conceptos fundamentales de governance on-chain y DAOs
- Implementar el patron Governor: propose -> vote -> queue -> execute
- Comprender el rol del timelock como mecanismo de seguridad
- Implementar un token de governance con delegacion de voto
- Identificar vulnerabilidades: flash loan attacks, quorum gaming, timelock bypass
- Construir un SimpleDAO funcional con Governor, Timelock y Treasury

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (tipos, modifiers, events)
- Modulo 02: Tokens and Standards (ERC-20)
- Modulo 04: Security Patterns (reentrancy, access control)
- Foundry instalado y funcional

---

## Conceptos clave

### 1. Que es una DAO

Una DAO (Decentralized Autonomous Organization) es una organizacion gobernada por smart contracts donde las decisiones se toman mediante votacion on-chain de los holders de governance tokens.

```
+------------------------------------------------------------------+
|                    ORGANIZACION TRADICIONAL                       |
|                                                                   |
|  CEO/Board ──decide──> Management ──ejecuta──> Operaciones       |
|  (centralizado, opaco, confianza requerida)                      |
+------------------------------------------------------------------+

+------------------------------------------------------------------+
|                           DAO                                     |
|                                                                   |
|  Token Holders ──votan──> Proposal ──timelock──> Ejecucion       |
|  (descentralizado, transparente, trustless)                      |
+------------------------------------------------------------------+
```

### 2. Governor Pattern (Lifecycle de una propuesta)

El patron Governor define un flujo estandar para governance on-chain. OpenZeppelin lo implementa como `Governor.sol`.

```
LIFECYCLE DE UNA PROPOSAL:

  +----------+    +--------+    +-----------+    +-----------+    +----------+
  | Pending  |--->| Active |--->| Succeeded |--->| Queued    |--->| Executed |
  +----------+    +--------+    +-----------+    +-----------+    +----------+
       |               |              |
       |               |              +---> Defeated (no quorum o mayoria en contra)
       |               |
       |               +---> Defeated (votacion finaliza sin aprobacion)
       |
       +---> (espera votingDelay bloques)

  DETALLE POR ETAPA:

  1. PENDING
     - Proposal creada pero votacion no inicia
     - votingDelay: tiempo de espera (ej: 1 dia)
     - Permite a holders prepararse, comprar tokens, delegar

  2. ACTIVE
     - Periodo de votacion abierto
     - votingPeriod: duracion (ej: 1 semana)
     - Votos: For (1), Against (0), Abstain (2)

  3. SUCCEEDED / DEFEATED
     - Votacion cierra
     - Succeeded si: quorum alcanzado AND votos For > Against
     - Defeated si: no hay quorum OR Against >= For

  4. QUEUED (Timelock)
     - Proposal pasa a timelock
     - timelockDelay: espera de seguridad (ej: 2 dias)
     - Permite a usuarios reaccionar (exit si no estan de acuerdo)

  5. EXECUTED
     - Despues del delay, cualquiera puede ejecutar
     - Se ejecutan las calls definidas en la proposal
```

### 3. Timelock

El timelock es un contrato que introduce un delay obligatorio entre la aprobacion de una propuesta y su ejecucion. Es un mecanismo de seguridad critico.

```
FLUJO CON TIMELOCK:

  Proposal aprobada
       |
       v
  Queue en Timelock ──(delay: 48h)──> Ejecutable
       |                                    |
       |  Durante el delay:                 v
       |  - Usuarios pueden salir          Execute
       |  - Comunidad puede reaccionar     (calls al Treasury
       |  - Se puede cancelar si es         o cualquier target)
       |    maliciosa
       |
  +--------------------------------------------------+
  | Timelock Contract                                 |
  |                                                   |
  |  queue(txHash, eta)                               |
  |  execute(txHash)  // solo despues de eta         |
  |  cancel(txHash)   // si se detecta problema      |
  |                                                   |
  |  POR QUE ES IMPORTANTE:                          |
  |  Sin timelock, una governance attack puede        |
  |  drenar fondos instantaneamente.                  |
  |  Con timelock, hay tiempo para reaccionar.        |
  +--------------------------------------------------+
```

### 4. Voting Strategies

```
TOKEN-WEIGHTED VOTING (1 token = 1 vote):

  Alice: 1000 tokens  -> 1000 votos
  Bob:   500 tokens   -> 500 votos
  Carol: 100 tokens   -> 100 votos

  Pro: simple, alineado con skin-in-the-game
  Con: plutocracia (whales dominan)


QUADRATIC VOTING (concepto):

  Votos = sqrt(tokens usados)

  Alice usa 100 tokens -> 10 votos
  Bob usa 400 tokens   -> 20 votos (4x tokens = solo 2x votos)

  Pro: reduce poder de whales
  Con: vulnerable a Sybil (crear muchas wallets)


DELEGACION:

  Alice ──delegate(bob)──> Bob vota con tokens de Alice + los suyos

  +--------+     delegate     +--------+
  | Alice  |----------------->|  Bob   |
  | 1000 tk|                  | 500 tk |
  +--------+                  +--------+
                              Voting power: 1500

  Pro: holders pasivos pueden delegar a expertos
  Con: concentracion de poder en delegates populares
```

### 5. Off-chain Governance: Snapshot

```
SNAPSHOT (gasless voting):

  1. Proposal creada off-chain
  2. Snapshot del balance de tokens en bloque X
  3. Usuarios firman voto con su wallet (no tx on-chain)
  4. Resultado se computa off-chain
  5. Ejecucion: manual o via multisig

  Pro: gas free, accesible, rapido
  Con: no es binding on-chain, requiere confianza en ejecutores

  Muchos protocolos usan modelo hibrido:
  - Snapshot para governance "soft" (signal, temp check)
  - Governor on-chain para ejecucion final
```

### 6. Treasury

El Treasury es un contrato que almacena los fondos de la DAO. Solo el Governor (via timelock) puede mover fondos.

```
+------------------------------------------------------------------+
|                        DAO Treasury                               |
|                                                                   |
|  +-----------+                                                    |
|  | ETH       |  Solo el Governor puede:                          |
|  | ERC-20s   |  - Transferir fondos                              |
|  | NFTs      |  - Aprobar gastos                                 |
|  +-----------+  - Ejecutar calls arbitrarios                     |
|                                                                   |
|  Proposal: "Enviar 10 ETH a contributor X"                       |
|       |                                                           |
|       v                                                           |
|  Vote -> Approve -> Timelock -> Execute -> Treasury.send(10 ETH) |
+------------------------------------------------------------------+
```

---

## Ejercicio practico: SimpleDAO

### Descripcion

Implementa un sistema de governance simplificado con tres componentes:
1. **GovernanceToken**: ERC-20 con delegacion de voto
2. **SimpleGovernor**: Contrato de governance con proposals, votacion y timelock
3. **Treasury**: Contrato que almacena fondos y es controlado por el Governor

### Arquitectura

```
+-------------------------------------------------------------------+
|                         SimpleDAO                                  |
|                                                                    |
|  +------------------+     +------------------+                     |
|  | GovernanceToken  |     | Treasury         |                     |
|  | ERC-20 + Votes   |     | ETH + Calls      |                     |
|  +--------+---------+     +--------+---------+                     |
|           |                        ^                               |
|           v                        |                               |
|  +------------------------------------------------+               |
|  |              SimpleGovernor                     |               |
|  |                                                 |               |
|  |  propose() --> proposalId                       |               |
|  |  vote(proposalId, support)                      |               |
|  |  execute(proposalId) --> calls Treasury         |               |
|  |                                                 |               |
|  |  votingDelay   = 1 block                        |               |
|  |  votingPeriod  = 50 blocks                      |               |
|  |  timelockDelay = 10 blocks                      |               |
|  |  quorum        = 4% of total supply             |               |
|  +------------------------------------------------+               |
+-------------------------------------------------------------------+

FLUJO END-TO-END:

  1. Alice propone: "Enviar 1 ETH del Treasury a Bob"
  2. Espera votingDelay (1 bloque)
  3. Alice y otros votan FOR durante votingPeriod (50 bloques)
  4. Proposal pasa quorum y mayoria For
  5. Espera timelockDelay (10 bloques)
  6. Cualquiera llama execute()
  7. Treasury envia 1 ETH a Bob
```

### Archivos

- `contracts/GovernanceToken.sol` - ERC-20 con delegacion de voto
- `contracts/SimpleGovernor.sol` - Governor con proposals, votacion y timelock
- `contracts/Treasury.sol` - Treasury controlado por el Governor
- `test/SimpleGovernor.t.sol` - tests completos

---

## Vulnerabilidades relevantes

### 1. Flash Loan Governance Attack

```
ATAQUE:

  1. Atacante pide flash loan de governance tokens
  2. Con la cantidad masiva de tokens, vota en una proposal
  3. Proposal aprobada instantaneamente (si no hay snapshot)
  4. Devuelve el flash loan en la misma tx

  MITIGACION:
  - Snapshots: el voting power se calcula en el bloque del propose()
  - No en el bloque del vote()
  - ERC20Votes usa checkpoints para esto
  - Nuestro SimpleGovernor usa un snapshot simplificado al crear la proposal

  tx {
    flashLoan(1M tokens)     // bloque N
    vote(proposalId, FOR)    // voting power = snapshot bloque N-1 (0 tokens!)
    repay(1M tokens)
  }
  // Ataque falla porque el snapshot es anterior al flash loan
```

### 2. Low Participation / Quorum Gaming

```
ESCENARIO:

  Total supply: 1,000,000 tokens
  Quorum: 4% = 40,000 tokens
  Typical voter turnout: ~5%

  Problema: con baja participacion, un whale con 40k tokens
  puede aprobar cualquier proposal solo.

  MITIGACION:
  - Quorum dinamico (ajusta segun participacion historica)
  - Minimum voting period largo
  - Timelock para dar tiempo a reaccionar
  - Veto power para council de emergencia
```

### 3. Timelock Bypass

```
ATAQUE: Governance con timelock corto o inexistente

  Sin timelock:
  - Proposal maliciosa se aprueba
  - Se ejecuta inmediatamente
  - No hay tiempo para que usuarios retiren fondos

  Con timelock corto (ej: 1 hora):
  - Casi igual de peligroso
  - Insuficiente para que la comunidad reaccione

  RECOMENDACION:
  - Mainnet: timelock de 2-7 dias minimo
  - Acciones criticas: timelock mayor
  - Emergency multisig para pausar si es necesario
```

### 4. Proposal Griefing

```
ATAQUE:

  Atacante crea cientos de proposals spam
  -> Congestion del sistema de governance
  -> Voters se cansan (voter fatigue)
  -> Proposal maliciosa pasa desapercibida

  MITIGACION:
  - Minimum token threshold para proponer
  - Proposal deposit (se pierde si no alcanza quorum)
  - Maximum active proposals
```

---

## Recursos

- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/5.x/governance)
- [Compound Governor Bravo](https://compound.finance/docs/governance)
- [Snapshot](https://snapshot.org/)
- [DAOs - Ethereum.org](https://ethereum.org/en/dao/)
- [ERC20Votes](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#ERC20Votes)
- [Timelock Controller](https://docs.openzeppelin.com/contracts/5.x/api/governance#TimelockController)
- [Nouns DAO](https://nouns.wtf/) - Ejemplo de DAO activa
- [Flash Loan Governance Attacks](https://www.paradigm.xyz/2020/11/decentralized-governance)

---

## Checkpoint

Antes de avanzar al Modulo 08, verifica que puedes:

- [ ] Explicar el lifecycle completo de una proposal: Pending -> Active -> Succeeded -> Executed
- [ ] Describir por que el timelock es critico para la seguridad de una DAO
- [ ] Explicar como funciona la delegacion de voto y por que es necesaria
- [ ] Describir el ataque de flash loan governance y como los snapshots lo previenen
- [ ] Explicar la diferencia entre governance on-chain y off-chain (Snapshot)
- [ ] Identificar al menos 3 vectores de ataque en sistemas de governance
- [ ] Tu SimpleDAO compila sin errores
- [ ] Todos los tests pasan con `forge test`
- [ ] Puedes ejecutar el flujo end-to-end: propose -> vote -> execute
