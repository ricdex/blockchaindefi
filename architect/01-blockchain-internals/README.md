# Blockchain Internals

Deep dive en cómo funcionan las blockchains a nivel interno: estructuras de datos, consenso, ejecución y modelo de estado.

---

## 1. Objetivo

Al completar este módulo serás capaz de:

- Explicar la estructura interna de un bloque (header, body, receipts)
- Construir y verificar Merkle proofs sobre un árbol binario y una Patricia Merkle Trie
- Comparar mecanismos de consenso (PoW, PoS, BFT) con criterios técnicos concretos
- Describir cómo la EVM ejecuta bytecode: stack, opcodes, modelo de gas
- Trazar el ciclo de vida completo de una transacción desde la firma hasta el cambio de estado
- Diferenciar el modelo account-based (Ethereum) del modelo UTXO (Bitcoin)

---

## 2. Prerequisitos

- Criptografía básica: funciones hash (SHA-256, Keccak-256), firma digital (ECDSA)
- Estructuras de datos: árboles, hash maps, listas enlazadas
- Nociones de redes distribuidas y tolerancia a fallas
- Familiaridad con hexadecimal y aritmética binaria
- Haber usado Ethereum como usuario (enviar transacciones, interactuar con contratos)

---

## 3. Conceptos clave

### 3.1 Estructura de bloques

Un bloque se compone de **header** y **body**.

**Block Header** (campos principales en Ethereum):

| Campo              | Descripción                                                  |
|--------------------|--------------------------------------------------------------|
| `parentHash`       | Hash del bloque anterior (encadena la blockchain)            |
| `stateRoot`        | Raíz de la Patricia Merkle Trie del estado global            |
| `transactionsRoot` | Raíz del Merkle tree de las transacciones del bloque         |
| `receiptsRoot`     | Raíz del Merkle tree de los recibos de ejecución             |
| `number`           | Altura del bloque                                            |
| `gasUsed`          | Gas total consumido por las transacciones del bloque         |
| `gasLimit`         | Límite de gas del bloque                                     |
| `timestamp`        | Marca temporal                                               |
| `baseFeePerGas`    | Tarifa base (EIP-1559)                                       |

**Block Body**: lista ordenada de transacciones firmadas.

El header actúa como un "compromiso criptográfico" de todo el contenido del bloque. Cualquier cambio en una sola transacción altera el `transactionsRoot`, que altera el hash del bloque, que rompe la cadena.

---

### 3.2 Merkle Trees

Un Merkle tree es un árbol binario de hashes que permite verificar la inclusión de un dato sin tener el conjunto completo.

```
                    Root Hash
                   /          \
              H(AB)            H(CD)
             /     \          /     \
          H(A)    H(B)    H(C)    H(D)
           |       |       |       |
          Tx A   Tx B    Tx C    Tx D
```

**Merkle Proof** para demostrar que Tx B está en el árbol:

```
  Se necesita: H(A), H(CD), y la Tx B

  Verificación:
  1. Calcular H(B) = hash(Tx B)
  2. Calcular H(AB) = hash(H(A) || H(B))
  3. Calcular Root = hash(H(AB) || H(CD))
  4. Comparar con Root Hash conocido
```

Complejidad del proof: **O(log n)** donde n es el número de hojas.

#### Patricia Merkle Trie (Ethereum)

Ethereum no usa un Merkle tree binario simple para el estado. Usa una **Modified Merkle Patricia Trie**, que combina:

- **Radix trie**: árbol de prefijos donde la clave es el path
- **Merkle tree**: cada nodo tiene el hash de sus hijos

Tipos de nodos:
- **Branch node**: 16 hijos (un nibble hexadecimal cada uno) + valor
- **Extension node**: comprime un path compartido
- **Leaf node**: contiene el valor final

El state trie mapea `address -> account state` donde cada account state contiene: `nonce`, `balance`, `storageRoot`, `codeHash`.

---

### 3.3 Mecanismos de consenso

#### Proof of Work (Nakamoto Consensus)

- Los mineros compiten para encontrar un nonce tal que `hash(block_header) < target`
- La cadena más larga (mayor trabajo acumulado) es la canónica
- Finalidad probabilística: cuantos más bloques encima, más difícil un reorg

#### Proof of Stake (Casper FFG + LMD GHOST)

Ethereum post-Merge usa dos componentes:

- **Casper FFG** (Friendly Finality Gadget): finalidad a nivel de epoch (32 slots = ~6.4 min). Los validators votan por checkpoints. Con 2/3 de votos, un checkpoint se finaliza.
- **LMD GHOST** (Latest Message Driven GHOST): fork-choice rule. Cada validator vota por el bloque más reciente que considera válido. Se sigue la rama con más peso de votos.

#### BFT Variants

- **Tendermint**: consenso BFT clásico. Bloques finalizados en 1-2 rondas. Tolera < 1/3 maliciosos. Usado en Cosmos.
- **HotStuff**: BFT lineal (O(n) mensajes por ronda). Base de LibraBFT. Pipeline de 3 fases.

#### Comparación

| Criterio           | PoW                | PoS (Casper)        | BFT (Tendermint)    |
|--------------------|--------------------|---------------------|---------------------|
| Finality time      | ~60 min (6 bloques)| ~13 min (2 epochs)  | ~6 seg (1 bloque)   |
| Energía            | Muy alta           | Baja                | Baja                |
| Descentralización  | Alta (permissionless) | Alta             | Media (validator set limitado) |
| Safety vs Liveness | Favorece liveness  | Balance             | Favorece safety     |
| Tolerancia a fallas| 50% hashpower      | 33% stake           | 33% validators      |

---

### 3.4 EVM Internals

La EVM (Ethereum Virtual Machine) es una **stack machine** de 256 bits.

#### Arquitectura

```
  +--------------------------------------------------+
  |                   EVM Instance                    |
  |                                                   |
  |  +----------+  +----------+  +-----------------+ |
  |  |  Stack   |  |  Memory  |  |    Storage      | |
  |  | (1024    |  | (linear, |  | (persistent,    | |
  |  |  items,  |  |  byte-   |  |  key-value,     | |
  |  |  256-bit |  |  addressed|  |  256-bit ->     | |
  |  |  each)   |  |  volatile)|  |  256-bit)       | |
  |  +----------+  +----------+  +-----------------+ |
  |                                                   |
  |  +----------+  +----------+                       |
  |  | Program  |  |Calldata  |                       |
  |  | Counter  |  |(input)   |                       |
  |  +----------+  +----------+                       |
  +--------------------------------------------------+
```

#### Opcodes fundamentales

| Opcode         | Descripción                                      | Gas (aprox)  |
|----------------|--------------------------------------------------|-------------|
| `PUSH1..32`    | Push valor al stack                              | 3           |
| `POP`          | Elimina el top del stack                         | 2           |
| `ADD/MUL/SUB`  | Aritmética básica                                | 3-5         |
| `SLOAD`        | Lee un slot de storage                           | 2100 (cold) |
| `SSTORE`       | Escribe un slot de storage                       | 20000 (nuevo valor) |
| `MLOAD/MSTORE` | Lee/escribe en memory                            | 3           |
| `CALL`         | Llama a otro contrato (nuevo contexto)           | variable    |
| `DELEGATECALL` | Llama usando storage del contrato actual         | variable    |
| `STATICCALL`   | Llamada de solo lectura (no puede mutar estado)  | variable    |
| `REVERT`       | Revierte la ejecución, devuelve gas restante     | 0           |

#### Storage Layout

El storage es un mapeo de slots de 256 bits a valores de 256 bits.

```
  Slot 0:  variable1 (uint256)
  Slot 1:  variable2 (address) + variable3 (uint96)  <- packing
  Slot 2:  variable4 (uint256)

  Mapping (slot n):
    mapping(address => uint256)
    Valor de key K está en: keccak256(K . n)
    donde "." es concatenación de 32 bytes

  Dynamic Array (slot n):
    length está en slot n
    element[i] está en: keccak256(n) + i
```

#### Memory Model

- Lineal, direccionada por bytes
- Se expande en palabras de 32 bytes
- Volátil: se reinicia por cada call context
- Costo de expansión: cuadrático más allá de cierto tamaño

---

### 3.5 Transaction Lifecycle

```
  Usuario                  Red P2P              Builder/Validator         EVM
    |                        |                        |                    |
    |  1. Crear Tx           |                        |                    |
    |  (to, value, data,     |                        |                    |
    |   gas, nonce)          |                        |                    |
    |                        |                        |                    |
    |  2. Firmar Tx          |                        |                    |
    |  (ECDSA -> v,r,s)      |                        |                    |
    |                        |                        |                    |
    |---3. Broadcast-------->|                        |                    |
    |                        |                        |                    |
    |                        |--4. Mempool----------->|                    |
    |                        |  (propagación P2P)     |                    |
    |                        |                        |                    |
    |                        |                   5. Selección de Txs      |
    |                        |                   (por gas price,          |
    |                        |                    MEV, ordering)          |
    |                        |                        |                    |
    |                        |                   6. Construir bloque      |
    |                        |                        |                    |
    |                        |                        |---7. Ejecutar----->|
    |                        |                        |   cada Tx          |
    |                        |                        |                    |
    |                        |                        |<--8. Receipt-------|
    |                        |                        |   (status, logs,   |
    |                        |                        |    gasUsed)        |
    |                        |                        |                    |
    |                        |                   9. Proponer bloque       |
    |                        |                   (attestations/votes)     |
    |                        |                        |                    |
    |                        |<--10. Bloque finalizado|                    |
    |                        |                        |                    |
    |<--11. Confirmación-----|                        |                    |
```

**Detalle de cada paso:**

1. **Creación**: el usuario define destinatario, valor, calldata, gas limit y nonce
2. **Firma**: la wallet firma con la clave privada (ECDSA sobre secp256k1)
3. **Broadcast**: la transacción firmada se envía a un nodo RPC
4. **Mempool**: el nodo la propaga por la red P2P. Cada nodo valida: firma, nonce, balance suficiente
5. **Selección**: el block builder ordena las transacciones (típicamente por gas price, con consideraciones MEV)
6. **Construcción**: se arma el bloque con las transacciones seleccionadas
7. **Ejecución**: la EVM ejecuta cada transacción secuencialmente, modificando el state trie
8. **Receipt**: se genera un recibo con status (1=éxito, 0=fallo), logs emitidos, gas usado
9. **Propuesta**: el validator propone el bloque; otros validators atestiguan
10. **Finalización**: tras suficientes attestations, el bloque se finaliza
11. **Confirmación**: el usuario verifica la inclusión de su transacción

---

### 3.6 Modelo de estado

#### Account-Based (Ethereum)

Cada cuenta tiene un estado global:

```
  Account {
    nonce:       uint64    // número de transacciones enviadas
    balance:     uint256   // saldo en Wei
    storageRoot: bytes32   // raíz del storage trie (solo contratos)
    codeHash:    bytes32   // hash del bytecode (solo contratos)
  }
```

- Las transferencias modifican directamente el balance de las cuentas
- Los contratos tienen su propio storage trie
- Ventaja: fácil de razonar sobre saldo actual
- Desventaja: problemas de concurrencia (nonce secuencial)

#### UTXO (Bitcoin)

- No hay concepto de "cuenta" con balance
- Existen UTXOs (Unspent Transaction Outputs)
- Una transacción consume UTXOs existentes y crea nuevos
- El "balance" es la suma de todos los UTXOs controlados por una clave

```
  Tx1: Alice -> Bob (1 BTC)
    Input:  UTXO_0 (Alice, 2 BTC)
    Output: UTXO_1 (Bob, 1 BTC)
            UTXO_2 (Alice, 0.999 BTC)  <- cambio
            Fee: 0.001 BTC
```

- Ventaja: paralelizable (UTXOs independientes), privacidad (nuevas direcciones por output)
- Desventaja: difícil modelar estado complejo (smart contracts limitados)

---

## 4. Análisis de casos reales

### 4.1 The Merge: Ethereum PoW -> PoS

**Contexto**: En septiembre 2022, Ethereum migró de Proof of Work a Proof of Stake.

**Decisiones de diseño:**
- Separación en dos capas: Execution Layer (EL) y Consensus Layer (CL/Beacon Chain)
- La Beacon Chain corrió en paralelo desde diciembre 2020 (>1 año de testing)
- Terminal Total Difficulty (TTD) como punto de merge: cuando el trabajo acumulado alcanzó un valor específico, la cadena PoW se fusionó con la Beacon Chain
- No se migró el estado: el state trie se mantuvo intacto

**Resultados:**
- Reducción de ~99.95% en consumo energético
- Finality time: ~13 minutos (2 epochs)
- Base para futuro sharding (danksharding)

**Lección arquitectónica**: una migración de esta escala requiere ejecución en paralelo prolongada y un punto de switch determinístico.

### 4.2 Solana: ejecución paralela vs Ethereum secuencial

**Ethereum**: ejecuta transacciones secuencialmente. Cada transacción ve el estado resultante de la anterior. Simplicidad a costa de throughput.

**Solana (Sealevel runtime)**:
- Las transacciones declaran explícitamente qué cuentas leen/escriben
- El runtime identifica transacciones sin conflictos y las ejecuta en paralelo
- Proof of History (PoH): reloj criptográfico que ordena eventos sin consenso
- Resultado: ~400ms block time, miles de TPS

**Trade-off**: Solana sacrifica simplicidad del modelo de programación (debes declarar accounts) y tiene una red de validators más centralizada (hardware requirements altos).

---

## 5. Ejercicio de diseño

### Diagrama del ciclo completo de un swap en Uniswap

**Tarea**: Diagramar el ciclo de vida completo de un swap en Uniswap V2, desde la firma del usuario hasta el cambio de estado. Debe incluir:

1. **Gas estimation**: cómo el frontend estima el gas necesario (eth_estimateGas simulando la ejecución)
2. **Construcción de la transacción**: qué calldata se genera (function selector + parámetros ABI-encoded)
3. **Firma y broadcast**: ECDSA signing, envío al RPC node
4. **Mempool**: propagación, validación, exposición a MEV (sandwich attacks)
5. **Block building**: cómo un builder incluye la transacción (PBS - Proposer-Builder Separation)
6. **EVM Execution**: traza de opcodes relevantes:
   - CALL al Router
   - DELEGATECALL si aplica
   - SLOAD para leer reserves
   - Cálculo de amountOut (getAmountOut)
   - Transfer de tokens (CALL a ERC-20)
   - SSTORE para actualizar reserves
   - Emit Swap event (LOG4)
7. **State trie updates**: qué slots de storage cambian en qué contratos
8. **Receipt generation**: logs, gas used, status

**Formato de entrega**: documento con diagramas ASCII o draw.io, explicación paso a paso.

---

## 6. Trade-offs y decisiones

| Decisión                        | Opción A                    | Opción B                     | Consideración                          |
|---------------------------------|-----------------------------|------------------------------|----------------------------------------|
| Modelo de estado                | Account-based               | UTXO                         | Expresividad vs paralelismo            |
| Ejecución                       | Secuencial                  | Paralela                     | Simplicidad vs throughput              |
| Consenso finality               | Probabilístico (PoW)        | Determinístico (BFT)         | Liveness vs safety                     |
| Block size                      | Pequeño (descentralizado)   | Grande (más throughput)      | Descentralización vs escalabilidad     |
| State storage                   | On-chain (todo verificable) | Stateless (proofs)           | Accesibilidad vs requerimientos de nodo|
| Gas model                       | Fijo por opcode             | Dinámico (EIP-1559)          | Predictibilidad vs eficiencia de mercado|

**Trilemma fundamental**: Descentralización vs Throughput vs Finality Speed. No puedes optimizar las tres simultáneamente. Cada blockchain hace una elección explícita o implícita.

---

## 7. Recursos

### Papers
- [Bitcoin Whitepaper](https://bitcoin.org/bitcoin.pdf) - Satoshi Nakamoto (2008)
- [Ethereum Yellowpaper](https://ethereum.github.io/yellowpaper/paper.pdf) - Gavin Wood
- [Casper FFG](https://arxiv.org/abs/1710.09437) - Buterin, Griffith
- [HotStuff](https://arxiv.org/abs/1803.05069) - Yin et al.

### Documentación
- [Ethereum EVM Handbook](https://noxx3xxon.notion.site/The-EVM-Handbook-bb38e175cc404111a391907c4975426d)
- [evm.codes](https://www.evm.codes/) - Referencia interactiva de opcodes
- [Ethereum Execution Specs](https://github.com/ethereum/execution-specs)
- [Ethereum Consensus Specs](https://github.com/ethereum/consensus-specs)

### Talks
- [Ethereum in 30 minutes](https://www.youtube.com/watch?v=UihMqcj-cqc) - Vitalik Buterin
- [Understanding the EVM](https://www.youtube.com/watch?v=RxL_1AfV7N4) - Owen Thurm
- [Merkle Trees and Patricia Tries](https://www.youtube.com/watch?v=OxofT39TJgg)

### Herramientas
- [Tenderly](https://tenderly.co/) - Debugger de transacciones y simulación
- [Etherscan](https://etherscan.io/) - Explorador con traza de opcodes
- [Remix](https://remix.ethereum.org/) - IDE con debugger EVM paso a paso

---

## 8. Checkpoint

Antes de avanzar al siguiente módulo, verifica que puedes:

- [ ] Explicar cada campo del block header y su propósito
- [ ] Construir un Merkle proof a mano para un conjunto de 8 transacciones
- [ ] Describir la diferencia entre Merkle tree binario y Patricia Merkle Trie
- [ ] Comparar PoW, PoS (Casper) y Tendermint en al menos 4 dimensiones
- [ ] Trazar la ejecución de un contrato simple a nivel de opcodes EVM
- [ ] Explicar por qué SSTORE es tan caro (20,000 gas) vs MSTORE (3 gas)
- [ ] Calcular la ubicación en storage de un valor en un mapping: `keccak256(key . slot)`
- [ ] Dibujar el ciclo de vida completo de una transacción (los 11 pasos)
- [ ] Explicar la diferencia entre CALL, DELEGATECALL y STATICCALL
- [ ] Argumentar pros y contras de account-based vs UTXO
- [ ] Completar el ejercicio de diseño del swap en Uniswap
