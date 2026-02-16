# Modulo 09: System Design Cases

## Objetivo

Al completar este modulo seras capaz de:

- Disenar sistemas DeFi completos desde cero con justificacion de decisiones arquitectonicas
- Aplicar todos los conceptos de modulos anteriores en escenarios realistas
- Evaluar trade-offs entre seguridad, eficiencia de capital, descentralizacion y UX
- Producir documentos de diseno de nivel profesional para protocolos blockchain
- Responder preguntas de system design en entrevistas de arquitectura blockchain

---

## Prerequisitos

- Todos los modulos anteriores completados (01-08)
- Experiencia analizando protocolos DeFi existentes
- Familiaridad con smart contract design patterns
- Entendimiento de MEV, cross-chain, identity y security

---

## Formato de cada caso

Cada caso sigue una estructura de entrevista de system design:

```
   1. Problem Statement    --> Que estamos construyendo y por que
   2. Requirements         --> Funcionales y no funcionales
   3. Constraints          --> Limitaciones tecnicas y de negocio
   4. High-Level Design    --> Arquitectura general, componentes
   5. Detailed Design      --> Profundizacion en componentes criticos
   6. Trade-offs           --> Decisiones y sus implicaciones
   7. Open Questions       --> Temas abiertos para discusion
```

---

---

# Case 1: Design a DEX (Decentralized Exchange)

## Problem Statement

Disenar un exchange descentralizado que permita a usuarios intercambiar cualquier par de tokens ERC-20 de forma eficiente, segura y composable.

El DEX debe ser competitivo con Uniswap v3 en terminos de eficiencia de capital y con exchanges centralizados en terminos de experiencia de usuario.

## Requirements

**Funcionales:**
- Soporte para cualquier par de tokens ERC-20
- Provision de liquidez por cualquier usuario
- Swap atomico (falla o tiene exito completamente)
- Oracle de precios para consumo externo (TWAP)
- Fee tiers configurables por pool
- Posiciones de liquidez como NFTs (transferibles)

**No funcionales:**
- Gas efficiency: swap no debe superar 150K gas
- Slippage minimo para trades de tamaño razonable
- Composabilidad total (otros contratos pueden integrar)
- Upgradeability con governance
- Multi-chain deployment ready

## Constraints

- EVM compatible (Ethereum mainnet + L2s)
- Sin dependencias de off-chain servers para funcionalidad core
- Liquidez provista por usuarios (no por el protocolo)
- Open source

## High-Level Design

```
   DEX ARCHITECTURE - HIGH LEVEL
   ===============================

   +------------------------------------------------------------------+
   |                        FRONTEND / SDK                             |
   |  +------------------+  +------------------+  +-----------------+ |
   |  | Swap Interface   |  | LP Interface     |  | Analytics       | |
   |  +--------+---------+  +--------+---------+  +--------+--------+ |
   +-----------|----------------------|----------------------|---------+
               |                      |                      |
   +-----------v----------------------v----------------------v---------+
   |                        ROUTER CONTRACT                            |
   |  - Multi-hop routing (A -> B -> C)                               |
   |  - Optimal path finding                                          |
   |  - Slippage protection                                           |
   |  - Deadline enforcement                                          |
   +---------------------------+---------------------------------------+
                               |
               +---------------+---------------+
               |                               |
   +-----------v-----------+   +---------------v-----------+
   |    FACTORY CONTRACT   |   |    QUOTER CONTRACT        |
   |  - Crea pools         |   |  - Simula swaps           |
   |  - Registry de pools  |   |  - Calcula precio         |
   |  - Fee tiers          |   |  - Estima gas             |
   +-----------+-----------+   +---------------------------+
               |
               |  Crea
               v
   +-----------+-----------+   +-----------+-----------+
   |    POOL A (ETH/USDC)  |   |    POOL B (ETH/DAI)   |
   |  +------------------+ |   |  +------------------+ |
   |  | Liquidity Engine | |   |  | Liquidity Engine | |
   |  | (CLAMM)          | |   |  | (CLAMM)          | |
   |  +------------------+ |   |  +------------------+ |
   |  | Oracle (TWAP)    | |   |  | Oracle (TWAP)    | |
   |  +------------------+ |   |  +------------------+ |
   |  | Fee Accounting   | |   |  | Fee Accounting   | |
   |  +------------------+ |   |  +------------------+ |
   +-----------------------+   +-----------------------+

   CLAMM = Concentrated Liquidity AMM
```

## Detailed Design

### 1. Modelo de Liquidez: Concentrated Liquidity AMM (CLAMM)

```
   CONCENTRATED LIQUIDITY vs UNIFORM
   ===================================

   Uniform (Uniswap v2):                Concentrated (Uniswap v3):

   Liquidez                              Liquidez
   |                                     |
   |########################             |       ######
   |########################             |      ########
   |########################             |     ##########
   |########################             |    ############
   +-----------------------> Precio      +-----------------------> Precio
   0        Pc        inf                Pa    Pc    Pb

   Capital distribuido                   Capital concentrado en
   en TODO el rango                      rango [Pa, Pb]
   (0, infinito)                         Eficiencia: hasta 4000x
                                         Riesgo: IL si precio sale del rango

   Pc = precio actual
   Pa = precio minimo del rango del LP
   Pb = precio maximo del rango del LP
```

**Matematica del CLAMM:**

```
   Formulas clave:

   Liquidez virtual:
   L = sqrt(x * y)     (similar a v2, pero en el rango)

   Dentro del rango [Pa, Pb]:
   L = delta_x * (sqrt(Pb) * sqrt(Pc)) / (sqrt(Pb) - sqrt(Pc))
   L = delta_y / (sqrt(Pc) - sqrt(Pa))

   Swap (vender dx tokens X):
   1. Calcular nueva sqrt price:
      sqrt(P_new) = sqrt(P_old) + dy/L   (si comprando token Y)
   2. Si P_new sale del rango del tick actual:
      - Cruzar al siguiente tick
      - Usar la liquidez de ese tick
      - Continuar el swap

   Ticks:
   - El rango de precios se divide en ticks discretos
   - Cada tick = incremento de 0.01% en precio (1.0001^i)
   - Tick spacing depende del fee tier:
     - 0.01% fee -> tick spacing 1
     - 0.05% fee -> tick spacing 10
     - 0.3% fee  -> tick spacing 60
     - 1% fee    -> tick spacing 200
```

### 2. Fee Tiers

```
   FEE TIER DESIGN
   =================

   +----------+---------------+----------------------------------+
   | Fee      | Tick Spacing  | Ideal para                       |
   +----------+---------------+----------------------------------+
   | 0.01%    | 1             | Stablecoin pairs (USDC/USDT)     |
   | 0.05%    | 10            | Correlated pairs (ETH/stETH)     |
   | 0.30%    | 60            | Standard pairs (ETH/USDC)        |
   | 1.00%    | 200           | Exotic/volatile pairs            |
   +----------+---------------+----------------------------------+

   Fee distribution:
   - LPs reciben: fee * (1 - protocol_fee_rate)
   - Protocolo recibe: fee * protocol_fee_rate
   - protocol_fee_rate: 0% inicialmente, activable via governance
     (maximo ~25% del fee del LP)
```

### 3. Oracle (TWAP)

```
   TWAP ORACLE
   =============

   Time-Weighted Average Price:
   Previene manipulacion por transacciones atomicas

   Almacenamiento en el pool contract:
   +----------------------------------------------------------+
   | observations[]: array circular de (timestamp, tickCumul)  |
   |                                                            |
   | Cada interaccion con el pool registra:                    |
   | - blockTimestamp                                          |
   | - tickCumulative += tick_actual * (t_now - t_last)        |
   +----------------------------------------------------------+

   Para calcular TWAP entre T1 y T2:
   TWAP_tick = (tickCumul[T2] - tickCumul[T1]) / (T2 - T1)
   TWAP_price = 1.0001 ^ TWAP_tick

   Seguridad:
   - Manipular requiere mover el precio Y mantenerlo por tiempo
   - Costo de manipulacion proporcional al periodo TWAP
   - TWAP de 30 minutos es razonablemente seguro
   - Protocolos que consumen: usar TWAP, NUNCA precio spot
```

### 4. MEV Protection

```
   ESTRATEGIAS MEV PARA EL DEX
   =============================

   Capa 1: Slippage Protection (en Router)
   - amountOutMinimum: minimo tokens a recibir
   - deadline: TX expira despues de N segundos
   - Si sandwich mueve precio > slippage, TX revierte

   Capa 2: Integration con Flashbots Protect
   - Frontend envia TXs via Flashbots RPC
   - TX no pasa por mempool publica
   - Reduce exposure a sandwiches

   Capa 3: Hooks para Batch Auctions (futuro)
   - Pool hooks que agregan ordenes en batches
   - Ejecucion a precio uniforme
   - Elimina ventaja de ordering

   Capa 4: MEV-Aware Routing
   - Router considera MEV al calcular rutas
   - Divide trades grandes en multiples pools
   - Reduce price impact (y por tanto MEV extraible)
```

### 5. Upgradeability

```
   UPGRADE STRATEGY
   ==================

   Componentes:

   Immutable (no upgradeable):
   +---------------------------+
   | Pool contracts            | <-- Core logic no cambia
   | Factory (existing pools)  |     Una vez deployado, es permanente
   +---------------------------+

   Upgradeable (via governance):
   +---------------------------+
   | Router                    | <-- Nuevas rutas, optimizaciones
   | Factory (new fee tiers)   | <-- Agregar nuevos fee tiers
   | Protocol fee switch       | <-- Activar/ajustar protocol fees
   +---------------------------+

   Governance process:
   1. Proposal (token holder con min tokens)
   2. Voting period (7 dias)
   3. Timelock (48 horas)
   4. Execution

   CRITICO: Los pools individuales son IMMUTABLES.
   La liquidez de los usuarios nunca esta sujeta a upgrades.
```

## Trade-offs

```
   +------------------------------+-------------------------------+
   | DECISION                     | TRADE-OFF                     |
   +------------------------------+-------------------------------+
   | Concentrated vs Uniform      | Capital efficiency vs         |
   | liquidity                    | IL risk y complexity          |
   +------------------------------+-------------------------------+
   | On-chain orderbook vs AMM    | Better pricing vs gas cost    |
   |                              | y complexity                  |
   +------------------------------+-------------------------------+
   | Multiple fee tiers vs single | Flexibility vs liquidity      |
   |                              | fragmentation                 |
   +------------------------------+-------------------------------+
   | Immutable pools vs           | Security (no rug) vs          |
   | upgradeable                  | ability to fix bugs           |
   +------------------------------+-------------------------------+
   | TWAP period (5 min vs 30 min)| Responsiveness vs             |
   |                              | manipulation resistance       |
   +------------------------------+-------------------------------+
```

## Open Questions

- Como manejar tokens con transfer taxes o rebasing tokens?
- Deberia el protocolo capturar MEV directamente (como Uniswap X)?
- Como integrar order book con AMM de forma hibrida?
- Que fee tiers agregar para nuevos tipos de assets (RWAs, LSTs)?
- Como escalar a cadenas con modelos de ejecucion diferentes (Solana, Move)?

---

---

# Case 2: Design a Lending Protocol

## Problem Statement

Disenar un protocolo de lending descentralizado que permita a usuarios prestar y pedir prestado multiples crypto-assets con tasas de interes variables y fijas, mecanismos de liquidacion robustos, y aislamiento de riesgo para assets volatiles.

## Requirements

**Funcionales:**
- Depositar assets y ganar interes (supply)
- Pedir prestado assets usando collateral (borrow)
- Variable y stable interest rates
- Liquidacion automatica de posiciones undercollateralized
- Flash loans (pedir prestado y devolver en una transaccion)
- Isolation mode para assets nuevos/riesgosos
- E-mode (efficiency mode) para assets correlacionados

**No funcionales:**
- Liquidaciones deben ejecutarse de forma confiable (sin bad debt)
- Oracle resilient: funcionar aun si un oracle falla
- Gas efficient: operaciones basicas < 200K gas
- Composable: otros protocolos pueden integrar
- Cross-chain deposits (roadmap futuro)

## Constraints

- EVM compatible
- Sin puntos centrales de fallo en operaciones core
- Governance para parametros de riesgo
- Auditado por minimo 3 firmas de seguridad antes de mainnet

## High-Level Design

```
   LENDING PROTOCOL ARCHITECTURE
   ===============================

   +------------------------------------------------------------------+
   |                      USER INTERFACE                               |
   |  +------------+  +------------+  +------------+  +-------------+ |
   |  | Supply     |  | Borrow     |  | Repay      |  | Liquidate   | |
   +--+-----+------+--+-----+------+--+-----+------+--+------+------+-+
            |              |              |               |
   +--------v--------------v--------------v---------------v-----------+
   |                        POOL CONTRACT                              |
   |  (Punto de entrada unico para todas las operaciones)             |
   |  - Supply / Withdraw                                             |
   |  - Borrow / Repay                                                |
   |  - Liquidate                                                     |
   |  - Flash Loan                                                    |
   +--------+-------------------+-------------------+-----------------+
            |                   |                   |
   +--------v--------+ +-------v--------+ +--------v--------+
   |  INTEREST RATE   | | ORACLE         | | RISK            |
   |  STRATEGY        | | MODULE         | | ENGINE          |
   |                  | |                | |                 |
   | - Variable rate  | | - Chainlink    | | - Collateral    |
   |   (utilization   | | - TWAP backup  | |   factors       |
   |   curve)         | | - Circuit      | | - Borrow caps   |
   | - Stable rate    | |   breakers     | | - Supply caps   |
   |   (fixed + var)  | | - Fallback     | | - Isolation mode|
   +---------+--------+ +-------+--------+ | - E-mode        |
             |                   |          +--------+--------+
             |                   |                   |
   +---------v-------------------v-------------------v----------------+
   |                     ASSET TOKENS                                  |
   |  +--------------+  +--------------+  +--------------+           |
   |  | aToken       |  | vToken       |  | sToken       |           |
   |  | (supply      |  | (variable    |  | (stable      |           |
   |  |  receipt)    |  |  debt)       |  |  debt)       |           |
   |  | ERC-20       |  | ERC-20       |  | ERC-20       |           |
   |  | rebasing     |  | non-transfer |  | non-transfer |           |
   |  +--------------+  +--------------+  +--------------+           |
   +------------------------------------------------------------------+
```

## Detailed Design

### 1. Interest Rate Model

```
   UTILIZATION-BASED INTEREST RATE
   =================================

   Utilization Rate (U):
   U = Total Borrows / Total Supplied

   Interest Rate Curve:

   Rate
   |                                        /
   |                                       /
   |                                      /  Slope 2 (steep)
   |                                     /   (penaliza alta
   |                                    /     utilizacion)
   |                             ------/
   |                       -----/
   |                  ----/
   |             ----/ Slope 1 (gradual)
   |        ----/
   |   ----/
   +--/---------------------------------------------> Utilization
   0%              Uoptimal (80%)                 100%

   Formula:
   Si U <= Uoptimal:
     Rate = base_rate + (U / Uoptimal) * slope1

   Si U > Uoptimal:
     Rate = base_rate + slope1 + ((U - Uoptimal) / (1 - Uoptimal)) * slope2

   Parametros tipicos (ETH):
   - base_rate: 0%
   - Uoptimal: 80%
   - slope1: 4% (tasa a 80% utilization)
   - slope2: 300% (penalidad por > 80%)

   Resultado:
   - A 50% utilization: ~2.5% APR
   - A 80% utilization: ~4% APR
   - A 95% utilization: ~60% APR (incentiva repago)
```

### 2. Collateral y Risk Parameters

```
   RISK PARAMETERS PER ASSET
   ===========================

   +-----------+--------+--------+--------+--------+---------+
   | Asset     | LTV    | Liq.   | Liq.   | Supply | Borrow  |
   |           | Max    | Thresh.| Bonus  | Cap    | Cap     |
   +-----------+--------+--------+--------+--------+---------+
   | ETH       | 80%    | 82.5%  | 5%     | No cap | No cap  |
   | WBTC      | 73%    | 78%    | 6.5%   | No cap | No cap  |
   | USDC      | 77%    | 80%    | 4.5%   | No cap | No cap  |
   | LINK      | 68%    | 73%    | 7%     | 50M    | 30M     |
   | UNI       | 65%    | 70%    | 10%    | 20M    | 10M     |
   | NEW_TOKEN | 0%*    | 0%*    | 10%    | 5M     | 2M      |
   +-----------+--------+--------+--------+--------+---------+

   * Isolation mode: solo puede usarse como collateral para
     un conjunto limitado de stablecoins

   LTV Max: Maximo que puedes pedir prestado vs collateral
   Liq. Threshold: Punto de liquidacion
   Liq. Bonus: Descuento que recibe el liquidador
   Caps: Limites de exposicion del protocolo

   Health Factor:
   HF = SUM(collateral_i * price_i * liq_threshold_i) / total_debt

   Si HF < 1.0 --> Posicion liquidable
```

### 3. Liquidation Mechanism

```
   LIQUIDATION FLOW
   ==================

   Condicion: Health Factor de la posicion < 1.0

   +-------+     1. Detecta HF < 1.0    +-------------+
   | Keeper| ---------------------------> | Pool        |
   | (bot) |     2. Llama liquidate()    | Contract    |
   |       |                              |             |
   |       |     3. Paga parte de la     |  Verifica:  |
   |       |        deuda del borrower   |  - HF < 1   |
   |       |                              |  - Monto ok |
   |       |     4. Recibe collateral    |  - Close    |
   |       | <--------------------------- |    factor   |
   +-------+     + liquidation bonus      +-------------+

   Parametros de liquidacion:
   - Close Factor: % maximo de deuda liquidable por TX (50%)
   - Liquidation Bonus: premium que recibe el liquidador (5-10%)

   Ejemplo numerico:
   Borrower tiene:
   - Collateral: 10 ETH ($20,000) con liq_threshold 82.5%
   - Deuda: 17,000 USDC
   - HF = (20,000 * 0.825) / 17,000 = 0.97 < 1.0

   Liquidador:
   - Paga hasta 50% de deuda: 8,500 USDC
   - Recibe: (8,500 / 2,000) * 1.05 = 4.4625 ETH (~$8,925)
   - Profit: $425

   PROTECCION CONTRA BAD DEBT:
   Si collateral < deuda (HF << 1):
   - El protocolo puede tener bad debt
   - Safety Module (staked tokens) cubre el deficit
   - Si Safety Module no alcanza: deficit socializado entre depositors
```

### 4. Oracle Strategy

```
   ORACLE RESILIENCE DESIGN
   ==========================

   +------------------------------------------------------------------+
   |                    ORACLE MODULE                                   |
   |                                                                    |
   |  Primary Source        Secondary Source       Circuit Breaker      |
   |  +-----------+         +-----------+          +-----------+       |
   |  | Chainlink |         | Uniswap   |          | Checks:   |       |
   |  | Price     |         | TWAP      |          | - Deviation|      |
   |  | Feed      |         | (30 min)  |          |   < 10%   |       |
   |  +-----------+         +-----------+          | - Staleness|      |
   |       |                     |                 |   < 1 hour|       |
   |       v                     v                 | - Sequencer|      |
   |  +-----------+         +-----------+          |   uptime  |       |
   |  | Heartbeat |         | Min       |          +-----------+       |
   |  | check     |         | liquidity |                              |
   |  | (< 1 hour)|         | check     |          Si circuit break:   |
   |  +-----------+         +-----------+          - Pausar borrows    |
   |       |                     |                 - Pausar liquidations|
   |       +----------+----------+                 - Alertar governance |
   |                  |                                                 |
   |           +------v------+                                         |
   |           | Final Price |                                         |
   |           | Selection   |                                         |
   |           +-------------+                                         |
   +------------------------------------------------------------------+

   Logica de seleccion:
   1. Usar Chainlink si esta fresco (< heartbeat) y no desviado
   2. Si Chainlink stale: usar TWAP como fallback
   3. Si ambos stale: circuit breaker, pausar operaciones
   4. Si desviacion > 10% entre fuentes: circuit breaker

   En L2s: Verificar que el sequencer esta activo
   (Si sequencer down, precios podrian estar desactualizados)
```

### 5. Flash Loans

```
   FLASH LOAN ARCHITECTURE
   ========================

   Todo dentro de UNA transaccion:

   +----------------------------------------------------------+
   |  Transaccion atomica                                      |
   |                                                            |
   |  1. Pool presta 1M USDC al usuario                       |
   |     (sin collateral)                                      |
   |                                                            |
   |  2. Usuario ejecuta logica arbitraria:                    |
   |     - Arbitrage entre DEXes                               |
   |     - Liquidacion en otro protocolo                       |
   |     - Refinanciamiento de posicion                        |
   |     - Self-liquidation                                    |
   |                                                            |
   |  3. Usuario devuelve 1M USDC + fee (0.05%)               |
   |                                                            |
   |  4. Pool verifica: amount_returned >= amount_borrowed + fee|
   |                                                            |
   |  Si paso 4 falla --> TODA la transaccion revierte          |
   |  (como si nunca hubiera pasado)                           |
   +----------------------------------------------------------+

   Implementacion:
   function flashLoan(
     address receiver,
     address[] assets,
     uint256[] amounts,
     bytes calldata params
   ) {
     // 1. Transfer assets to receiver
     // 2. Call receiver.executeOperation(assets, amounts, params)
     // 3. Verify balances >= pre_balance + fees
     // 4. If not: revert
   }

   Fee: 0.05% (va al protocolo y/o depositors)
```

### 6. Isolation Mode y E-Mode

```
   ISOLATION MODE
   ===============

   Para assets nuevos/riesgosos que no han probado su liquidez:

   Normal Mode:                    Isolation Mode:
   +------------------+            +------------------+
   | Collateral: ETH  |            | Collateral: XYZ  |
   | Borrow: cualquier|            | Borrow: SOLO     |
   | asset            |            | stablecoins      |
   | Debt ceiling: no |            | Debt ceiling: $5M|
   +------------------+            +------------------+

   Si XYZ colapsa en valor:
   - Maximo bad debt = $5M (debt ceiling)
   - Solo afecta stablecoins del pool
   - El resto del protocolo no se ve afectado

   E-MODE (Efficiency Mode):
   Para assets altamente correlacionados (ej: ETH/stETH, USDC/DAI)

   Normal:                         E-Mode:
   ETH collateral                  ETH collateral
   Borrow stETH                    Borrow stETH
   LTV: 80%                        LTV: 93%
   Liq threshold: 82.5%            Liq threshold: 95%

   Mayor eficiencia de capital porque el riesgo de divergencia
   entre ETH y stETH es bajo (estan correlacionados).
```

## Trade-offs

```
   +------------------------------+-------------------------------+
   | DECISION                     | TRADE-OFF                     |
   +------------------------------+-------------------------------+
   | Liquidation bonus alto vs    | Incentiva liquidadores pero   |
   | bajo                         | penaliza borrowers            |
   +------------------------------+-------------------------------+
   | Muchos assets vs pocos       | Mas opciones pero mas         |
   |                              | superficie de ataque          |
   +------------------------------+-------------------------------+
   | Oracle unico vs multi-oracle | Simple vs resiliente          |
   +------------------------------+-------------------------------+
   | Close factor 50% vs 100%    | Protege borrower vs           |
   |                              | protege protocolo de bad debt |
   +------------------------------+-------------------------------+
   | Variable rate vs stable rate | Flexible vs predecible        |
   |                              | (stable rate es mas complejo) |
   +------------------------------+-------------------------------+
```

## Open Questions

- Como manejar liquidaciones en escenarios de cascada (ETH cae 50% en minutos)?
- Deberia el protocolo implementar su propio keeper network o depender de terceros?
- Como integrar cross-chain deposits sin introducir riesgo de bridge?
- Interest rate model: deberia ajustarse automaticamente basado en condiciones de mercado (AI-driven)?

---

---

# Case 3: Design a Stablecoin

## Problem Statement

Disenar un stablecoin con soft peg al USD que sea descentralizado, capital-eficiente, resistente a bank runs, y escalable. El sistema debe funcionar sin depender de reservas en bancos tradicionales.

## Requirements

**Funcionales:**
- Mantener peg 1:1 con USD (tolerancia +/- 0.5%)
- Minting: usuarios depositan collateral, reciben stablecoin
- Redemption: usuarios devuelven stablecoin, recuperan collateral
- Liquidacion automatica de posiciones bajo-colateralizadas
- Peg Stability Module (PSM): intercambio directo stablecoin <-> USDC
- Emergency shutdown: mecanismo de cierre ordenado
- Savings rate: tasa de interes para holders

**No funcionales:**
- Collateral ratio minimo: 150% (crypto) / 110% (stablecoins)
- Peg recovery en < 24 horas ante depegs moderados
- Escalabilidad: soportar $1B+ de supply
- Composabilidad: integrable en todo el ecosistema DeFi

## Constraints

- Sin reservas en bancos (a diferencia de USDC/USDT)
- Gobernado por DAO
- Debe funcionar en escenarios de stress extremo (ETH -80%)
- Regulacion: debe poder adaptarse a requerimientos futuros

## High-Level Design

```
   STABLECOIN SYSTEM ARCHITECTURE
   ================================

   +------------------------------------------------------------------+
   |                                                                    |
   |   USUARIOS                                                        |
   |   +--------+   +--------+   +--------+   +--------+             |
   |   | Minter |   | Holder |   | Saver  |   | Keeper |             |
   |   +---+----+   +---+----+   +---+----+   +---+----+             |
   +-------|-------------|-------------|-------------|------------------+
           |             |             |             |
   +-------v-------------v-------------v-------------v----------------+
   |                   CORE CONTRACTS                                  |
   |                                                                    |
   |  +------------------+  +------------------+  +-----------------+ |
   |  | VAULT ENGINE     |  | LIQUIDATION      |  | PSM             | |
   |  | (CDP Manager)    |  | ENGINE           |  | (Peg Stability  | |
   |  |                  |  |                  |  |  Module)         | |
   |  | - Open vault     |  | - Dutch auction  |  | - Swap STABLE   | |
   |  | - Deposit coll.  |  | - Bad debt mgmt  |  |   <-> USDC 1:1 | |
   |  | - Generate stable|  | - Surplus buffer |  | - Fee: 0.1%    | |
   |  | - Repay debt     |  |                  |  |                 | |
   |  +--------+---------+  +--------+---------+  +--------+--------+ |
   |           |                      |                     |          |
   |  +--------v---------+  +--------v---------+  +--------v--------+ |
   |  | PRICE ORACLE     |  | BUFFER MODULE    |  | SAVINGS RATE   | |
   |  | MODULE           |  |                  |  | MODULE (DSR)   | |
   |  |                  |  | - Surplus buffer |  |                 | |
   |  | - Multi-oracle   |  |   (profits)     |  | - Deposit STABLE| |
   |  | - Median price   |  | - Debt buffer   |  | - Earn interest | |
   |  | - OSM (1hr delay)|  |   (safety net)  |  | - Rate set by  | |
   |  +------------------+  +------------------+  |   governance   | |
   |                                                +-----------------+ |
   |  +------------------------------------------------------------+  |
   |  | GOVERNANCE (DAO)                                           |  |
   |  | - Risk parameters (LTV, liquidation ratio, debt ceilings) |  |
   |  | - Collateral onboarding                                    |  |
   |  | - Interest rates                                           |  |
   |  | - Emergency shutdown                                       |  |
   |  +------------------------------------------------------------+  |
   +------------------------------------------------------------------+
```

## Detailed Design

### 1. Vault (CDP) System

```
   VAULT LIFECYCLE
   =================

   1. OPEN: Usuario crea vault y deposita collateral

      +------------------+
      | Vault #1234      |
      | Owner: Alice     |
      | Collateral: 10 ETH ($20,000)
      | Debt: 0 STABLE   |
      | Coll. Ratio: inf |
      +------------------+

   2. GENERATE: Usuario genera (mint) stablecoins contra collateral

      +------------------+
      | Vault #1234      |
      | Owner: Alice     |
      | Collateral: 10 ETH ($20,000)
      | Debt: 10,000 STABLE + stability fee
      | Coll. Ratio: 200% |
      +------------------+

   3. REPAY: Usuario devuelve stablecoins para liberar collateral

      +------------------+
      | Vault #1234      |
      | Owner: Alice     |
      | Collateral: 10 ETH ($20,000)
      | Debt: 5,000 STABLE (parcial repay)
      | Coll. Ratio: 400% |
      +------------------+

   4. LIQUIDATE: Si ratio cae bajo minimo

      ETH baja a $1,200:
      +------------------+
      | Vault #1234      |
      | Collateral: 10 ETH ($12,000)
      | Debt: 10,000 STABLE
      | Coll. Ratio: 120% < 150% !!
      | STATUS: LIQUIDABLE |
      +------------------+
```

### 2. Multi-Collateral Design

```
   COLLATERAL TYPES
   ==================

   +-------------+--------+----------+--------+------------------+
   | Collateral  | Min CR | Stab.Fee | Debt   | Risk Profile     |
   |             |        | (APR)    | Ceiling|                  |
   +-------------+--------+----------+--------+------------------+
   | ETH         | 150%   | 2%       | $500M  | Core, liquid     |
   | WBTC        | 150%   | 2.5%    | $300M  | Core, wrap risk  |
   | stETH       | 150%   | 1.5%    | $400M  | Yield-bearing    |
   | USDC (PSM)  | 100%   | 0%       | $200M  | Stability anchor |
   | wstETH      | 160%   | 2%       | $200M  | Wrapped LST      |
   | RWA (bonds) | 110%   | 3%       | $100M  | Off-chain risk   |
   +-------------+--------+----------+--------+------------------+

   Debt Ceiling: maximo STABLE que puede generarse por tipo de collateral
   Esto limita la exposicion del sistema a cada tipo de riesgo.

   Stability Fee: interes que el borrower paga por generar STABLE
   - Va al surplus buffer del protocolo
   - Se usa como herramienta de politica monetaria
```

### 3. Liquidation Design: Dutch Auction

```
   DUTCH AUCTION LIQUIDATION
   ===========================

   A diferencia de liquidacion instantanea (Aave style),
   se usa una subasta descendente:

   Precio ofrecido
   por el collateral
   |
   | * (inicio: precio alto, incentiva urgencia)
   |  \
   |   \
   |    \
   |     \
   |      \  <-- Alguien compra aqui (cuando el precio
   |       \     les resulta rentable)
   |        \
   |         \
   |          * (precio minimo / fin de subasta)
   +-------------------------------------------------> Tiempo
   T0                                                  T0 + 1 hora

   Ventajas sobre liquidacion instantanea:
   1. Price discovery: el mercado decide el precio justo
   2. Menos MEV: no hay race condition (primer comprador)
   3. Mas competencia: cualquiera puede participar
   4. Menos perdida para el borrower: no hay bonus fijo

   Flujo:
   1. Keeper inicia liquidacion (kick)
   2. Subasta comienza a precio alto
   3. Precio decrece linealmente con el tiempo
   4. Participante compra cuando precio le conviene (take)
   5. Collateral transferido, deuda cubierta
   6. Si sobra collateral: devuelto al owner del vault
```

### 4. Peg Stability Module (PSM)

```
   PEG STABILITY MODULE
   ======================

   Problema: El peg puede desviarse por supply/demand

   STABLE > $1.00 (premium):
   +------------------------------------------------------+
   | Arbitrageur:                                          |
   | 1. Deposita 1 USDC en PSM                           |
   | 2. Recibe 1 STABLE (- 0.1% fee)                     |
   | 3. Vende STABLE en mercado a $1.01                   |
   | 4. Profit: $0.009                                    |
   | Efecto: Aumenta supply de STABLE --> precio baja     |
   +------------------------------------------------------+

   STABLE < $1.00 (descuento):
   +------------------------------------------------------+
   | Arbitrageur:                                          |
   | 1. Compra STABLE en mercado a $0.99                  |
   | 2. Redime en PSM por 1 USDC (- 0.1% fee)            |
   | 3. Profit: $0.009                                    |
   | Efecto: Reduce supply de STABLE --> precio sube      |
   +------------------------------------------------------+

   El PSM actua como ANCLA de estabilidad.
   Trade-off: Introduce dependencia de USDC (centralizado)
   pero proporciona estabilidad confiable.

   Debt ceiling del PSM controla cuanta exposicion a USDC
   esta dispuesto a tener el sistema.
```

### 5. Savings Rate (DSR)

```
   SAVINGS RATE MODULE
   =====================

   Cualquier holder de STABLE puede depositarlo y ganar interes.

   Mecanismo:
   1. Governance fija el savings rate (ej: 5% APR)
   2. Usuarios depositan STABLE en el modulo
   3. El sistema acumula interes con el tiempo
   4. Usuarios retiran STABLE + interes generado

   Fuente de los rendimientos:
   +------------------------------------------+
   | Ingresos del sistema:                    |
   | - Stability fees de los vaults           |
   | - Liquidation proceeds                   |
   | - PSM fees                               |
   +------------------------------------------+
              |
              v
   +------------------------------------------+
   | Distribicion:                            |
   | - Savings rate (a depositors)            |
   | - Surplus buffer (reserva del sistema)   |
   | - Governance token buyback (si surplus)  |
   +------------------------------------------+

   El savings rate es una herramienta de POLITICA MONETARIA:
   - Rate alto: incentiva hold STABLE (reduce supply circulante)
   - Rate bajo: desincentiva hold (aumenta supply circulante)
   - Usado para controlar el peg indirectamente
```

### 6. Emergency Shutdown

```
   EMERGENCY SHUTDOWN
   ====================

   Ultimo recurso ante un evento catastrofico
   (exploit, oracle failure, black swan market event)

   Triggers (governance vote o threshold automatico):
   - Total system debt > total collateral value
   - Critical oracle failure
   - Governance vote (emergency)

   Proceso:
   +----------------------------------------------------------+
   | Fase 1: FREEZE                                            |
   | - No se pueden crear nuevos vaults                        |
   | - No se puede generar nuevo STABLE                        |
   | - Precios se congelan (ultimo precio valido)              |
   +----------------------------------------------------------+
              |
              v
   +----------------------------------------------------------+
   | Fase 2: COOLDOWN (6-48 horas)                             |
   | - Vault owners pueden repagar deuda y recuperar collateral|
   | - Liquidaciones se pausan                                 |
   | - Tiempo para que el mercado se estabilice                |
   +----------------------------------------------------------+
              |
              v
   +----------------------------------------------------------+
   | Fase 3: REDEMPTION                                        |
   | - Holders de STABLE pueden reclamar su parte              |
   |   proporcional del collateral                             |
   | - 1 STABLE = $1 de collateral (al precio congelado)      |
   | - Distribucion pro-rata si hay deficit                    |
   +----------------------------------------------------------+

   El emergency shutdown asegura que incluso en el peor caso,
   los holders de STABLE reciben tanto valor como sea posible.
```

## Trade-offs

```
   +------------------------------+-------------------------------+
   | DECISION                     | TRADE-OFF                     |
   +------------------------------+-------------------------------+
   | Overcollateralization alta   | Mas seguro pero menos         |
   | (200%) vs baja (130%)       | eficiente en capital           |
   +------------------------------+-------------------------------+
   | PSM con USDC vs sin PSM     | Estabilidad de peg vs         |
   |                              | dependencia centralizada      |
   +------------------------------+-------------------------------+
   | Dutch auction vs liquidacion | Mejor precio para borrowers   |
   | instantanea                  | vs velocidad de liquidacion   |
   +------------------------------+-------------------------------+
   | Debt ceilings conservadores  | Menor riesgo vs menor         |
   | vs agresivos                 | crecimiento del supply        |
   +------------------------------+-------------------------------+
   | Savings rate alto vs bajo   | Atrae depositors vs           |
   |                              | sostenibilidad financiera     |
   +------------------------------+-------------------------------+
```

## Open Questions

- Como manejar collateral que genera yield (stETH, RWAs)? El yield va al vault owner o al sistema?
- Deberia el stablecoin soportar negative interest rates (para reducir supply)?
- Como integrar Real World Assets sin introducir riesgo legal excesivo?
- Cross-chain stablecoin: burn-and-mint nativo o bridges?
- Regulatory compliance: como hacer que el stablecoin cumpla MiCA sin sacrificar descentralizacion?

---

---

# Case 4: Design a Decentralized Identity System

## Problem Statement

Disenar un sistema de identidad descentralizado que permita a usuarios controlar su propia identidad, compartir credenciales de forma selectiva, cumplir con regulaciones (KYC/AML), y recuperar acceso ante perdida de claves. El sistema debe integrarse con protocolos DeFi para habilitar transfer restrictions y compliance.

## Requirements

**Funcionales:**
- Self-sovereign: usuario controla su identidad completamente
- Privacy-preserving: selective disclosure via ZK proofs
- Credential issuance: KYC providers pueden emitir VCs
- Credential verification: smart contracts verifican proofs on-chain
- Revocation: issuers pueden revocar credenciales comprometidas
- Recovery: usuarios pueden recuperar identidad ante perdida de wallet
- Integration: hooks para protocolos DeFi (transfer restrictions)

**No funcionales:**
- Verificacion on-chain: < 500K gas
- Latencia de revocacion: < 1 hora
- Compatible con DIDs existentes (W3C standard)
- Multi-chain: funcionar en Ethereum, L2s, y potencialmente non-EVM
- GDPR compatible (no datos personales on-chain)

## Constraints

- No almacenar datos personales on-chain (privacidad + GDPR)
- Soportar multiples KYC providers (no vendor lock-in)
- El protocolo DeFi no debe tener acceso a datos personales
- Reguladores pueden acceder a datos bajo autorizacion legal

## High-Level Design

```
   DECENTRALIZED IDENTITY SYSTEM
   ===============================

   OFF-CHAIN                                   ON-CHAIN
   +---------------------------+               +---------------------------+
   |                           |               |                           |
   |  +-------------------+   |               |  +---------------------+  |
   |  | KYC Provider A    |   |               |  | Identity Registry   |  |
   |  | (Issuer)          |   |               |  | Contract            |  |
   |  +--------+----------+   |               |  | - DID -> State Root |  |
   |           |              |               |  | - Issuer whitelist  |  |
   |  +--------v----------+   |               |  +----------+----------+  |
   |  | Verifiable        |   |               |             |             |
   |  | Credential        |   |               |  +----------v----------+  |
   |  | (signed, stored   |   |               |  | ZK Verifier         |  |
   |  |  in user wallet)  |   |               |  | Contract            |  |
   |  +--------+----------+   |               |  | - Verify proofs     |  |
   |           |              |               |  | - Check nullifiers  |  |
   |  +--------v----------+   |    ZK Proof   |  | - Check issuer      |  |
   |  | User Wallet       |   | +-----------> |  +----------+----------+  |
   |  | (Identity Agent)  |   |               |             |             |
   |  | - Stores VCs      |   |               |  +----------v----------+  |
   |  | - Generates proofs|   |               |  | DeFi Protocol       |  |
   |  | - Manages DIDs    |   |               |  | Integration         |  |
   |  +-------------------+   |               |  | - Transfer hooks    |  |
   |                           |               |  | - Access control    |  |
   |  +-------------------+   |               |  +---------------------+  |
   |  | Recovery Module   |   |               |                           |
   |  | (Social Recovery) |   |               |  +---------------------+  |
   |  +-------------------+   |               |  | Revocation Registry |  |
   |                           |               |  | (on-chain)          |  |
   |  +-------------------+   |               |  +---------------------+  |
   |  | Encrypted Data    |   |               |                           |
   |  | Escrow (para      |   |               |                           |
   |  | reguladores)      |   |               |                           |
   |  +-------------------+   |               |                           |
   +---------------------------+               +---------------------------+
```

## Detailed Design

### 1. DID Method y Resolution

```
   DID METHOD: did:ethr + did:pkh
   ================================

   Eleccion: Combinar did:ethr (Ethereum) para identidades principales
   con did:pkh (blockchain-agnostic) para multi-chain.

   Registro on-chain (ERC-1056 based):
   +----------------------------------------------------------+
   | Identity Registry Contract                                |
   |                                                            |
   | mapping(address => IdentityState) public identities;      |
   |                                                            |
   | struct IdentityState {                                    |
   |   bytes32 stateRoot;       // Merkle root de claims      |
   |   uint256 nonce;           // Para replay protection      |
   |   uint256 lastUpdate;      // Timestamp                   |
   |   address[] delegates;     // Authorized keys             |
   | }                                                          |
   |                                                            |
   | function updateState(                                     |
   |   bytes32 newRoot,                                        |
   |   bytes proof                                             |
   | ) external;                                                |
   |                                                            |
   | function addDelegate(                                     |
   |   address delegate,                                       |
   |   uint256 expiration                                      |
   | ) external;                                                |
   +----------------------------------------------------------+

   Resolution flow:
   1. Input: did:ethr:0x1234...
   2. Query Identity Registry para stateRoot
   3. Construir DID Document con:
      - Authentication: owner address + delegates
      - Service endpoints: desde off-chain resolver
      - Estado: stateRoot para verificacion de claims
```

### 2. Credential Issuance Flow

```
   KYC CREDENTIAL ISSUANCE
   =========================

   +--------+          +----------+          +----------+
   | User   |          | KYC      |          | On-Chain |
   |        |          | Provider |          | Registry |
   +---+----+          +----+-----+          +----+-----+
       |                    |                      |
       | 1. Submit docs     |                      |
       | (passport, selfie) |                      |
       +------------------->|                      |
       |                    |                      |
       |                    | 2. Verify identity   |
       |                    | (off-chain process)  |
       |                    |                      |
       | 3. Issue VC        |                      |
       | (signed credential)|                      |
       |<-------------------+                      |
       |                    |                      |
       | 4. Store VC in     |                      |
       | identity wallet    | 5. Update issuer     |
       |                    | state root           |
       |                    +--------------------->|
       |                    |                      |
       | 6. Update user     |                      |
       | identity state     |                      |
       +------------------------------------------>|
       |                    |                      |

   VC Structure:
   {
     "type": "KYCCredential",
     "issuer": "did:ethr:0xISSUER",
     "subject": "did:ethr:0xUSER",
     "claims": {
       "kycLevel": 2,
       "jurisdiction": "EU",
       "riskScore": "low",
       "expirationDate": "2025-12-31"
     },
     "proof": {
       "type": "BJJSignature2021",
       "signature": "..."
     }
   }

   La VC se almacena SOLO en el wallet del usuario (off-chain).
   On-chain solo se publica el state root (hash).
```

### 3. ZK Verification Flow

```
   ZK PROOF GENERATION AND VERIFICATION
   ======================================

   Cuando el usuario quiere interactuar con un DeFi protocol:

   +--------+                              +----------+
   | User   |                              | DeFi     |
   | Wallet |                              | Protocol |
   +---+----+                              +----+-----+
       |                                        |
       | 1. Protocol requires:                  |
       |    "KYC level >= 2 AND                |
       |     jurisdiction IN [EU, US] AND      |
       |     not expired"                       |
       |<---------------------------------------+
       |                                        |
       | 2. Generate ZK proof locally:          |
       |    Private inputs:                     |
       |    - Full VC data                      |
       |    - Issuer signature                  |
       |    - Merkle proof of claim in state    |
       |                                        |
       |    Public inputs:                      |
       |    - Issuer ID (trusted list)          |
       |    - Current timestamp                 |
       |    - Nullifier                         |
       |    - Query: "level>=2 AND juris IN...' |
       |                                        |
       | 3. Submit ZK proof on-chain            |
       +--------------------------------------->|
       |                                        |
       |    4. ZK Verifier Contract checks:     |
       |    - Proof is valid                    |
       |    - Issuer is in trusted list         |
       |    - Nullifier not used                |
       |    - Not expired                       |
       |                                        |
       |    5. If valid: allow operation         |
       |<---------------------------------------+

   Gas cost: ~200-400K gas para verificacion de un Groth16 proof
   Optimizacion: Usar session proofs (verificar una vez, cache N horas)
```

### 4. Revocation System

```
   REVOCATION DESIGN
   ===================

   Tres modelos evaluados:

   Modelo A: Revocation List (simple)
   +------------------------------------------+
   | mapping(bytes32 => bool) public revoked; |
   | Hash del credential -> revocado o no      |
   | Pro: Simple, O(1) check                  |
   | Con: Revela CUALES credentials existen   |
   +------------------------------------------+

   Modelo B: Accumulator (privacy-preserving)   <-- ELEGIDO
   +------------------------------------------+
   | RSA Accumulator o Sparse Merkle Tree     |
   |                                           |
   | - Issuer mantiene un accumulator de       |
   |   credentials VALIDAS                     |
   | - Para probar no-revocacion:              |
   |   ZK proof de membership en accumulator  |
   | - Para revocar: actualizar accumulator   |
   |   (excluir credential)                   |
   |                                           |
   | Pro: No revela cuales credentials existen|
   | Con: Mas complejo, updates costosos      |
   +------------------------------------------+

   Modelo C: Status List 2021 (W3C standard)
   +------------------------------------------+
   | Bitstring comprimido on-chain            |
   | Cada bit = status de un credential       |
   | Pro: Estandar W3C, eficiente             |
   | Con: Posicion en bitstring = correlatable|
   +------------------------------------------+

   Flow de revocacion:
   1. Issuer decide revocar (ej: fraude detectado)
   2. Issuer actualiza accumulator on-chain
   3. Proximo ZK proof del usuario debe incluir
      non-revocation proof contra el nuevo accumulator
   4. Si credential revocada: proof falla
   5. Latencia: depende de cuando el usuario genera nuevo proof
      (maximo: duracion del session proof cache)
```

### 5. Recovery Mechanism

```
   SOCIAL RECOVERY FOR DIDs
   ==========================

   Problema: Si el usuario pierde acceso a su wallet,
   pierde su DID y todas sus credentials.

   Solucion: Social recovery con guardians

   +----------------------------------------------------------+
   | Identity Contract del Usuario                             |
   |                                                            |
   | Guardians: [Guardian1, Guardian2, Guardian3, Guardian4]    |
   | Threshold: 3 de 4                                         |
   |                                                            |
   | function initiateRecovery(                                |
   |   address newOwner,                                       |
   |   bytes[] guardianSignatures  // 3 de 4 firmas           |
   | ) external {                                               |
   |   require(signatures.length >= threshold);                |
   |   // Verificar firmas                                     |
   |   // Timelock de 48 horas (el owner puede cancelar)       |
   |   pendingRecovery = Recovery(newOwner, block.timestamp);  |
   | }                                                          |
   |                                                            |
   | function executeRecovery() external {                     |
   |   require(block.timestamp >= pendingRecovery.timestamp + 48h);
   |   owner = pendingRecovery.newOwner;                       |
   |   // Migrar delegates al nuevo owner                      |
   | }                                                          |
   +----------------------------------------------------------+

   Guardians pueden ser:
   - Contactos de confianza (amigos, familia)
   - Institutional guardians (servicios de recovery)
   - Hardware wallets secundarias
   - Multi-factor (email verification + guardian)

   Post-recovery:
   - Las VCs existentes siguen validas (estan firmadas por el issuer,
     no por la wallet del usuario)
   - El DID Document se actualiza con la nueva key
   - Nullifiers previos se invalidan (nuevo identity state)
```

### 6. DeFi Protocol Integration

```
   INTEGRATION HOOKS
   ===================

   El protocolo DeFi integra verificacion de identidad
   en sus operaciones criticas:

   +----------------------------------------------------------+
   | DeFi Protocol (ej: Lending)                               |
   |                                                            |
   | modifier onlyVerified(bytes calldata proof) {             |
   |   require(                                                |
   |     identityVerifier.verify(proof, msg.sender),           |
   |     "Identity not verified"                               |
   |   );                                                      |
   |   _;                                                      |
   | }                                                          |
   |                                                            |
   | function deposit(                                         |
   |   address asset,                                          |
   |   uint256 amount,                                         |
   |   bytes calldata identityProof                            |
   | ) external onlyVerified(identityProof) {                  |
   |   // Logica normal de deposit                             |
   | }                                                          |
   |                                                            |
   | // Transfer hook para ERC-20 con restricciones            |
   | function _beforeTokenTransfer(                            |
   |   address from,                                           |
   |   address to,                                             |
   |   uint256 amount                                          |
   | ) internal {                                               |
   |   if (transferRestricted) {                               |
   |     require(                                              |
   |       identityVerifier.isSessionValid(to),                |
   |       "Recipient not verified"                            |
   |     );                                                    |
   |   }                                                       |
   | }                                                          |
   +----------------------------------------------------------+

   Session Management:
   +----------------------------------------------------------+
   | Session proof: verificar ZK proof una vez,                |
   | almacenar resultado temporalmente                         |
   |                                                            |
   | mapping(address => Session) public sessions;              |
   |                                                            |
   | struct Session {                                          |
   |   uint256 validUntil;                                     |
   |   bytes32 nullifier;     // Previene reuso               |
   |   uint8 kycLevel;        // Nivel de verificacion         |
   |   bytes2 jurisdiction;   // EU, US, etc.                  |
   | }                                                          |
   |                                                            |
   | Session dura 24 horas -> usuario genera proof una vez/dia |
   +----------------------------------------------------------+
```

### 7. Encrypted Data Escrow (para reguladores)

```
   REGULATORY ESCROW
   ===================

   Para cumplir con regulaciones que requieren que datos de identidad
   sean accesibles bajo orden judicial:

   +----------------------------------------------------------+
   | Flujo de escrow:                                          |
   |                                                            |
   | 1. Al completar KYC, se encripta un paquete con:         |
   |    - Datos personales (nombre, pais, documento)           |
   |    - Con clave publica del REGULADOR                      |
   |    - Almacenado en IPFS (hash on-chain)                   |
   |                                                            |
   | 2. Solo el regulador puede descifrar:                     |
   |    - Con su clave privada                                 |
   |    - Requiere proceso legal (warrant)                     |
   |    - Audit log de accesos                                 |
   |                                                            |
   | Estructura on-chain:                                       |
   | mapping(bytes32 => EscrowData) public escrows;            |
   |                                                            |
   | struct EscrowData {                                       |
   |   bytes32 ipfsHash;        // Datos encriptados           |
   |   address regulator;       // Quien puede descifrar       |
   |   bytes32 userNullifier;   // Link (solo util para reg.)  |
   | }                                                          |
   +----------------------------------------------------------+

   Privacidad:
   - El publico solo ve un hash (no datos)
   - El protocolo DeFi no ve datos personales
   - Solo el regulador puede descifrar (y solo con la clave)
   - El usuario sabe que existe un escrow (consentimiento)
```

## Trade-offs

```
   +------------------------------+-------------------------------+
   | DECISION                     | TRADE-OFF                     |
   +------------------------------+-------------------------------+
   | ZK proofs vs attestations    | Privacidad maxima vs          |
   | directas                     | simplicidad y gas cost        |
   +------------------------------+-------------------------------+
   | Single issuer vs multiple    | Simplicidad vs                |
   |                              | descentralizacion             |
   +------------------------------+-------------------------------+
   | Session proofs vs per-tx     | UX (menos ZK generation)      |
   | proofs                       | vs seguridad (granularidad)   |
   +------------------------------+-------------------------------+
   | Accumulator vs revocation    | Privacidad vs costo de        |
   | list                         | updates                       |
   +------------------------------+-------------------------------+
   | Social recovery vs seed      | Usabilidad vs autonomia       |
   | phrase only                  | completa                      |
   +------------------------------+-------------------------------+
   | Encrypted escrow vs no       | Regulatory compliance vs      |
   | escrow                       | privacidad absoluta           |
   +------------------------------+-------------------------------+
```

## Open Questions

- Como manejar identidad cross-chain? El estado del DID vive en una cadena pero necesita ser verificable en otras.
- Como prevenir que los reguladores abusen del acceso al escrow? Multi-party computation?
- Como manejar la expiracion de credentials cuando el issuer desaparece?
- Como incentivar a los usuarios a completar KYC si el sistema es permissionless?
- Como manejar identity para DAOs y smart contracts (no solo personas)?
- Cuantas pruebas ZK puede generar un movil razonablemente? Implicaciones para UX.

---

---

## Recursos generales para system design

### Libros y papers
- "DeFi and the Future of Finance" - Campbell Harvey et al.
- "How to DeFi" - CoinGecko
- "Flash Boys 2.0" - Daian et al.
- "SoK: Decentralized Finance (DeFi)" - IEEE S&P

### Documentacion de referencia
- Uniswap v3 Whitepaper y Development Book
- Aave v3 Technical Paper
- MakerDAO Technical Docs (docs.makerdao.com)
- Compound v3 (Comet) Documentation
- Polygon ID Technical Documentation

### Herramientas de diseno
- Excalidraw: para diagramas de arquitectura
- Miro: para collaborative design sessions
- HackMD: para documentos de diseno colaborativos

### Talks
- "Designing DeFi Protocols" - Paradigm research talks
- "System Design for Web3" - a]{ blockchain conferences
- Devcon/ETHDenver architecture track presentations

---

## Checkpoint

Antes de considerar este modulo completado, verifica que puedes:

- [ ] Disenar un DEX desde cero: modelo de liquidez, fee design, oracle, MEV protection, upgradeability
- [ ] Disenar un lending protocol: interest rate model, liquidation mechanism, oracle strategy, risk management
- [ ] Disenar un stablecoin: vault system, multi-collateral, liquidation auction, PSM, emergency shutdown
- [ ] Disenar un identity system: DID, VC, ZK verification, revocation, recovery, DeFi integration
- [ ] Para cada caso: justificar decisiones de diseno con trade-offs explicitos
- [ ] Para cada caso: identificar al menos 3 open questions que requeriran investigacion adicional
- [ ] Producir documentos de diseno de ~300 lineas que cubran todos los aspectos del sistema
- [ ] Defender tus decisiones de diseno en una discusion tecnica (como en una entrevista)
- [ ] Comparar tu diseno con los protocolos existentes (Uniswap, Aave, MakerDAO, Polygon ID)
- [ ] Identificar vulnerabilidades y puntos de fallo en tu propio diseno
