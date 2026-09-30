# Scalability

Escalabilidad de sistemas blockchain: el trilemma, Layer 2 solutions, data availability y análisis comparativo.

---

## 1. Objetivo

Al completar este módulo serás capaz de:

- Explicar el blockchain trilemma y las decisiones que implica
- Diferenciar rollups optimistic vs ZK con criterios técnicos concretos
- Comparar sidechains, rollups y validiums en términos de seguridad y performance
- Explicar qué ejecuta y guarda Arbitrum, qué publica en Ethereum y qué **no** se guarda en Ethereum
- Describir los cuatro servicios que Ethereum le presta a una L2: settlement, seguridad, disponibilidad de datos y resolución de disputas
- Distinguir una L2 de una blockchain EVM independiente con criterios arquitectónicos (no por el nombre)
- Entender data availability: el problema, EIP-4844, y soluciones dedicadas
- Analizar la arquitectura de Arbitrum, StarkNet y Polygon
- Crear una decision matrix para elegir dónde deployar un protocolo DeFi

---

## 2. Prerequisitos

- Módulos 01 al 04 completados
- Entender cómo funciona la EVM y el modelo de transacciones de Ethereum
- Conceptos básicos de criptografía: hashes, firmas, zero-knowledge proofs (a nivel conceptual)
- Haber usado al menos un L2. Si nunca lo hiciste, el [laboratorio L1 → L2 de developer/05](../../developer/05-oracles-and-bridges/) te lleva paso a paso (Sepolia → Arbitrum Sepolia)
- Tener claro el mapa "blockchain / EVM / red / activo nativo / token" ([developer/01, sección 0](../../developer/01-solidity-fundamentals/))

---

## 3. Conceptos clave

### 3.1 The Blockchain Trilemma

```
                    Decentralization
                         /\
                        /  \
                       /    \
                      /      \
                     /  BTC   \
                    /  ETH L1  \
                   /            \
                  /______________\
                 /                \
                /                  \
  Security  --/--------------------\--  Scalability
              \                    /
               \   Solana, BSC   /
                \    L2s aim    /
                 \  to balance /
                  \   all 3   /
                   \         /
                    \       /
                     \_____/
```

**El trilemma** (formulado por Vitalik Buterin): es difícil optimizar simultáneamente las tres propiedades:

- **Decentralization**: cualquiera puede participar como nodo/validator. Bajo hardware requirement.
- **Security**: resistencia a ataques con garantías criptográficas/económicas.
- **Scalability**: capacidad de procesar muchas transacciones rápidamente.

**Elecciones implícitas:**
- Bitcoin/Ethereum L1: priorizan decentralization + security. Throughput limitado (~15-30 TPS Ethereum).
- Solana/BSC: priorizan scalability + security. Menos descentralizados (hardware alto, menos validators).
- L2 rollups: intentan tener las tres al heredar security de L1 y escalar off-chain.

---

### 3.2 L1 Scaling

Enfoques para escalar la propia L1:

| Enfoque              | Descripción                                      | Ejemplo             | Trade-off                          |
|----------------------|--------------------------------------------------|---------------------|------------------------------------|
| Bigger blocks        | Aumentar gas limit / block size                  | BCH, BSV            | Centralización (más hardware)      |
| Parallel execution   | Ejecutar transacciones sin conflictos en paralelo| Solana (Sealevel)   | Complejidad del modelo de programación |
| Sharding             | Dividir el estado en particiones                 | Ethereum (danksharding) | Complejidad, cross-shard communication |
| Faster consensus     | Reducir block time                               | Solana (400ms), BSC (3s) | Más bloques huérfanos, centralización |

---

### 3.3 Layer 2 Solutions

#### Optimistic Rollups

**Principio**: ejecutar transacciones off-chain y asumir que son correctas ("optimistic"). Si alguien detecta fraude, puede desafiarlo.

```
  L2 (Optimistic Rollup)                    L1 (Ethereum)
  +-------------------------+                +-------------------+
  |                         |                |                   |
  | 1. Usuarios envían txs  |                |                   |
  |    al Sequencer         |                |                   |
  |         |               |                |                   |
  |         v               |                |                   |
  | 2. Sequencer ejecuta    |                |                   |
  |    y ordena txs         |                |                   |
  |         |               |   3. Publica   |                   |
  |         +---------------|---batch de txs>|  State root +     |
  |                         |   + state root |  tx data en       |
  |                         |                |  calldata/blobs   |
  |                         |                |                   |
  |                         |   4. Challenge |                   |
  |  Verifier/Challenger <--|---period (7d)->|  Si nadie          |
  |  puede disputar         |                |  disputa: final   |
  |                         |                |                   |
  |  5. Si disputa:         |                |                   |
  |  - Fraud proof on L1    |                |  L1 arbitra UN    |
  |  - Si fraude: revert    |                |  solo paso y      |
  |                         |                |  decide           |
  +-------------------------+                +-------------------+
```

**Características:**
- Fraud proofs: solo se ejecuta algo en L1 si hay disputa. Y ni siquiera se re-ejecuta la transacción completa: las partes van "partiendo" el desacuerdo en mitades (bisección) hasta aislar **una sola instrucción**, y L1 ejecuta solo esa instrucción para decidir quién tenía razón
- Challenge period: ~7 días (6.4 días en Arbitrum One) para retiros de L2 a L1
- EVM compatibility: alta (casi idéntico a Ethereum)
- Ejemplos: **Optimism** (OP Stack), **Arbitrum** (Nitro)

#### ZK Rollups

**Principio**: ejecutar transacciones off-chain y generar una validity proof (prueba criptográfica) de que la ejecución fue correcta. L1 verifica la prueba.

```
  L2 (ZK Rollup)                            L1 (Ethereum)
  +-------------------------+                +-------------------+
  |                         |                |                   |
  | 1. Usuarios envían txs  |                |                   |
  |    al Sequencer         |                |                   |
  |         |               |                |                   |
  |         v               |                |                   |
  | 2. Sequencer ejecuta    |                |                   |
  |    txs                  |                |                   |
  |         |               |                |                   |
  |         v               |                |                   |
  | 3. Prover genera        |                |                   |
  |    validity proof       |                |                   |
  |    (ZK-SNARK/STARK)     |   4. Publica   |                   |
  |         +---------------|---proof + data>|  Verifier contract|
  |                         |                |  verifica proof   |
  |                         |                |         |         |
  |                         |                |         v         |
  |                         |                |  Si válido:       |
  |                         |                |  state actualizado|
  |                         |                |  inmediatamente   |
  +-------------------------+                +-------------------+
```

**Características:**
- Validity proofs: L1 verifica matemáticamente que la ejecución fue correcta
- Finality: tan pronto como la prueba se verifica en L1 (minutos, no días)
- EVM compatibility: varía. zkEVM busca compatibilidad, otros usan VMs custom
- Ejemplos: **zkSync Era**, **StarkNet** (Cairo VM), **Scroll**, **Polygon zkEVM**

#### Comparación Optimistic vs ZK

| Criterio              | Optimistic Rollup            | ZK Rollup                     |
|-----------------------|------------------------------|-------------------------------|
| Proof mechanism       | Fraud proof (interactive)    | Validity proof (ZK-SNARK/STARK)|
| Finality to L1        | ~7 días (challenge period)   | Minutos-horas (proof generation)|
| EVM compatibility     | Alta (casi nativa)           | Variable (zkEVM en desarrollo) |
| Costo por tx          | Bajo (solo data posting)     | Medio (proof generation costoso)|
| Complejidad           | Menor                        | Mayor (cryptography pesada)    |
| Withdrawal to L1      | 7 días (sin fast bridge)     | Horas (después del proof)      |
| Madurez               | Más maduro (Arbitrum, OP)    | En rápida evolución            |
| Prover requirements   | N/A                          | Hardware intensivo             |

---

### 3.4 Sidechains vs Rollups vs Validiums

```
  Security Model Spectrum

  L1 native    Rollup         Validium /     Sidechain /
  (Ethereum)   (L1 data +     Optimium       cadena independiente
               L1 proofs)     (L1 proofs,    (propia seguridad)
                              off-chain data)
  |____________|______________|_______________|

  Más seguro                              Menos seguro
  Más caro                                Más barato
  Más lento                               Más rápido
```

Para comparar, la pregunta útil no es "¿quién es más rápido?", sino **"¿quién decide cuál es el estado válido y dónde están los datos para comprobarlo?"**:

| Solución | Quién ejecuta | Dónde están los datos | Quién decide qué estado es válido | Confianza extra que asumes | Ejemplo |
|----------|---------------|-----------------------|-----------------------------------|----------------------------|---------|
| Rollup | El sequencer de la L2 | En Ethereum (calldata o blobs) | **Ethereum** (fraud o validity proofs) | Que el sequencer no te censure por un tiempo (existe inclusión forzada) y quién controla las llaves de upgrade | Arbitrum One, Base, zkSync Era |
| Validium (ZK) / Optimium (optimistic) | El sequencer | En un comité off-chain (DAC) | **Ethereum**, pero solo si los datos están disponibles | Que el comité publique los datos | Arbitrum Nova (AnyTrust), StarkEx en modo validium |
| Sidechain / cadena independiente | Sus validadores | En su propia red | **Sus propios validadores** | Todo: si la mayoría miente, el estado falso *es* el estado | Polygon PoS, Gnosis, BNB Chain |

**Rollup**: la opción más segura de las tres. Los datos están en L1, así que cualquiera puede reconstruir el estado y disputarlo. Pero su seguridad **no es idéntica** a la de L1: se agregan supuestos que conviene nombrar (ver más abajo).

**Validium / Optimium**: las pruebas o disputas se resuelven en L1, pero los datos están fuera, en un Data Availability Committee (DAC). Si el DAC deja de publicar, nadie puede demostrar cuál es el estado y los fondos pueden quedar inaccesibles.

**Sidechain**: cadena independiente con un bridge a L1. Su seguridad depende de su propio conjunto de validators, no de Ethereum. Polygon PoS publica *checkpoints* en Ethereum, pero Ethereum no verifica que sean correctos: solo los guarda.

#### "Hereda la seguridad de L1": qué significa y qué no

En un rollup, Ethereum garantiza dos cosas muy concretas: **que el estado aceptado es el resultado correcto de ejecutar las transacciones publicadas** y **que esas transacciones se publicaron**. Hay otras cosas que Ethereum **no** garantiza por sí solo:

| Riesgo | Qué puede pasar | Mitigación en Arbitrum One |
|--------|-----------------|----------------------------|
| Sequencer centralizado | Puede reordenar, retrasar o ignorar tu transacción | *Inclusión forzada*: si te ignora, envías la tx por el `Inbox` de L1 y a las ~24 h puedes obligar a incluirla |
| Sequencer caído | La L2 deja de producir bloques rápidos | La misma vía de L1 (más lenta y cara) |
| Llaves de upgrade | Quien puede actualizar los contratos de L1 podría cambiar las reglas | Upgrades normales vía DAO con timelocks largos. Un Security Council (9 de 12) solo para emergencias |
| Blobs temporales | Los blobs se borran de L1 a las ~18 días | Suficiente para disputar; después, los datos se obtienen de nodos de L2 y archivadores |

> [L2Beat](https://l2beat.com/scaling/summary) clasifica los rollups en *Stages* (0, 1, 2) según cuánto dependen todavía de actores con privilegios. Revisar el stage es la forma rápida de responder "¿qué tanto hereda realmente de L1?".

#### L2 vs cadena EVM independiente: la prueba de las tres preguntas

Arbitrum y BNB Chain se ven iguales desde MetaMask: misma EVM, mismas direcciones, mismo Solidity, un selector de red. La diferencia está en la arquitectura, y se detecta con tres preguntas:

1. **¿Quién decide cuál es el estado válido?** En Arbitrum, en última instancia, un contrato en Ethereum. En BNB Chain, sus validadores.
2. **¿Dónde se pueden obtener los datos para reconstruir el estado?** Arbitrum los publica en Ethereum. BNB Chain, solo en su propia red.
3. **¿Qué pasa si los operadores desaparecen o mienten?** En Arbitrum, cualquiera puede reconstruir el estado con los datos de L1 y retirar por el bridge canónico. En BNB Chain, si la mayoría de los validadores miente, no hay ninguna instancia superior que lo corrija.

| | Arbitrum One | Arbitrum Nova | Polygon PoS | BNB Chain |
|---|---|---|---|---|
| ¿Ejecuta la EVM? | Sí | Sí | Sí | Sí |
| ¿Quién decide el estado válido? | Ethereum | Ethereum | Sus validadores | Sus validadores |
| ¿Dónde están los datos? | Ethereum | Comité (DAC) | Polygon | BNB Chain |
| Gas token | ETH | ETH | POL | BNB |
| Clasificación | Rollup (L2) | AnyTrust / Optimium | Sidechain con checkpoints | L1 independiente |

La lección: **"EVM-compatible" y "L2" son ejes independientes.** El primero describe la experiencia del desarrollador; el segundo, de dónde viene la seguridad.

```
                              ¿Ejecuta la EVM?
                         Sí                          No
                 ┌──────────────────────────┬──────────────────────────┐
  ¿Ethereum  Sí  │ Arbitrum One, Base,      │ StarkNet (Cairo VM)      │
  decide el      │ Optimism  (L2 EVM)       │ (L2 no-EVM)              │
  estado         ├──────────────────────────┼──────────────────────────┤
  válido?    No  │ BNB Chain, Polygon PoS,  │ Solana, Bitcoin          │
                 │ Avalanche C-Chain        │                          │
                 └──────────────────────────┴──────────────────────────┘
```

---

### 3.5 Data Availability

#### El problema

Para que un rollup sea seguro, los datos de las transacciones deben estar disponibles para que cualquiera pueda:
1. Verificar la correctitud del state root
2. Generar fraud proofs (en optimistic rollups)
3. Reconstruir el estado si el sequencer desaparece

Si los datos no están disponibles, el rollup pierde su garantía de seguridad.

#### EIP-4844: Proto-Danksharding (Blob Transactions)

Antes de EIP-4844, los rollups publicaban datos en calldata de Ethereum (caro, permanente).

EIP-4844 introduce **blob transactions**:

```
  Transacción normal (pre-4844):
  +------------------+
  | tx data          |  <- calldata (permanente, caro)
  | (rollup batches) |
  +------------------+

  Blob transaction (post-4844):
  +------------------+  +------------------+
  | tx metadata      |  | blob 1 (128 KB)  |  <- datos temporales
  | (commitment)     |  | blob 2 (128 KB)  |     (~18 días)
  +------------------+  +------------------+     mucho más barato
```

**Características:**
- Blobs: hasta 128 KB cada uno, ~3-6 blobs por bloque
- Temporales: se eliminan después de ~18 días (suficiente para fraud proofs)
- Baratos: mercado de fee separado del gas normal
- Resultado: reducción de ~10-100x en costos de L2

#### Data Availability Sampling (DAS)

En full danksharding (futuro), los nodos no necesitarán descargar todos los datos:

```
  Blob completo (dividido en fragmentos):
  [F1][F2][F3][F4][F5][F6][F7][F8]

  Nodo A muestrea: [F1]   [F4]         [F8]
  Nodo B muestrea:    [F2]      [F5][F6]
  Nodo C muestrea:       [F3]      [F6]   [F8]

  Con suficientes nodos muestreando aleatoriamente,
  hay alta probabilidad de que todos los datos estén disponibles.
```

DAS permite verificar disponibilidad sin descargar todo, habilitando más datos por bloque sin aumentar los requerimientos de los nodos.

#### Dedicated DA Layers

| Solución    | Descripción                                           | Modelo                        |
|-------------|-------------------------------------------------------|-------------------------------|
| Celestia    | Blockchain modular dedicada solo a DA y consenso      | DAS nativo, light nodes       |
| EigenDA     | DA layer construido sobre EigenLayer (restaked security)| Operators de Ethereum         |
| Avail       | DA chain con DAS, separada de ejecución               | Similar a Celestia            |

Estas capas permiten a los rollups publicar datos fuera de Ethereum por mucho menos costo, a cambio de un modelo de seguridad diferente (no Ethereum-native DA).

---

### 3.6 Cost Comparison

Costos aproximados por transacción (orden de magnitud, sujetos a variación):

| Solución                    | Costo por swap (USD aprox) | Finality        |
|-----------------------------|---------------------------|-----------------|
| Ethereum L1                 | $5 - $50+                 | ~13 min         |
| Optimistic Rollup (pre-4844)| $0.50 - $2               | 7 días (L1 final)|
| Optimistic Rollup (post-4844)| $0.01 - $0.10           | 7 días (L1 final)|
| ZK Rollup (post-4844)      | $0.01 - $0.20            | Horas           |
| Validium                    | $0.001 - $0.01           | Variable        |
| Sidechain (Polygon PoS)    | $0.001 - $0.01           | ~2 min (propia) |
| Solana (L1)                 | $0.001 - $0.01           | ~0.4 sec        |

Nota: estos costos varían significativamente según la congestión de la red y las condiciones del mercado.

---

## 4. Análisis de casos reales

### 4.1 Arbitrum (caso principal): qué vive en cada capa

Esta sección es el corazón del módulo. El objetivo es que puedas dibujar, sin mirar, qué hace Arbitrum, qué hace Ethereum y por qué la combinación es más que "otra blockchain EVM". La parte práctica está en el [laboratorio del módulo developer/05](../../developer/05-oracles-and-bridges/): conviene hacerlo antes o en paralelo.

#### 4.1.1 La frase guía

> **L2 ejecuta; L1 proporciona la infraestructura de confianza.**

Una analogía para fijarla: Arbitrum es una empresa que atiende a millones de clientes y lleva su propia contabilidad al día. Ethereum cumple tres papeles para ella:

- **Registro público**: la empresa está obligada a publicar allí cada operación, para que cualquiera pueda rehacer su contabilidad.
- **Bóveda**: el dinero de los clientes que entró desde fuera está guardado allí.
- **Tribunal**: si alguien afirma que la contabilidad publicada es falsa, el caso se decide allí.

El tribunal no revisa todos los libros de la empresa, solo el punto exacto del desacuerdo.

La empresa (L2) hace el trabajo pesado y rápido. El registro, la bóveda y el tribunal (L1) son lentos y caros, pero no dependen de confiar en la empresa.

#### 4.1.2 Componentes

```
  ARBITRUM (L2) ─ ejecuta y guarda el estado          ETHEREUM (L1) ─ contratos de Arbitrum en L1
  ┌──────────────────────────────────────────┐        ┌───────────────────────────────────────────┐
  │                                          │        │                                           │
  │  Usuarios ──txs──> Sequencer             │        │  Inbox + Bridge                           │
  │                    (ordena, ~250 ms)     │<───────│  (depósitos, mensajes L1→L2,              │
  │                        │                 │ lee    │   bóveda del ETH depositado)              │
  │                        ▼                 │        │                                           │
  │  Nodos Nitro: ArbOS + núcleo de Geth     │        │  SequencerInbox                           │
  │  - ejecutan la EVM                       │        │  (recibe los batches: DATOS)       ◄──┐   │
  │  - guardan balances, contratos, storage  │        │                                       │   │
  │                        │                 │        │  Rollup (BoLD)                        │   │
  │                        ▼                 │        │  (recibe assertions: ESTADO,     ◄──┐ │   │
  │  Batch poster ─── batches comprimidos ───┼────────┼──────────────────────────────────┼──┘   │
  │                   (blobs EIP-4844)       │        │   challenge period, disputas)    │     │
  │                                          │        │                                  │     │
  │  Validadores ──── assertions ────────────┼────────┼──────────────────────────────────┘     │
  │  (afirman "tras el batch N, el           │        │                                           │
  │   estado es S")                          │        │  Outbox                                   │
  │                                          │        │  (ejecuta retiros ya confirmados)         │
  └──────────────────────────────────────────┘        └───────────────────────────────────────────┘
```

#### 4.1.3 Qué ejecuta y almacena Arbitrum

Todo lo que un usuario o un desarrollador "toca" vive en L2:

- **Transacciones**: las recibe, ordena y ejecuta el sequencer en ~250 ms (la "soft confirmation" que ves en la wallet).
- **Contratos**: el bytecode desplegado es una cuenta en el estado **de Arbitrum**.
- **Balances**: el ETH nativo de L2 y los `mapping` de cada ERC-20 de L2.
- **Estado completo**: nonces, storage, receipts y logs. Todo lo guardan los nodos de Arbitrum.

#### 4.1.4 Qué se publica en Ethereum y qué NO

| Se publica / guarda en Ethereum L1 | NO se guarda en Ethereum L1 |
|------------------------------------|-----------------------------|
| **Batches**: las transacciones de L2, comprimidas, en blobs (temporales, ~18 días) o calldata | El **estado** de L2: balances, storage, nonces |
| **Compromisos de los blobs** (`blobVersionedHash`), para siempre | Los **contratos** de L2 como cuentas ejecutables (`cast code` en L1 devuelve `0x`) |
| **Assertions**: compromisos (hashes) del estado de L2 tras cada tramo de batches | La **ejecución**: L1 no corre las transacciones de L2 (salvo un único paso en una disputa) |
| El **ETH bloqueado** en el contrato `Bridge` y los mensajes de depósito | Receipts, logs y eventos de L2 |
| Las **disputas** y su resultado | El historial "legible" de L2: para eso está Arbiscan |

La sutileza más importante de la tabla: **los datos de un deploy sí llegan a L1, pero el contrato no existe en L1.** Ethereum guarda los datos como un notario guarda un documento: los conserva para que otros puedan verificar, pero no los ejecuta.

#### 4.1.5 Los cuatro servicios que Ethereum le presta a Arbitrum

| Servicio | Qué significa en concreto | Qué pasaría sin él |
|----------|---------------------------|--------------------|
| **Settlement** (asentamiento) | El contrato `Rollup` en L1 es la fuente de verdad de qué estado de L2 es definitivo. Los retiros se liberan en L1 solo contra un estado confirmado | Nadie en L1 podría saber qué te corresponde; el bridge dependería de firmantes externos |
| **Seguridad** | El ETH depositado está en un contrato de L1, protegido por el consenso de Ethereum (y no por un multisig) | La bóveda sería tan segura como las llaves de quien la custodie (ver Ronin) |
| **Disponibilidad de datos (DA)** | Los batches se publican en L1, así que cualquiera puede descargarlos y reconstruir el estado de L2 | Un operador podría "congelar" el estado negándose a publicar los datos |
| **Resolución de disputas** | Si una assertion es falsa, cualquier validador honesto puede disputarla en L1 (BoLD: permissionless, con plazo acotado), y L1 decide ejecutando un solo paso | Habría que confiar en que los validadores de L2 no mienten, igual que en una cadena independiente |

Con los cuatro servicios juntos, **basta un solo participante honesto** que mire los datos para que un estado falso no pueda asentarse. Esa es la diferencia de fondo con una cadena independiente, donde se necesita que la *mayoría* de los validadores sea honesta.

#### 4.1.6 Lo que la frase guía no dice (supuestos de confianza)

- **El sequencer ordena.** Hoy es un único operador: puede retrasar o censurar tu transacción, aunque no puede robarte. La vía de escape es la inclusión forzada desde L1 (~24 h).
- **Los contratos son actualizables.** La DAO de Arbitrum los actualiza con timelocks, y el Security Council (9 de 12) puede actuar en emergencias. Es un supuesto de confianza real, visible en L2Beat.
- **Finalidad en capas.** Una transacción tiene tres niveles de "confirmado", y conviene saber cuál necesitas (ver 4.1.8).

#### 4.1.7 Cuánto cuesta y por qué

La comisión de una transacción en Arbitrum tiene dos componentes:

```
fee = gas de ejecución en L2 (barato: lo ejecuta Arbitrum)
    + gas por el espacio que ocupan tus datos en L1 (lo que cuesta publicar en Ethereum)
```

En el receipt de Arbitrum, el campo `gasUsedForL1` muestra la segunda parte. Por eso EIP-4844 (blobs) abarató tanto las L2: el componente dominante era el de L1.

#### 4.1.8 Un deploy, capa por capa (lo que hiciste en el laboratorio)

```
 t ≈ 0                        L2  Remix + MetaMask firman una tx con chain ID 421614 y la envían al sequencer.
                                  Gas pagado en ETH NATIVO de Arbitrum (llegó por el bridge desde L1).
 t ≈ 250 ms                   L2  El sequencer la ordena y los nodos la ejecutan: el contrato ya existe
                                  en el estado de Arbitrum. (soft confirmation: confías en el sequencer)
 t ≈ minutos                  L1  El batch poster publica un batch con tu tx en SequencerInbox (blob tx).
                                  Tus datos ya son públicos en Ethereum. Cuando ese bloque de L1 se
                                  finaliza (~13 min), el ORDEN de tu tx no puede cambiar.
 t ≈ ~1 h                     L1  Un validador publica una assertion que cubre ese batch: "el estado
                                  resultante es S".
 t ≈ ~6.4 días (Arbitrum One) L1  Sin disputas exitosas, la assertion se confirma: el estado es
                                  definitivo PARA L1. Solo importa si quieres retirar a L1.
```

Fíjate en que, para usar tu contrato en L2, te basta con el segundo o el tercer nivel. El challenge period **no** hace lenta a Arbitrum: solo hace lentos los **retiros hacia L1**.

#### 4.1.9 Arbitrum Nova: la misma tecnología, otro modelo de datos

Arbitrum Nova usa el mismo software, pero en lugar de publicar los batches en Ethereum se los entrega a un comité (DAC, *AnyTrust*) que firma que los guardará, y en L1 solo se publica ese certificado. Es más barata, pero el servicio de **disponibilidad de datos** deja de venir de Ethereum. Es un buen ejemplo de que "L2" no es binario: hay que preguntar qué servicios de L1 se usan realmente.

#### 4.1.10 Decisiones de diseño de Nitro

- **Evolución**: Arbitrum Classic usaba una VM propia (AVM). Nitro (2022) reemplazó esa VM por el núcleo de Geth, con ArbOS encima.
- **Geth como base**: máxima compatibilidad EVM y menor superficie de bugs nuevos.
- **WASM para las pruebas**: la misma función de transición de estado se compila a WAVM, un formato determinista en el que se puede probar en L1 un solo paso (*one-step proof*).
- **Sequencer centralizado (actualmente)**: throughput alto y latencia baja, a cambio del supuesto de confianza descrito en 4.1.6.
- **BoLD** (activo en Arbitrum One desde 2025): disputas permissionless con tiempo acotado. Cualquiera puede defender el estado correcto, y el protocolo garantiza que el honesto gana en un plazo máximo, sin importar cuántos atacantes haya.

### 4.2 StarkNet: STARK Proofs y Cairo

**Arquitectura:**

```
  +----------------------------------------------------------+
  |  StarkNet                                                |
  |                                                          |
  |  +-------------------+     +----------------------+      |
  |  | Sequencer         |     | Cairo VM             |      |
  |  | (ordena txs)      |---->| (no EVM, VM propia)  |      |
  |  +-------------------+     +----------------------+      |
  |                                      |                   |
  |                                      v                   |
  |                             +----------------------+     |
  |                             | SHARP (Shared Prover)|     |
  |                             | Genera STARK proofs  |     |
  |                             +----------------------+     |
  |                                      |                   |
  +--------------------------------------|-------------------+
                                         |
                                         v
                                +--------+---------+
                                | Ethereum L1      |
                                | Verifier contract|
                                | (verifica STARK) |
                                +------------------+
```

**Diferencias respecto a otros ZK rollups:**
- **Cairo**: lenguaje de programación propio (no Solidity). Diseñado para ser "provable" eficientemente.
- **STARKs vs SNARKs**: STARKs no requieren trusted setup, son post-quantum resistant, pero las proofs son más grandes.
- **Account Abstraction nativa**: todas las cuentas son smart contracts (no EOAs).
- **Recursive proofs**: proofs de proofs, permitiendo mayor escalabilidad.

**Trade-off**: no EVM compatible -> los desarrolladores deben aprender Cairo. Pero el diseño es más eficiente para ZK.

### 4.3 Polygon: de sidechain a zkEVM

**Evolución:**

```
  Polygon PoS (sidechain)
        |
        | (mantiene operando)
        |
        +---> Polygon zkEVM (ZK rollup)
        |     - Compatible con Solidity
        |     - Proofs en Ethereum L1
        |
        +---> Polygon CDK
        |     - Kit para crear L2s custom
        |
        +---> AggLayer
              - Capa de agregación de proofs
              - Unifica liquidez entre chains
```

**Polygon PoS:**
- Sidechain con su propio consenso PoS
- Muy barata pero seguridad independiente de Ethereum
- Usa checkpoints en Ethereum (no full rollup security)

**Polygon zkEVM:**
- ZK rollup con compatibilidad EVM a nivel de bytecode
- El prover traduce ejecución EVM a circuitos ZK
- Trade-off: compatibilidad total vs eficiencia del prover

**Lección**: un ecosistema puede evolucionar de sidechain a rollup, aprovechando el network effect existente.

---

## 5. Ejercicio de diseño

### Decision Matrix: Dónde deployar un DEX

**Escenario**: Estás diseñando un DEX (tipo Uniswap V3 con concentrated liquidity). Debes elegir dónde deployarlo: Ethereum L1, Optimistic Rollup (Arbitrum) o ZK Rollup (zkSync Era).

**Analizar para cada opción:**

#### A. Costo por swap
- Gas estimado para un swap (considerando storage reads/writes)
- Costo en USD a diferentes niveles de congestión
- Costo para LPs de add/remove liquidity

#### B. Finality time
- Tiempo hasta que el swap es "seguro" para el usuario
- Implicaciones para arbitrage bots y market makers
- Tiempo de retiro a L1 (relevant para bridges)

#### C. Bridge UX
- Cómo llegan los fondos desde L1
- Tiempo de bridging (deposit y withdrawal)
- Riesgos del bridge (smart contract, liquidity)
- Fast bridges (third-party vs native)

#### D. Developer Experience
- Tooling disponible (Hardhat, Foundry, etc.)
- Diferencias en el entorno de ejecución
- Debugging y testing capabilities
- Madurez del ecosistema de librerías

#### E. Security Assumptions
- De quién depende la seguridad (L1 validators, L2 sequencer, prover)
- Qué pasa si el sequencer se cae
- Escape hatch: pueden los usuarios retirar fondos si el L2 falla
- Riesgos específicos de cada solución

#### F. Decision Matrix

| Criterio                  | Peso | Ethereum L1 | Arbitrum | zkSync Era |
|---------------------------|------|-------------|----------|------------|
| Costo por swap            | 25%  | ?/10        | ?/10     | ?/10       |
| Finality                  | 15%  | ?/10        | ?/10     | ?/10       |
| Bridge UX                 | 10%  | ?/10        | ?/10     | ?/10       |
| Developer experience      | 20%  | ?/10        | ?/10     | ?/10       |
| Security                  | 20%  | ?/10        | ?/10     | ?/10       |
| Ecosystem / liquidity     | 10%  | ?/10        | ?/10     | ?/10       |
| **Total ponderado**       |      | ?           | ?        | ?          |

Completar la tabla con scores y justificaciones para cada celda.

**Formato de entrega**: documento con la decision matrix completa, justificación de pesos, scores con argumentación, y recomendación final.

### Ejercicio 2: Explica tu deploy capa por capa

**Prerequisito**: haber hecho el [laboratorio L1 → L2 de developer/05](../../developer/05-oracles-and-bridges/) (o al menos leerlo con atención).

**Tarea**: escribe una explicación de una página, para alguien que solo conoce Ethereum, de lo que ocurrió desde que tenías SepoliaETH hasta que tu `ChainProbe` quedó asentado. Debe incluir:

1. **Un diagrama de dos columnas (L1 | L2)** con cada paso (depósito, crédito en L2, deploy, batch, assertion) ubicado en la columna correcta.
2. **La tabla "qué quedó dónde"**, completada con *tus* datos: dirección del contrato, hash del depósito, número de batch, hash de la tx de L1 del batch.
3. **Los cuatro servicios de L1** (settlement, seguridad, DA, disputas), cada uno señalado en un punto concreto de tu recorrido.
4. **Contrafactual**: reescribe el recorrido suponiendo que desplegaste en BNB Chain. ¿Qué pasos desaparecen? ¿Qué servicio de los cuatro deja de existir y quién lo reemplaza?
5. **Contrafactual 2**: ¿y si hubiera sido Arbitrum Nova? ¿Qué servicio cambia de proveedor?

**Criterio de evaluación**: la explicación es correcta si alguien que la lea puede responder sin dudar "¿mi contrato existe en Ethereum?" (no) y "¿por qué entonces decimos que Ethereum lo asegura?" (porque sus datos están en L1 y L1 decide qué estado es válido).

---

## 6. Trade-offs y decisiones

| Decisión                          | Opción A                        | Opción B                         | Consideración                          |
|-----------------------------------|---------------------------------|----------------------------------|----------------------------------------|
| Finality vs Security              | Optimistic (7d, battle-tested)  | ZK (horas, newer tech)           | Madurez vs velocidad                   |
| EVM compatibility vs Performance  | zkEVM (compatible, más lento)   | Custom VM (rápido, nuevo lang)   | Adopción vs eficiencia                 |
| Sequencer                         | Centralizado (rápido, simple)   | Descentralizado (censorship-resistant) | UX vs resistencia a censura      |
| Data availability                 | On-chain (Ethereum, seguro)     | Off-chain (barato, trust assumptions) | Seguridad vs costo                |
| Proof system                      | SNARK (proof pequeño, trusted setup) | STARK (proof grande, no setup) | Verificación barata vs trustless  |
| Multi-chain vs Single-chain       | Deploy en muchos L2s            | Focus en uno solo                | Liquidez fragmentada vs alcance        |
| Native bridge vs Third-party      | Official bridge (seguro, lento) | Third-party (rápido, riesgo)     | Seguridad vs UX                        |
| Dónde asentar (settlement)        | L2 sobre Ethereum (hereda DA y disputas) | Cadena EVM independiente (seguridad propia) | Seguridad heredada vs soberanía y costo |

---

## 7. Recursos

### Papers y especificaciones
- [Ethereum Rollup-centric Roadmap](https://ethereum-magicians.org/t/a-rollup-centric-ethereum-roadmap/4698) - Vitalik Buterin
- [EIP-4844: Shard Blob Transactions](https://eips.ethereum.org/EIPS/eip-4844)
- [Danksharding Proposal](https://notes.ethereum.org/@dankrad/new_sharding)
- [An Incomplete Guide to Rollups](https://vitalik.eth.limo/general/2021/01/05/rollup.html) - Vitalik

### Documentación de L2s
- [Arbitrum Docs](https://docs.arbitrum.io/)
  - [Inside Arbitrum Nitro](https://docs.arbitrum.io/how-arbitrum-works/inside-arbitrum-nitro) - sequencer, batches, assertions
  - [A gentle introduction to BoLD](https://docs.arbitrum.io/how-arbitrum-works/bold/gentle-introduction) - disputas permissionless
  - [Diferencias de Solidity en Arbitrum](https://docs.arbitrum.io/build-decentralized-apps/arbitrum-vs-ethereum/solidity-support) - `block.number`, precompiles
- [L2Beat - Arbitrum One](https://l2beat.com/scaling/projects/arbitrum) - riesgos, stage y permisos, explicados
- [Optimism Docs](https://docs.optimism.io/)
- [zkSync Era Docs](https://docs.zksync.io/)
- [StarkNet Docs](https://docs.starknet.io/)
- [Polygon zkEVM Docs](https://zkevm.polygon.technology/)

### Data availability
- [Celestia Docs](https://docs.celestia.org/)
- [EigenDA](https://docs.eigenlayer.xyz/)
- [Data Availability Explained](https://ethereum.org/en/developers/docs/data-availability/)

### Talks
- [Vitalik - The Different Types of Layer 2s](https://www.youtube.com/watch?v=lhHKbRddOX0)
- [Understanding ZK Rollups](https://www.youtube.com/watch?v=7pWxCklcNsU)
- [L2Beat Overview](https://www.youtube.com/watch?v=S2HDHFz5RKk)

### Herramientas y dashboards
- [L2Beat](https://l2beat.com/) - Comparación de L2s (TVL, risk, tech)
- [L2Fees](https://l2fees.info/) - Comparación de costos en tiempo real
- [Dune L2 Dashboards](https://dune.com/browse/dashboards?q=l2)
- [Rollup.codes](https://rollup.codes/) - Comparación técnica de rollups

---

## 8. Checkpoint

Antes de avanzar al siguiente módulo, verifica que puedes:

- [ ] Explicar el blockchain trilemma y cómo cada solución hace trade-offs
- [ ] Describir cómo funciona un optimistic rollup paso a paso (sequencer, batch, challenge)
- [ ] Describir cómo funciona un ZK rollup paso a paso (sequencer, prover, verifier)
- [ ] Comparar optimistic vs ZK en al menos 5 dimensiones con argumentos
- [ ] Explicar la diferencia entre rollup, validium y sidechain en términos de security model
- [ ] Describir el problema de data availability y cómo EIP-4844 lo aborda
- [ ] Explicar qué es DAS (Data Availability Sampling) y por qué importa
- [ ] Comparar Celestia y EigenDA como DA layers
- [ ] Explicar por qué "hereda la seguridad de L1" no significa "igual que L1" (sequencer, upgrades, blobs temporales)
- [ ] Aplicar la prueba de las tres preguntas para clasificar Arbitrum One, Arbitrum Nova, Polygon PoS y BNB Chain
- [ ] Explicar por qué "EVM-compatible" y "L2" son ejes independientes, con un ejemplo de cada cuadrante
- [ ] Listar qué ejecuta y guarda Arbitrum, qué publica en Ethereum y qué NO se guarda en Ethereum
- [ ] Nombrar los cuatro servicios que Ethereum presta a Arbitrum y qué pasaría sin cada uno
- [ ] Explicar con tus palabras "L2 ejecuta; L1 proporciona infraestructura de confianza"
- [ ] Recorrer un deploy en Arbitrum capa por capa con sus tiempos (250 ms, minutos, ~1 h, ~6.4 días)
- [ ] Describir la arquitectura de Arbitrum Nitro y sus decisiones de diseño
- [ ] Explicar por qué StarkNet eligió un lenguaje propio (Cairo) en lugar de EVM
- [ ] Trazar la evolución de Polygon de sidechain a zkEVM
- [ ] Completar la decision matrix del ejercicio de diseño
- [ ] Completar el ejercicio 2 (tu deploy capa por capa, con los dos contrafactuales)
- [ ] Estimar costos de transacción en L1 vs diferentes L2s (orden de magnitud)
