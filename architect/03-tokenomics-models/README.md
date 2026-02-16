# Tokenomics Models

Diseño económico de protocolos: supply mechanics, utility, ve-tokens, liquidity mining y distribución de fees.

---

## 1. Objetivo

Al completar este módulo serás capaz de:

- Analizar y diseñar mecánicas de supply (emisión, burning, halving)
- Clasificar tipos de utilidad de un token y evaluar su sostenibilidad
- Explicar el modelo ve-token y su flywheel de incentivos
- Identificar problemas de liquidity mining y diseñar alternativas
- Evaluar modelos de distribución de fees y su impacto en demand/supply del token
- Diseñar tokenomics completas para un protocolo ficticio

---

## 2. Prerequisitos

- Módulos 01 y 02 completados
- Conceptos básicos de economía: oferta/demanda, incentivos, game theory
- Familiaridad con governance tokens (haber votado o delegado en algún protocolo)
- Entender qué es un AMM y cómo funciona un DEX

---

## 3. Conceptos clave

### 3.1 Supply Mechanics

La supply de un token determina la presión inflacionaria o deflacionaria sobre su precio.

#### Fixed Supply

```
  Supply
    |
    |========================================  Max Supply (e.g., 21M BTC)
    |       .............................
    |     ..
    |   ..
    |  .
    | .   Emissiones decrecientes (halving)
    |.
    +----------------------------------------> Tiempo
```

- Ejemplo: Bitcoin (21M max), muchos governance tokens con supply cap
- Ventaja: escasez programada, predecible
- Desventaja: si se necesitan incentivos continuos, no hay tokens para emitir

#### Inflationary

```
  Supply
    |                                    .....
    |                               ....
    |                          ....
    |                     ....
    |                ....
    |           ....
    |      ....       Emisión continua (puede decrecer rate)
    | ....
    +----------------------------------------> Tiempo
```

- Ejemplo: Ethereum post-Merge (~0.5% anual de issuance a validators)
- Ventaja: incentivos perpetuos para participantes
- Desventaja: dilución constante, necesita mecanismos de absorción

#### Deflationary (Burning)

**EIP-1559 Base Fee Burn:**
- Cada transacción en Ethereum quema la base fee
- Si burn > issuance, la supply neta disminuye (ultrasound money)
- Dinámico: en periodos de alta actividad, más burn

**Buyback-and-Burn:**
- El protocolo usa revenue para comprar tokens en el mercado y quemarlos
- Ejemplo: MakerDAO (surplus -> compra MKR -> burn)
- Crea presión de compra sostenida por revenue real

#### Emission Schedules

| Schedule            | Fórmula                         | Ejemplo           |
|---------------------|---------------------------------|-------------------|
| Linear              | `emission = constant per block` | Muchos farm tokens|
| Exponential decay   | `emission = base * (1-r)^t`     | Synthetix         |
| Halving             | `emission / 2 cada N bloques`   | Bitcoin           |
| Epoch-based         | Governance decide cada epoch    | Curve gauges      |

---

### 3.2 Token Utility Types

Un token puede tener una o más funciones:

| Tipo          | Descripción                                           | Ejemplo              |
|---------------|-------------------------------------------------------|----------------------|
| Governance    | Votar sobre parámetros del protocolo                  | UNI, AAVE            |
| Fee-sharing   | Recibir parte de los fees del protocolo               | xSUSHI, veCRV        |
| Access        | Necesario para usar ciertas funciones                 | BNB (descuento fees) |
| Staking       | Lock para asegurar la red y ganar rewards             | ETH (PoS)            |
| Collateral    | Usado como colateral en el mismo protocolo            | MKR (backstop)       |
| Work token    | Necesario para operar como proveedor de servicios     | LINK, GRT            |

**Evaluación de sostenibilidad:**
- Un token solo con governance y sin fee-sharing tiene poca demanda real
- Un token con fee-sharing pero sin revenue real es insostenible
- Los mejores tokens tienen múltiples utilidades que se refuerzan

---

### 3.3 ve-Tokens (Vote-Escrowed)

El modelo ve-token fue popularizado por Curve con veCRV.

#### Mecánica

1. El usuario bloquea CRV por un periodo (1 semana a 4 años)
2. Recibe veCRV proporcional al tiempo de lock:
   - 1 CRV locked 4 años = 1 veCRV
   - 1 CRV locked 1 año = 0.25 veCRV
3. veCRV decae linealmente hasta 0 al expirar el lock
4. veCRV otorga: voting power, fee sharing, boost en farming rewards

#### Flywheel

```
  +------------------+
  |  Protocolo genera|
  |  fees de trading |
  +--------+---------+
           |
           v
  +--------+---------+      +------------------+
  |  Fees se reparten|      |  Más TVL = más   |
  |  a holders de    |----->|  fees = más       |
  |  veCRV           |      |  incentivo a      |
  +------------------+      |  lockear CRV      |
                            +--------+---------+
                                     |
           +-------------------------+
           |
           v
  +--------+---------+      +------------------+
  |  Más CRV locked  |      |  Más veCRV =     |
  |  = menos CRV     |----->|  más voting power |
  |  circulante      |      |  = controlas      |
  +------------------+      |  emisiones        |
                            +--------+---------+
                                     |
           +-------------------------+
           |
           v
  +--------+---------+
  |  Dirigir emisiones|
  |  a tu pool =     |
  |  más rewards =   |
  |  más liquidez    |
  +--------+---------+
           |
           v
  +--------+---------+
  |  Más liquidez =  |
  |  más volumen =   |
  |  más fees        |
  +------------------+
           |
           +-------> (vuelve al inicio)
```

#### Gauge Voting

- Los holders de veCRV votan sobre cómo distribuir las emisiones de CRV
- Cada pool tiene un "gauge" que recibe emisiones proporcionales a los votos
- Esto crea un mercado de votos: protocolos sobornan a holders de veCRV para que voten por su pool

---

### 3.4 Liquidity Mining

#### Por qué existe

- Un nuevo protocolo necesita liquidez para funcionar (DEX sin liquidez = alto slippage)
- Liquidity mining: "te pago tokens del protocolo por proveer liquidez"
- Bootstrap efectivo: atrae capital rápidamente

#### Problemas

```
  TVL
    |
    |     .........
    |   ..         ..
    |  .    Farm     ..
    | .   activo       ..
    |.                    ...
    |                        .......
    |                               ........  (sin emisiones)
    +-------------------------------------------> Tiempo
         ^                ^
         |                |
      Inicio           Farm termina
      mining           capital se va
```

- **Mercenary capital**: los farmers venden los tokens inmediatamente, creando presión de venta constante
- **Emissions dilution**: los tokens emitidos diluyen a los holders existentes
- **No sticky**: cuando las emisiones terminan, el capital migra al siguiente farm
- **Race to the bottom**: protocolos compiten emitiendo más tokens

#### Diseños mejores

**Protocol-Owned Liquidity (POL) - Olympus DAO:**
- En lugar de rentar liquidez (mining), el protocolo la compra
- Mecanismo de bonding: usuarios venden LP tokens al protocolo a cambio de tokens con descuento + vesting
- El protocolo acumula liquidez propia que no se va
- Trade-off: complejidad, dependencia del precio del token

**Bonds (mecanismo):**

```
  +----------+                    +----------+
  | Usuario  |  LP tokens o      | Protocol |
  |          |  stablecoins      | Treasury |
  |          |------------------->|          |
  |          |                    |          |
  |          |  Tokens del        |          |
  |          |  protocolo con     |          |
  |          |  descuento +       |          |
  |          |  vesting (5-7d)    |          |
  |          |<-------------------|          |
  +----------+                    +----------+
```

**Liquidity Bootstrapping Pool (LBP):**
- Peso dinámico que cambia con el tiempo (e.g., 90/10 -> 50/50)
- Crea price discovery justo sin front-running
- Usado para token launches

---

### 3.5 Fee Distribution Models

| Modelo              | Descripción                                          | Pros                           | Contras                        |
|---------------------|------------------------------------------------------|--------------------------------|--------------------------------|
| Buy-back and burn   | Revenue compra tokens y los quema                    | Reduce supply, simple          | No beneficia holders directamente |
| Staking rewards     | Revenue se distribuye a stakers                      | Incentiva hold/stake           | Puede ser "security" regulatorio |
| ve-distribution     | Revenue solo para ve-lockers                         | Alinea incentivos largo plazo  | Baja liquidez del token        |
| Treasury            | Revenue va al treasury del DAO                       | Flexibilidad, runway           | No beneficia holders directamente |
| Dividendos          | Distribución proporcional a holders                  | Simple, directo                | Riesgo regulatorio alto        |

**Consideración regulatoria**: en muchas jurisdicciones, un token que distribuye revenue directamente a holders puede clasificarse como security. Muchos protocolos evitan el "fee switch" por esta razón (ejemplo: UNI no tiene fee sharing activo).

---

### 3.6 Token Launch Strategies

| Estrategia          | Descripción                                           | Ejemplo                        |
|---------------------|-------------------------------------------------------|--------------------------------|
| Fair launch         | Sin pre-mine, sin VC allocation, minería abierta      | Bitcoin, YFI                   |
| ICO                 | Venta pública de tokens antes del lanzamiento          | Ethereum (2014)                |
| IDO                 | Venta en DEX (launchpad) descentralizado               | Múltiples en Balancer LBP      |
| Retroactive airdrop | Tokens distribuidos a usuarios históricos del protocolo| Uniswap, Optimism, Arbitrum    |
| Gradual emission    | Sin evento de launch, tokens se emiten por uso         | Compound (COMP farming)        |

---

## 4. Análisis de casos reales

### 4.1 Curve Wars

**Contexto**: veCRV controla hacia dónde van las emisiones de CRV (gauge voting). Esto creó una "guerra" por acumular veCRV.

**Actores:**
- **Curve**: el protocolo base con el mecanismo ve
- **Convex Finance**: acumula CRV de usuarios, los lockea permanentemente, vota en su nombre. Los depositantes reciben cvxCRV + rewards sin lockear ellos mismos
- **Bribe markets** (Votium, HiddenHand): protocolos pagan a holders de vlCVX (Convex locked) para que voten por sus gauges

**Resultado**: un meta-juego de gobernanza donde controlar votos es más valioso que el yield directo. Convex controla ~50% de todo el veCRV.

**Lección**: el diseño de governance puede crear mercados secundarios inesperados. El poder de voto tiene valor económico.

### 4.2 Olympus DAO: (3,3) y Protocol-Owned Liquidity

**Mecanismo:**
- Bonding: comprar OHM con descuento vendiendo LP tokens o stables al treasury
- Staking: stakear OHM para recibir rebases (emisiones inflacionarias)
- (3,3): teoría de juegos donde si todos stakean, todos ganan (Nash equilibrium)

**Qué salió bien:**
- Concepto innovador de POL (Protocol-Owned Liquidity)
- El treasury acumuló cientos de millones en assets

**Qué salió mal:**
- APY de miles de % no es sostenible
- Cuando el precio bajó, se creó un death spiral (unstake -> sell -> más caída)
- (3,3) asumía cooperación racional, pero el incentivo individual es defeccionar

**Lección**: tokenomics que dependen de precio ascendente son frágiles. POL como concepto es valioso, pero las emisiones extremas son insostenibles.

### 4.3 Uniswap: governance token sin fee switch

**Situación:**
- UNI es un governance token puro (vota sobre el protocolo)
- El "fee switch" permitiría que parte de los fees de trading vayan a UNI holders
- Nunca se ha activado (a pesar de múltiples propuestas)

**Por qué no se activa:**
- Riesgo regulatorio: distribuir fees podría hacer de UNI un security
- Impacto en LPs: si el protocolo toma un cut, los LPs ganan menos y podrían migrar
- Valor del token: sin fee sharing, la demanda por UNI es débil (solo governance)

**Lección**: las decisiones políticas y regulatorias pueden ser tan importantes como el diseño técnico.

### 4.4 MakerDAO: MKR burn y Endgame

**Modelo original:**
- El sistema cobra stability fees por DAI prestado
- El surplus se usa para comprar y quemar MKR (buyback-and-burn)
- Si hay bad debt, se minta nuevo MKR y se vende (MKR como backstop)

**Endgame restructuring:**
- Reorganización en SubDAOs con sus propios tokens
- Transición a NewStableToken y NewGovToken
- Objetivo: mayor descentralización y resistencia regulatoria

**Lección**: los modelos de tokenomics evolucionan. El burn model de MKR es elegante pero la complejidad del sistema requiere reestructuración continua.

---

## 5. Ejercicio de diseño

### Diseñar tokenomics para un DEX ficticio: "NovaSwap"

Define los siguientes componentes:

#### A. Token Supply
- Total supply y distribución (team, investors, community, treasury)
- Vesting schedules para cada categoría
- Justificar las proporciones elegidas

#### B. Emission Schedule
- Cómo se emiten los tokens comunitarios
- Curva de emisión (linear, decay, epoch-based)
- Duración total del programa de emisiones
- Diagrama de supply circulante en el tiempo

#### C. Token Utility
- Al menos 3 utilidades concretas
- Para cada una: por qué crea demanda, cómo funciona técnicamente

#### D. Governance Mechanism
- Tipo: token voting, ve-model, delegación, quadratic
- Quórum y thresholds
- Timelock y ejecución

#### E. Fee Distribution
- Qué porcentaje de fees va a: LPs, protocol, stakers/lockers
- Justificación de las proporciones
- Análisis de implicaciones regulatorias

#### F. Anti-Whale Measures
- Caps de voting power
- Lock periods
- Gradual unlock schedules
- Resistencia a Sybil

#### G. Attack Vectors
- Governance attack (acumular tokens para propuesta maliciosa)
- Flash loan voting
- Mercenary farming
- Death spiral scenario
- Para cada uno: mitigación propuesta

**Formato de entrega**: documento con diagramas, tablas, fórmulas y análisis de escenarios.

---

## 6. Trade-offs y decisiones

| Decisión                          | Opción A                     | Opción B                      | Consideración                            |
|-----------------------------------|------------------------------|-------------------------------|------------------------------------------|
| Descentralización de governance   | 1 token = 1 voto             | ve-model (lock = más poder)   | Accesible vs long-term aligned           |
| Emisiones                         | Altas (crecimiento rápido)   | Bajas (menos dilución)        | Bootstrap liquidez vs preservar valor    |
| Fee sharing                       | Activar (demanda por token)  | Desactivar (evitar regulación)| Revenue para holders vs riesgo legal     |
| Launch                            | Fair launch (sin VC)         | VC-funded + airdrop           | Descentralización vs funding/desarrollo  |
| Supply                            | Fixed (escasez)              | Inflationary (incentivos)     | Store of value vs flexibilidad           |
| Liquidity                         | Mining rentado               | POL (comprado)                | Rápido vs sostenible                     |
| Vesting del team                  | Corto (1 año)                | Largo (4 años)                | Retención vs alineación                  |

---

## 7. Recursos

### Papers y modelos
- [Tokenomics 101](https://every.to/napkin-math/tokenomics-101) - Nat Eliason
- [Curve Whitepaper](https://curve.fi/files/CurveDAO.pdf)
- [Olympus DAO Docs](https://docs.olympusdao.finance/)
- [ve-token Economics](https://www.mechanism.capital/ve-token/) - Mechanism Capital

### Talks
- [Token Engineering Fundamentals](https://www.youtube.com/watch?v=bMlLz4sFz8c)
- [DeFi Token Design](https://www.youtube.com/watch?v=LMTe7HkqAKk) - Bankless
- [The Curve Wars Explained](https://www.youtube.com/watch?v=ao-HG9E27HA)

### Herramientas y datos
- [Token Terminal](https://tokenterminal.com/) - Revenue y métricas financieras de protocolos
- [Dune Analytics](https://dune.com/) - Dashboards on-chain
- [DefiLlama](https://defillama.com/) - TVL comparativo
- [CoinGecko](https://www.coingecko.com/) - Datos de supply, vesting, distribución

### Artículos
- [Liquidity Mining: A User-Centric Token Distribution Strategy](https://medium.com/bollinger-investment-group/liquidity-mining-a-user-centric-token-distribution-strategy-1d05c5174641)
- [The Problem with Mercenary Capital](https://www.nansen.ai/research/the-problem-with-mercenary-capital)
- [Protocol-Owned Liquidity](https://olympusdao.medium.com/introducing-protocol-owned-liquidity-6a12a15d8a3b)

---

## 8. Checkpoint

Antes de avanzar al siguiente módulo, verifica que puedes:

- [ ] Explicar la diferencia entre fixed supply, inflationary y deflationary
- [ ] Describir cómo funciona EIP-1559 base fee burn y cuándo Ethereum es deflacionario
- [ ] Clasificar al menos 5 tipos de token utility con ejemplos reales
- [ ] Explicar el modelo ve-token completo: lock, voting, fee sharing, boost
- [ ] Dibujar el flywheel de Curve y explicar cómo Convex lo amplifica
- [ ] Identificar 3 problemas de liquidity mining y proponer alternativas
- [ ] Explicar Protocol-Owned Liquidity y por qué es más sostenible que mining
- [ ] Analizar por qué Uniswap no ha activado el fee switch
- [ ] Describir el death spiral de Olympus DAO y qué lo causó
- [ ] Completar el ejercicio de diseño de tokenomics para NovaSwap
- [ ] Evaluar un tokenomics dado e identificar vectores de ataque
