# Modulo 08: MEV and Transaction Ordering

## Objetivo

Al completar este modulo seras capaz de:

- Comprender que es MEV (Maximum Extractable Value) y por que es fundamental en el diseno de protocolos
- Identificar los tipos de MEV: arbitrage, liquidations, sandwich attacks, JIT liquidity
- Analizar el MEV supply chain post-PoS: searchers, builders, proposers, relayers
- Entender PBS (Proposer-Builder Separation) y su implementacion via MEV-Boost
- Evaluar el impacto de MEV en diferentes protocolos (DEXes, lending, NFTs)
- Disenar mecanismos MEV-resistant: batch auctions, commit-reveal, encrypted mempools
- Analizar el ecosistema Flashbots y su evolucion

---

## Prerequisitos

- Conocimiento profundo de como funcionan las transacciones en Ethereum (mempool, gas, inclusion)
- Entendimiento de AMMs (Uniswap v2/v3) y como se determinan precios
- Familiaridad con protocolos de lending (Aave, Compound) y su mecanismo de liquidacion
- Conceptos basicos de teoria de juegos y mecanismos de subasta
- Modulos anteriores del track de arquitecto completados (01-07)

---

## Conceptos clave

### 1. Que es MEV

MEV (Maximum Extractable Value) es el valor maximo que puede ser extraido de la produccion de un bloque mas alla de la recompensa estandar del bloque y las fees de gas, mediante la inclusion, exclusion o reordenamiento de transacciones.

```
   EVOLUCION DEL TERMINO
   ======================

   Pre-Merge (PoW):                    Post-Merge (PoS):
   "Miner Extractable Value"           "Maximum Extractable Value"

   Mineros decidian el orden           Validators proponen bloques
   de transacciones en bloques         pero builders los construyen

   En ambos casos: quien controla el orden de transacciones
   puede extraer valor adicional.
```

**La intuicion fundamental**: En blockchain, las transacciones tienen un orden dentro de cada bloque. Este orden afecta los resultados (precios, liquidaciones, etc.). Quien controla el orden puede beneficiarse.

```
   POR QUE EXISTE MEV
   ====================

   Mempool publica                     Bloque final
   (transacciones pendientes)          (transacciones ordenadas)

   +---------------------------+       +---------------------------+
   | TX-A: Swap 100K USDC->ETH|       | 1. TX-X: Arb buy ETH     |
   | TX-B: Liquidar posicion  |       | 2. TX-A: Swap 100K       |
   | TX-C: Mint NFT           | ----> | 3. TX-Y: Arb sell ETH    |
   | TX-D: Transferir tokens  |       | 4. TX-B: Liquidar        |
   | TX-E: Deposit en Aave   |       | 5. TX-C: Mint NFT        |
   +---------------------------+       | 6. TX-D: Transfer        |
                                       | 7. TX-E: Deposit         |
   Las TX en mempool son publicas      +---------------------------+
   Cualquiera puede ver y actuar
                                       TX-X y TX-Y son del searcher:
                                       sandwich attack en TX-A
```

---

### 2. Tipos de MEV

#### 2.1 Arbitrage

Explotar diferencias de precio entre DEXes o pools.

```
   DEX ARBITRAGE
   ==============

   Uniswap: 1 ETH = 2,000 USDC
   Sushiswap: 1 ETH = 2,010 USDC

   Searcher:
   1. Compra 1 ETH en Uniswap por 2,000 USDC
   2. Vende 1 ETH en Sushiswap por 2,010 USDC
   3. Profit: 10 USDC (menos gas)

   Esto es MEV "bueno":
   - Alinea precios entre mercados
   - Mejora eficiencia del mercado
   - Los precios convergen mas rapido

   Pero genera competencia extrema:
   - Priority Gas Auctions (PGAs)
   - Latencia importa (similar a HFT)
   - Gas fees infladas para todos
```

#### 2.2 Liquidations

En protocolos de lending, las posiciones bajo-colateralizadas pueden ser liquidadas. Los searchers compiten por ser los primeros en liquidar.

```
   LIQUIDATION MEV
   ================

   Aave/Compound:

   Posicion de Alice:
   Collateral: 10 ETH ($20,000)
   Deuda: 15,000 USDC
   Health Factor: 1.33
   Liquidation Threshold: 80% (HF < 1.0 = liquidable)

   Si ETH cae a $1,400:
   Collateral: 10 ETH ($14,000)
   Deuda: 15,000 USDC
   Health Factor: 0.93 <-- LIQUIDABLE

   Searcher liquida:
   1. Paga 7,500 USDC de la deuda de Alice (50%)
   2. Recibe 5 ETH + bonus (5%) = 5.25 ETH
   3. 5.25 ETH * $1,400 = $7,350
   4. Pago: $7,500 USDC
   5. Net profit: $7,350 - $7,500 + liquidation bonus...

   En realidad usan flash loans para capital cero:
   1. Flash loan 7,500 USDC
   2. Liquidar posicion
   3. Recibir ETH con bonus
   4. Swap ETH -> USDC
   5. Repagar flash loan + fee
   6. Quedarse con el profit
```

#### 2.3 Sandwich Attacks

El tipo de MEV mas danino para usuarios. El searcher coloca una transaccion antes (front-run) y despues (back-run) de la transaccion victima.

```
   SANDWICH ATTACK (DETALLE)
   ==========================

   Mempool: Alice quiere swap 100,000 USDC -> ETH
            (slippage tolerance: 1%)

   Precio actual ETH: $2,000
   Alice esperaria: ~50 ETH

   Searcher detecta TX de Alice en mempool:

   +------+----------------------------------------------+----------+
   | Paso | Transaccion                                  | Precio   |
   +------+----------------------------------------------+----------+
   | 1    | Searcher: Compra ETH con USDC (front-run)   | $2,000   |
   |      | Mueve el precio hacia arriba                 |          |
   +------+----------------------------------------------+----------+
   | 2    | Alice: Swap 100K USDC -> ETH                | $2,015   |
   |      | Recibe menos ETH del esperado               | (peor)   |
   |      | Pero dentro de su slippage tolerance         |          |
   +------+----------------------------------------------+----------+
   | 3    | Searcher: Vende ETH por USDC (back-run)     | $2,018   |
   |      | Precio aun mas alto por impacto de Alice    |          |
   +------+----------------------------------------------+----------+

   Resultado:
   - Alice recibe ~49.6 ETH en vez de ~50 ETH (pierde ~$800)
   - Searcher gana ~$500 (despues de gas)
   - El $300 restante va a gas/tips (deadweight loss)

   Visualizacion del precio durante el bloque:

   Precio ETH
   $2,020 |           * (back-run sell)
   $2,015 |       * (Alice swap)
   $2,010 |     /
   $2,005 |   /
   $2,000 | * (front-run buy)
          +-------------------------> Orden en bloque
```

#### 2.4 Just-in-Time (JIT) Liquidity

Un tipo sofisticado de MEV en Uniswap v3: el searcher provee liquidez concentrada justo antes de un swap grande y la retira justo despues.

```
   JIT LIQUIDITY
   ==============

   Uniswap v3: Liquidez concentrada en ranges

   Antes del swap de Alice (100K USDC -> ETH):

   Liquidez en el rango actual:
   |####|     <-- Liquidez existente (de LPs normales)

   Searcher ve TX de Alice y actua:

   Paso 1 (justo antes de Alice):
   |####|
   |####|
   |########| <-- Searcher agrega liquidez concentrada

   Paso 2 (swap de Alice ejecuta):
   Alice obtiene mejor precio (mas liquidez = menos slippage)
   PERO las fees van mayoritariamente al searcher

   Paso 3 (justo despues de Alice):
   |####|     <-- Searcher retira su liquidez + fees earned

   Es MEV "gris":
   + Alice obtiene mejor ejecucion
   - LPs normales pierden fees (el searcher se las lleva)
   - Desincentiva provision de liquidez pasiva
```

---

### 3. MEV Supply Chain (Post-PoS Ethereum)

Despues del Merge (Sept 2022), el ecosistema MEV se profesionalizo en una cadena de suministro especializada.

```
   MEV SUPPLY CHAIN
   ==================

   +------------------------------------------------------------------+
   |                                                                    |
   |  1. SEARCHERS                                                     |
   |  +------------------------------------------------------------+  |
   |  | - Monitorizan mempool y estado on-chain                    |  |
   |  | - Identifican oportunidades de MEV                         |  |
   |  | - Crean "bundles" (conjuntos atomicos de transacciones)    |  |
   |  | - Pagan tips a builders por inclusion                      |  |
   |  +------------------------------+-----------------------------+  |
   |                                 |                                 |
   |                                 v                                 |
   |  2. BUILDERS                                                      |
   |  +------------------------------------------------------------+  |
   |  | - Reciben bundles de searchers + TXs del mempool publico   |  |
   |  | - Construyen bloques optimos (maximizan valor)             |  |
   |  | - Compiten entre si por construir el bloque mas valioso    |  |
   |  | - Envian bloques sellados a relayers                       |  |
   |  +------------------------------+-----------------------------+  |
   |                                 |                                 |
   |                                 v                                 |
   |  3. RELAYERS                                                      |
   |  +------------------------------------------------------------+  |
   |  | - Intermediarios entre builders y proposers                |  |
   |  | - Verifican bloques son validos                            |  |
   |  | - Previenen que proposers roben MEV (bloques sellados)     |  |
   |  | - Ej: Flashbots relay, bloXroute, Ultrasound              |  |
   |  +------------------------------+-----------------------------+  |
   |                                 |                                 |
   |                                 v                                 |
   |  4. PROPOSERS (Validators)                                        |
   |  +------------------------------------------------------------+  |
   |  | - Eligen el bloque con mayor bid del relay                 |  |
   |  | - No ven el contenido del bloque (sealed bid)              |  |
   |  | - Proponen el bloque a la red                              |  |
   |  | - Reciben: base reward + tips + MEV payment                |  |
   |  +------------------------------------------------------------+  |
   |                                                                    |
   +------------------------------------------------------------------+

   Flujo de valor:
   Users --[fees]--> Searchers --[tips]--> Builders --[bids]--> Proposers
```

```
   DISTRIBUCION DE MEV VALUE
   ==========================

   Total MEV extraido
   |==================================================| 100%
   |################|||||||||||||||||||||@@@@@@@@@@@@@@|
   |  Searchers     |  Builders        |  Proposers   |
   |  ~20-30%       |  ~10-20%         |  ~50-70%     |

   La competencia entre searchers y builders resulta en que
   la mayoria del valor fluye hacia los proposers (validators).
   Esto es por diseno: los searchers/builders compiten,
   los validators se benefician.
```

---

### 4. PBS (Proposer-Builder Separation)

#### 4.1 Por que PBS

Antes de PBS, los validators construian Y proponian bloques. Esto significaba que validators sofisticados (con capacidad de extraer MEV) tenian ventaja sobre validators simples, centralizando el staking.

```
   SIN PBS (PROBLEMATICO)
   =======================

   Validator A (sofisticado):
   - Puede extraer MEV
   - Gana: block reward + MEV
   - Incentivo a ser grande y sofisticado

   Validator B (simple, home staker):
   - No puede extraer MEV
   - Gana: solo block reward
   - En desventaja economica

   Resultado: Centralizacion de validators hacia
   entidades sofisticadas (mala para descentralizacion)


   CON PBS (SOLUCION)
   ===================

   Builders (especializados): Compiten por construir bloques
   Proposers (validators): Solo eligen el bloque con mayor bid

   Validator A y B reciben el MISMO MEV (via bids de builders)
   --> Home stakers no estan en desventaja
   --> Mejor descentralizacion
```

#### 4.2 MEV-Boost (Out-of-Protocol PBS)

MEV-Boost es la implementacion actual de PBS, desarrollada por Flashbots. No es parte del protocolo Ethereum, es un sidecar que los validators ejecutan voluntariamente.

```
   MEV-BOOST ARCHITECTURE
   =======================

   Consensus Client     MEV-Boost          Relay            Builder
   (Validator)          (Sidecar)
   +-----------+        +---------+        +-------+        +--------+
   |           | 1. Req |         | 2. Req |       | 2. Req |        |
   | Cuando    | header | Proxy   | header | Forward|       | Build  |
   | toca      +------->+ a relay +------->+ to     +<------+ block  |
   | proponer  |        |         |        | builder|       |        |
   |           | 4. Get |         | 3. Ret |       |       |        |
   | block     | full   | Return  | header | Return |       |        |
   |           +<-------+ full    +<-------+ header |       |        |
   | Propone   | block  | block   | + bid  |+ bid   |       |        |
   +-----------+        +---------+        +-------+        +--------+

   Flujo:
   1. Validator pide header al relay (via MEV-Boost)
   2. Relay solicita bloques a builders
   3. Builders envian bloques sellados + bids al relay
   4. Relay envia el header con mayor bid al validator
   5. Validator firma el header (commit sin ver contenido)
   6. Relay revela el bloque completo
   7. Validator propone el bloque a la red

   Proteccion: El validator NO ve el contenido del bloque,
   solo el bid. No puede "robar" las oportunidades de MEV.
```

#### 4.3 ePBS (Enshrined PBS)

Propuesta para incluir PBS directamente en el protocolo de Ethereum.

```
   ePBS vs MEV-BOOST
   ===================

   MEV-Boost (actual):
   + Funciona hoy
   + No requiere hard fork
   - Trust assumptions en relays
   - Relays como punto de censura
   - No es mandatory (validators pueden no usarlo)

   ePBS (propuesto):
   + Trustless (en-protocol)
   + Sin dependencia de relays
   + Mandatory para todos los validators
   - Requiere hard fork de Ethereum
   - Complejidad en el protocolo
   - Diseno aun en investigacion

   Estado actual: ePBS es parte del roadmap de Ethereum
   pero su implementacion tomara anos.
```

---

### 5. Flashbots

#### 5.1 Flashbots Auction

```
   FLASHBOTS AUCTION
   ==================

   Problema original: Priority Gas Auctions (PGAs)
   - Searchers competian subiendo gas price
   - Congestionaban la red para TODOS los usuarios
   - Gas fees infladas artificialmente
   - Failed transactions = gas desperdiciado

   Solucion Flashbots: Auction privada, off-chain

   Regular Mempool:                    Flashbots Bundle:
   +-------------------+              +-------------------+
   | TX visible a      |              | Bundle enviado    |
   | TODOS los nodos   |              | SOLO al builder   |
   | Competencia via   |              | Sealed bid        |
   | gas price publica |              | Si falla = no gas |
   +-------------------+              +-------------------+

   Beneficios:
   - No congestion de la red
   - Privacidad pre-trade (no front-running entre searchers)
   - Eficiencia: sin failed transactions
   - Precio justo via auction
```

#### 5.2 Flashbots Protect

```
   FLASHBOTS PROTECT (para usuarios)
   ===================================

   Problema: Usuarios normales son victimas de sandwich attacks

   Solucion: RPC endpoint que envia TXs directamente a builders,
   saltando el mempool publico

   Flujo normal (vulnerable):
   User -> Public Mempool -> Searchers ven TX -> Sandwich attack

   Flujo con Protect:
   User -> Flashbots Protect RPC -> Builder directamente
   (TX nunca pasa por mempool publico)

   Configuracion:
   - Agregar RPC a MetaMask: https://rpc.flashbots.net
   - Las TXs van directamente a Flashbots builder
   - Si no se incluyen en X bloques, se envian al mempool

   Limitaciones:
   - Solo protege contra sandwich (no contra otros tipos de MEV)
   - Dependencia del builder de Flashbots
   - Puede ser mas lento que mempool publico
```

#### 5.3 SUAVE (Single Unified Auction for Value Expression)

```
   SUAVE VISION
   ==============

   Problema actual:
   - Block building esta centralizado (2-3 builders dominan)
   - Searchers dependen de builders especificos
   - Cross-chain MEV no tiene infraestructura

   SUAVE propone:
   +--------------------------------------------------+
   |  SUAVE Chain (specialized blockchain)             |
   |                                                    |
   |  - Decentralized block building                   |
   |  - Cross-chain MEV management                     |
   |  - Programmable privacy (users set preferences)   |
   |  - Sealed-bid auctions en-protocol               |
   |                                                    |
   |  Componentes:                                     |
   |  1. Universal preference environment              |
   |  2. Optimal execution market                      |
   |  3. Decentralized block building                  |
   +--------------------------------------------------+

   Estado: En desarrollo activo, testnet.
   Timeline: Años antes de produccion.
```

---

### 6. MEV Impact en Protocolos

#### 6.1 DEXes

```
   MEV EN DEXes
   ==============

   Impacto por tipo:

   +------------------+-------------+-------------------+
   | Tipo MEV         | Frecuencia  | Impacto usuario   |
   +------------------+-------------+-------------------+
   | Sandwich attacks | Muy alta    | Peor precio       |
   |                  |             | (0.5-2% perdida)  |
   +------------------+-------------+-------------------+
   | Arbitrage        | Muy alta    | Indirecto         |
   |                  |             | (precios mejores) |
   +------------------+-------------+-------------------+
   | JIT liquidity    | Media       | Mejor ejecucion   |
   |                  |             | (pero LPs pierden)|
   +------------------+-------------+-------------------+

   Costo estimado para traders:
   - Swaps > $10K USDC: ~0.5-1% de costo adicional por sandwich
   - Esto equivale a BILLONES de dolares anuales extraidos de usuarios
```

#### 6.2 Lending

```
   MEV EN LENDING
   ===============

   Liquidaciones:
   - Multiples searchers compiten por la misma liquidacion
   - El primero que incluye la TX gana
   - Genera: priority gas auctions, failed TXs

   Oracle updates:
   - Cuando un oracle actualiza precio, se abren oportunidades
   - Searchers monitorizan mempool por oracle update TXs
   - Envian liquidaciones en el mismo bloque

   Impacto en borrowers:
   - Liquidaciones mas agresivas (searchers son rapidos)
   - Menos tiempo para reaccionar a caidas de precio
   - Liquidation bonus va mayoritariamente a searchers, no al protocolo
```

#### 6.3 NFT Mints

```
   MEV EN NFT MINTS
   ==================

   Mint popular (ej: 10,000 NFTs, demand >> supply):

   Bloque N:
   +--------------------------------------------------+
   | TX-1: Mint (gas: 500 gwei)    <-- Whale          |
   | TX-2: Mint (gas: 450 gwei)    <-- Bot            |
   | TX-3: Mint (gas: 400 gwei)    <-- Bot            |
   | ...                                               |
   | TX-50: Mint (gas: 100 gwei)   <-- Usuario normal |
   | TX-51: REVERTED (sold out)    <-- Usuario normal  |
   +--------------------------------------------------+

   Resultado:
   - Gas fees se disparan (toda la red afectada)
   - Usuarios normales pagan gas por TXs que fallan
   - Bots/whales obtienen la mayoria de los NFTs

   Mitigaciones comunes:
   - Allowlists (whitelist pre-aprobada)
   - Dutch auctions (precio baja gradualmente)
   - Commit-reveal (compromiso previo, reveal posterior)
```

---

### 7. Disenando Protocolos MEV-Resistant

#### 7.1 Batch Auctions

```
   BATCH AUCTION (CowSwap Model)
   ==============================

   En vez de ejecutar swaps uno por uno (vulnerable a ordering),
   se agrupan en batches y se ejecutan al mismo precio.

   Batch Period (ej: 30 segundos):
   +--------------------------------------------------+
   | Ordenes recibidas:                                |
   | - Alice: Sell 10 ETH for USDC (limit: $1,950)    |
   | - Bob: Buy 5 ETH with USDC (limit: $2,050)       |
   | - Charlie: Sell 3 ETH for USDC (limit: $1,980)   |
   | - Diana: Buy 8 ETH with USDC (limit: $2,020)     |
   +--------------------------------------------------+
              |
              v
   Solver Competition:
   +--------------------------------------------------+
   | Solvers proponen settlement:                      |
   | - Precio uniforme: $2,000/ETH                    |
   | - Alice sells 10 ETH at $2,000 (satisfied)       |
   | - Bob buys 5 ETH at $2,000 (satisfied)           |
   | - Charlie sells 3 ETH at $2,000 (satisfied)      |
   | - Diana buys 8 ETH at $2,000 (satisfied)         |
   | - Surplus: distribuido a usuarios                 |
   +--------------------------------------------------+

   Por que es MEV-resistant:
   1. Ordenes no estan en mempool (off-chain submission)
   2. Precio uniforme: no hay ventaja en el ordering
   3. Coincidence of Wants (CoW): Alice vende a Bob directamente
   4. Sin sandwich: no hay front-run posible en batch
```

#### 7.2 Commit-Reveal Schemes

```
   COMMIT-REVEAL
   ==============

   Fase 1: COMMIT (bloque N)
   +------------------------------------------+
   | Usuario envia: hash(order + salt)         |
   | Nadie puede ver la orden real             |
   | Ni el contenido, ni la direccion del swap |
   +------------------------------------------+

   Fase 2: REVEAL (bloque N+1 o N+2)
   +------------------------------------------+
   | Usuario revela: order + salt              |
   | Smart contract verifica hash              |
   | Orden se ejecuta                          |
   +------------------------------------------+

   Ventaja: Sandwich attacks imposibles (no saben que viene)
   Desventaja:
   - 2 transacciones en vez de 1 (doble gas)
   - Latencia (esperar bloque de reveal)
   - Usuarios pueden no revelar (griefing)
```

#### 7.3 Encrypted Mempools

```
   ENCRYPTED MEMPOOL (Threshold Encryption)
   ==========================================

   1. Usuario encripta TX con clave publica del comite
   2. TX encriptada entra al mempool (nadie puede leerla)
   3. Builders incluyen TXs encriptadas en bloque
   4. Despues de inclusion, comite descifra con threshold
   5. TXs se ejecutan

   +----------+     TX encriptada     +----------+
   | Usuario  | --------------------> | Mempool  |
   | encripta |                       | (no se   |
   | con PK   |                       | puede    |
   +----------+                       | leer)    |
                                      +----+-----+
                                           |
                                      +----v-----+
                                      | Builder  |
                                      | incluye  |
                                      | sin ver  |
                                      +----+-----+
                                           |
                                      +----v-----+
                                      | Threshold|
                                      | Decrypt  |
                                      | Committee|
                                      +----+-----+
                                           |
                                      +----v-----+
                                      | Ejecutar |
                                      | TXs      |
                                      +----------+

   Proyectos: Shutter Network, SUAVE (parcial)

   Trade-off: Elimina MEV de ordering, pero introduce
   latencia y dependencia del comite de descifrado
```

#### 7.4 Order Flow Auctions (OFAs)

```
   ORDER FLOW AUCTION
   ====================

   En vez de que los searchers capturen el valor del order flow,
   el protocolo subasta el derecho de ejecutar ordenes.

   1. Usuario envia orden al protocolo
   2. Protocolo subasta la orden a searchers/solvers
   3. Searchers pujan por el derecho de ejecutar
   4. El mejor bid gana (mejor precio para usuario)
   5. La diferencia entre ejecucion y bid = MEV redistribuido

   +----------+   Orden    +----------+   Subasta   +-----------+
   | Usuario  | ---------> | OFA      | ----------> | Searchers |
   |          |            | Protocol |             | compiten  |
   |          | <--------- |          | <---------- |           |
   +----------+   Mejor    +----------+   Mejor     +-----------+
                  ejecucion             bid

   Ejemplo: MEV-Share (Flashbots)
   - Usuarios comparten parcialmente info de sus TXs
   - Searchers pujan por backrun rights
   - Profit se divide: searcher + usuario
```

---

## Analisis de casos reales

### Flashbots: De Research Org a Infraestructura

```
   EVOLUCION DE FLASHBOTS
   =======================

   2020: Flashbots Research
   - Paper "Flash Boys 2.0" identifica el problema
   - Comunidad de investigadores

   2021: Flashbots Auction (Pre-Merge)
   - Mev-geth: fork de geth con bundle submission
   - Adopcion masiva por miners
   - Reduce PGAs significativamente

   2022: MEV-Boost (Post-Merge)
   - PBS implementado como sidecar
   - 90%+ de validators usan MEV-Boost
   - Relay como infraestructura critica

   2023: MEV-Share
   - Order Flow Auctions
   - Redistribucion de MEV a usuarios
   - Flashbots Protect actualizado

   2024+: SUAVE
   - Block building descentralizado
   - Cross-chain MEV
   - Programmable privacy

   Critica: Flashbots se ha convertido en infraestructura critica
   con un solo punto de fallo. Ironia: descentralizar MEV
   con infraestructura centralizada.
```

### CowSwap: Batch Auctions + Solver Competition

```
   COWSWAP ARCHITECTURE
   =====================

   +----------+     Intent      +------------+
   | Usuario  | -------------> | CowSwap    |
   | firma    |   (off-chain   | Protocol   |
   | intent   |    signed msg) |            |
   +----------+                +-----+------+
                                     |
                               Batch cada ~30 seg
                                     |
                                     v
                              +------+------+
                              | Solver      |
                              | Competition |
                              +------+------+
                                     |
                    +----------------+----------------+
                    |                |                |
              +-----v----+   +------v-----+   +-----v-----+
              | Solver A  |   | Solver B   |   | Solver C  |
              | Propone   |   | Propone    |   | Propone   |
              | settlement|   | settlement |   | settlement|
              +----------+   +------------+   +-----------+
                    |                |                |
                    v                v                v
              Evaluacion: Quien da mejor precio al usuario?
              Winner on-chain settlement via CoW Protocol

   Innovaciones:
   1. Coincidence of Wants: match ordenes directamente
      (sin pasar por AMM = cero price impact)
   2. Solver competition: multiples estrategias compiten
   3. Uniform clearing price: mismo precio para todos en batch
   4. Surplus: excedente de precio va al usuario
```

### MEV en Solana: Diferente Dinamica

```
   MEV EN SOLANA
   ==============

   Solana vs Ethereum MEV:

   +-------------------+-------------------+-------------------+
   |                   | Ethereum          | Solana            |
   +-------------------+-------------------+-------------------+
   | Mempool           | Publica           | No hay mempool*   |
   | Block time        | 12 segundos       | 400 ms            |
   | Block builder     | Separado (PBS)    | Validator = builder|
   | MEV infra         | Flashbots, MEV-   | Jito              |
   |                   | Boost             |                   |
   | Tipo dominante    | Sandwich, arb     | Arb, liquidations |
   +-------------------+-------------------+-------------------+

   *Solana usa un leader schedule: el proximo validator
   ya esta determinado, y las TXs van directamente al leader.

   Jito (MEV en Solana):
   - Jito-Solana: fork del validator client con bundle support
   - Block engine: similar a Flashbots relay
   - Tip distribution: MEV tips van al validator + stakers
   - Controversia: Jito shut down su mempool servicio en 2024
     despues de criticas sobre sandwich attacks
```

### La Crisis de Censura MEV (2023)

```
   CENSURA VIA MEV-BOOST
   =======================

   Situacion:
   - OFAC sanciona Tornado Cash (Agosto 2022)
   - Flashbots relay comienza a censurar TXs de Tornado Cash
   - >90% de validators usan MEV-Boost via Flashbots relay
   - Resultado: TXs de Tornado Cash tardaban mucho mas en incluirse

   Porcentaje de bloques que cumplen OFAC:

   Nov 2022: ~78% de bloques censuraban Tornado Cash TXs

   |########################################                    | 78%

   Esto genero debate:
   - Es MEV infra un punto de censura?
   - Deberian los relays ser neutrales?
   - El builder centralizado amenaza la censorship resistance?

   Respuesta del ecosistema:
   - Relays alternativos (Ultrasound, bloXroute sin filtro)
   - Min-bid feature: validators aceptan bloques locales si
     el bid del relay no supera un minimo
   - Investigacion en ePBS y encrypted mempools
   - Para 2024: censura bajó significativamente (<30%)
```

---

## Ejercicio de diseno

### Analizar MEV en un Lending Protocol

**Escenario**: Estas disenando un protocolo de lending similar a Aave v3. Necesitas analizar y mitigar el MEV que afecta a tus usuarios.

**Parte 1: Identificacion de MEV**

Documenta cada tipo de MEV que existe en tu protocolo:
1. **Liquidation MEV**: Quien lo extrae, cuanto vale, como afecta a borrowers
2. **Oracle update MEV**: Que pasa cuando se actualiza un oracle, que oportunidades se abren
3. **Interest rate arbitrage**: Cambios en utilization rate crean oportunidades
4. **Collateral swap MEV**: Si permites cambiar collateral, hay MEV en el ordering

**Parte 2: Analisis de impacto**

Para cada tipo de MEV:
- Cuantifica el valor extraido (en terminos de % del TVL)
- Identifica quien lo paga (borrowers, depositors, el protocolo)
- Evalua si es MEV "bueno" (eficiencia) o "malo" (extraction)

**Parte 3: Diseno de mitigaciones**

Para tu protocolo, disena:

1. **Liquidation auction design**:
   - Dutch auction vs sealed bid vs batch
   - Duracion de la subasta
   - Como evitar que un solo searcher domine liquidaciones
   - Penalty structure (liquidation bonus)

2. **Keeper incentives**:
   - Como incentivar liquidaciones sin crear competencia destructiva
   - Fee structure para keepers
   - Backup mechanism si ningun keeper actua

3. **Oracle update mechanism**:
   - Frecuencia de updates
   - TWAP vs spot price
   - Circuit breakers ante cambios drasticos
   - Delay entre update y liquidation permitida

4. **Protocol-level MEV capture**:
   - Puede el protocolo capturar MEV en vez de dejarlo a searchers?
   - Auction de liquidation rights
   - Redistribucion de MEV a depositors

---

## Trade-offs y decisiones

### MEV Extraction Efficiency vs User Costs

```
   +-------------------+-------------------+-------------------+
   |                   | FREE MARKET MEV   | MEV PROTECTION    |
   +-------------------+-------------------+-------------------+
   | Price discovery   | Rapida (arbs)     | Mas lenta         |
   | User cost         | Alto (sandwiches) | Bajo              |
   | Capital efficiency| Alta              | Puede ser menor   |
   | Complexity        | Simple protocol   | Complejo (OFAs)   |
   +-------------------+-------------------+-------------------+

   El arbitrage MEV mejora la eficiencia del mercado.
   El sandwich MEV solo extrae valor de usuarios.
   El reto es permitir lo bueno y bloquear lo malo.
```

### Censorship Resistance vs MEV Protection

```
   Encrypted mempools:
   + Eliminan sandwich attacks
   + Eliminan front-running
   - Requieren comite de threshold decryption
   - El comite puede censurar (si no descifra)
   - Latencia adicional

   MEV-Boost (relays):
   + Infraestructura existente
   + Eficiente
   - Relays pueden censurar
   - Centralizacion de block building

   No hacer nada:
   + Maxima censorship resistance (permissionless mempool)
   + Sin latencia adicional
   - Usuarios expuestos a todo tipo de MEV
```

### Protocol-Level MEV Capture vs Free Market

```
   Protocol captura MEV:
   + Valor va al protocolo/usuarios
   + Menos externalidades negativas
   - Mas complejidad
   - Posible menor eficiencia
   - Governance risk (quien controla la captura?)

   Free market:
   + Simple
   + Competencia reduce spreads
   - Valor va a searchers/builders
   - Usuarios pagan el costo
   - Gas wars en momentos de alta MEV

   Tendencia: Protocolos evolucionan hacia captura parcial
   (ej: Uniswap X, CowSwap, MEV-Share)
```

---

## Recursos

### Papers fundamentales
- "Flash Boys 2.0: Frontrunning, Transaction Reordering, and Consensus Instability" - Daian et al.
- "Flashbots: MEV in Eth2" - Flashbots Research
- "Order Fairness" - Kelkar et al.
- "MEV-SBC" (Science of Blockchain Conference) papers

### Documentacion tecnica
- Flashbots Docs: docs.flashbots.net
- MEV-Boost: github.com/flashbots/mev-boost
- CowSwap Docs: docs.cow.fi
- Jito Docs: jito-foundation.gitbook.io

### Dashboards y datos
- MEV-Boost Dashboard: mevboost.org
- Flashbots MEV-Explore: explore.flashbots.net
- EigenPhi: eigenphi.io (MEV analytics)
- libMEV: libmev.com

### Talks y presentaciones
- "MEV and Me" - Flashbots presentation series
- "The MEV Supply Chain" - Hasu & Georgios (Paradigm)
- "Censorship Resistance in MEV-Boost" - Ethereum Foundation research
- MEV-SBC Conference talks (annual)

### Herramientas
- Flashbots Bundle Explorer
- MEV-Inspect (open source MEV classifier)
- Jito Block Engine documentation

---

## Checkpoint

Antes de avanzar al siguiente modulo, verifica que puedes:

- [ ] Explicar que es MEV y por que el orden de transacciones importa
- [ ] Describir los 4 tipos principales de MEV (arbitrage, liquidations, sandwich, JIT) con ejemplos numericos
- [ ] Diagramar el MEV supply chain completo: searchers -> builders -> relayers -> proposers
- [ ] Explicar PBS y por que es necesario para la descentralizacion de Ethereum
- [ ] Describir la arquitectura de MEV-Boost y el flujo de un bloque
- [ ] Analizar como MEV afecta a DEXes, lending protocols y NFT mints de forma diferente
- [ ] Disenar al menos 2 mecanismos MEV-resistant (batch auctions, commit-reveal, encrypted mempool)
- [ ] Explicar el trade-off entre censorship resistance y MEV protection
- [ ] Completar el ejercicio de analisis de MEV en un lending protocol
- [ ] Evaluar la evolucion del ecosistema Flashbots y sus implicaciones para Ethereum
