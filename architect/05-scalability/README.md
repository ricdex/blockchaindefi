# Scalability

Escalabilidad de sistemas blockchain: el trilemma, Layer 2 solutions, data availability y análisis comparativo.

---

## 1. Objetivo

Al completar este módulo serás capaz de:

- Explicar el blockchain trilemma y las decisiones que implica
- Diferenciar rollups optimistic vs ZK con criterios técnicos concretos
- Comparar sidechains, rollups y validiums en términos de seguridad y performance
- Entender data availability: el problema, EIP-4844, y soluciones dedicadas
- Analizar la arquitectura de Arbitrum, StarkNet y Polygon
- Crear una decision matrix para elegir dónde deployar un protocolo DeFi

---

## 2. Prerequisitos

- Módulos 01 al 04 completados
- Entender cómo funciona la EVM y el modelo de transacciones de Ethereum
- Conceptos básicos de criptografía: hashes, firmas, zero-knowledge proofs (a nivel conceptual)
- Haber usado al menos un L2 (Arbitrum, Optimism, zkSync, etc.)

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
  |  - Fraud proof on L1    |                |  L1 re-ejecuta    |
  |  - Si fraude: revert    |                |  y decide         |
  +-------------------------+                +-------------------+
```

**Características:**
- Fraud proofs: solo se ejecuta la prueba en L1 si hay disputa
- Challenge period: típicamente 7 días para retiros de L2 a L1
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

  L1 native    Rollup         Validium       Sidechain
  (Ethereum)   (L1 data +     (L1 proofs,    (propia
               L1 proofs)     off-chain data) seguridad)
  |____________|______________|_______________|

  Más seguro                              Menos seguro
  Más caro                                Más barato
  Más lento                               Más rápido
```

| Solución    | Consensus          | Data Availability | Security            | Ejemplo           |
|-------------|--------------------|--------------------|---------------------|-------------------|
| Rollup      | Hereda de L1       | On-chain (L1)      | Igual que L1        | Arbitrum, zkSync  |
| Validium    | Hereda de L1       | Off-chain (DAC)    | Proofs on L1, data trust | zkPorter, StarkEx |
| Sidechain   | Propia (PoS, PoA)  | Propia             | Independiente de L1 | Polygon PoS, Gnosis |

**Rollup**: máxima seguridad. Los datos están en L1, cualquiera puede reconstruir el estado.

**Validium**: proofs en L1 pero datos off-chain en un Data Availability Committee (DAC). Si el DAC falla, los fondos pueden quedar inaccesibles.

**Sidechain**: cadena independiente con un bridge a L1. Su seguridad depende de su propio conjunto de validators, no de Ethereum.

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

### 4.1 Arbitrum: Nitro Architecture

**Evolución:**
- Arbitrum One (original): rollup optimistic con AVM (Arbitrum Virtual Machine)
- Arbitrum Nitro: reescritura usando WASM + Go-Ethereum (Geth) como base

**Arquitectura Nitro:**

```
  +----------------------------------------------------------+
  |  Arbitrum Nitro                                          |
  |                                                          |
  |  +-------------------+     +----------------------+      |
  |  | Sequencer         |     | State Transition     |      |
  |  | (ordena txs)      |---->| Function (Geth core) |      |
  |  +-------------------+     +----------------------+      |
  |           |                          |                   |
  |           v                          v                   |
  |  +-------------------+     +----------------------+      |
  |  | Batch poster      |     | Validator            |      |
  |  | (publica en L1)   |     | (verifica ejecución) |      |
  |  +-------------------+     +----------------------+      |
  |           |                          |                   |
  +-----------|--------------------------|-------------------+
              |                          |
              v                          v
  +-----------+---+              +-------+--------+
  | Ethereum L1   |              | Fraud proof    |
  | (data + roots)|              | (si disputa)   |
  +--------------+               | WASM execution |
                                 | on L1          |
                                 +----------------+
```

**Decisiones clave:**
- Usar Geth como base: máxima compatibilidad EVM, menor superficie de bugs nuevos
- Compilar a WASM para fraud proofs: portable, determinístico
- Sequencer centralizado (actualmente): throughput alto, plan de descentralización futuro
- Bold (nueva versión): fraud proofs permissionless con un solo honest participant

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

---

## 7. Recursos

### Papers y especificaciones
- [Ethereum Rollup-centric Roadmap](https://ethereum-magicians.org/t/a-rollup-centric-ethereum-roadmap/4698) - Vitalik Buterin
- [EIP-4844: Shard Blob Transactions](https://eips.ethereum.org/EIPS/eip-4844)
- [Danksharding Proposal](https://notes.ethereum.org/@dankrad/new_sharding)
- [An Incomplete Guide to Rollups](https://vitalik.eth.limo/general/2021/01/05/rollup.html) - Vitalik

### Documentación de L2s
- [Arbitrum Docs](https://docs.arbitrum.io/)
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
- [ ] Describir la arquitectura de Arbitrum Nitro y sus decisiones de diseño
- [ ] Explicar por qué StarkNet eligió un lenguaje propio (Cairo) en lugar de EVM
- [ ] Trazar la evolución de Polygon de sidechain a zkEVM
- [ ] Completar la decision matrix del ejercicio de diseño
- [ ] Estimar costos de transacción en L1 vs diferentes L2s (orden de magnitud)
