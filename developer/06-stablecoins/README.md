# Modulo 06: Stablecoins

## Objetivo

Al completar este modulo seras capaz de:

- Entender los tres tipos principales de stablecoins: fiat-backed, crypto-backed (CDP) y algoritmicas
- Comprender el mecanismo CDP (Collateralized Debt Position) en detalle
- Implementar un sistema de liquidacion con incentivos economicos
- Identificar vulnerabilidades criticas: oracle failure, bank run, depeg, governance attacks
- Construir un stablecoin CDP-based colateralizado con ETH

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (tipos, storage, modifiers, events)
- Modulo 02: Tokens and Standards (ERC-20 completo)
- Modulo 03: DeFi Primitives (AMMs, lending basico)
- Modulo 05: Oracles and Bridges (price feeds, oracle patterns)
- Foundry instalado y funcional

---

## Conceptos clave

### 1. Tipos de Stablecoins

Las stablecoins buscan mantener un precio estable (generalmente 1 USD). Existen tres categorias principales:

```
+---------------------+-------------------+-------------------+--------------------+
| Tipo                | Colateral         | Ejemplos          | Riesgo principal   |
+---------------------+-------------------+-------------------+--------------------+
| Fiat-backed         | USD en banco      | USDC, USDT        | Riesgo custodio    |
| Crypto-backed (CDP) | Crypto on-chain   | DAI (MakerDAO)    | Volatilidad        |
| Algoritmico         | Ninguno / parcial | UST (fallido)     | Death spiral       |
+---------------------+-------------------+-------------------+--------------------+
```

#### Fiat-backed (USDC, USDT)

```
Usuario ──deposita USD──> Emisor (Circle/Tether) ──mint──> USDC/USDT on-chain
Usuario ──redime USDC──>  Emisor ──devuelve USD──> Cuenta bancaria

Confianza: el emisor realmente tiene los USD en reserva
Riesgo:    censura, congelamiento de fondos, riesgo bancario
```

- **Mecanismo**: 1:1 respaldado por dolares (o equivalentes) en cuentas bancarias
- **Ventaja**: estabilidad fuerte mientras el emisor sea solvente
- **Desventaja**: centralizado, sujeto a regulacion y censura
- USDC (Circle): auditorias regulares, cumplimiento regulatorio
- USDT (Tether): historialmente cuestionado por falta de transparencia en reservas

#### Crypto-backed CDP (DAI / MakerDAO)

```
+------------------------------------------------------------------+
|                      CDP (Vault) en MakerDAO                      |
|                                                                   |
|  Usuario deposita ETH (colateral)                                |
|       |                                                           |
|       v                                                           |
|  +----------+    Ratio minimo: 150%                              |
|  | Vault    |    Ejemplo: deposita $300 ETH -> puede mintar      |
|  | ETH: $300|    hasta $200 DAI                                  |
|  | DAI: $200|                                                     |
|  | Ratio:150%                                                     |
|  +----------+                                                     |
|       |                                                           |
|       v                                                           |
|  Si ETH baja y ratio < 150% -> LIQUIDACION                      |
|  Liquidador paga deuda DAI -> recibe ETH con descuento           |
+------------------------------------------------------------------+
```

- **Mecanismo**: sobre-colateralizacion. Siempre hay mas colateral que deuda
- **Ventaja**: descentralizado, transparente, sin custodio
- **Desventaja**: ineficiencia de capital (necesitas >$1 de colateral por $1 de stablecoin)

#### Algoritmico (UST / Terra - FALLIDO)

```
MECANISMO TERRA/UST (simplificado):

  1 UST > $1  -->  Quemar $1 LUNA, mintear 1 UST  --> Aumenta supply UST --> precio baja
  1 UST < $1  -->  Quemar 1 UST, mintear $1 LUNA  --> Reduce supply UST  --> precio sube

  DEATH SPIRAL (Mayo 2022):
  UST depeg -> panico -> todos queman UST por LUNA -> LUNA se infla masivamente
  -> LUNA pierde valor -> no hay respaldo -> UST colapsa a $0
  -> ~$40B perdidos
```

- **Mecanismo**: usa mecanismos de arbitraje y control de supply sin colateral real
- **Ventaja** (teorica): eficiencia de capital maxima
- **Desventaja**: fragilidad extrema, propenso a death spirals
- **Leccion**: la historia de UST/Terra es el ejemplo mas claro de por que los stablecoins algoritmicos puros son extremadamente riesgosos

### 2. CDP en detalle (Collateralized Debt Position)

Un CDP es una posicion de deuda colateralizada. El usuario deposita colateral y puede generar (mintear) stablecoins hasta un limite determinado por el collateral ratio.

```
CICLO DE VIDA DE UN CDP:

  1. APERTURA
     Usuario deposita 1 ETH (precio: $3000)
     Colateral value = $3000

  2. MINTEO
     Con ratio 150%, puede mintear hasta $2000 en stablecoin
     Usuario mintea $1500 (ratio actual = 3000/1500 = 200%)

  3. USO
     Usuario usa los $1500 stablecoin libremente
     (trading, yield farming, pagos, etc.)

  4. CIERRE
     Usuario devuelve (burn) $1500 stablecoin
     + paga fee de estabilidad (stability fee)
     Retira su 1 ETH de colateral

  5. LIQUIDACION (si el precio cae)
     ETH baja a $2000
     Ratio = 2000/1500 = 133% < 150% (minimo)
     -> Posicion liquidable
     -> Liquidador paga $1500 deuda
     -> Recibe ETH con 10% descuento (~$1650 en ETH)
```

### 3. Mecanismo de liquidacion

La liquidacion es el mecanismo que mantiene la solvencia del sistema:

```
LIQUIDACION - FLUJO COMPLETO:

  +------------------+          +------------------+
  |   CDP en riesgo  |          |   Liquidador     |
  |  ETH: $2000      |          |   (Keeper Bot)   |
  |  Deuda: $1500    |          |                  |
  |  Ratio: 133%     |          |                  |
  +--------+---------+          +--------+---------+
           |                             |
           |    1. Detecta posicion      |
           |       undercollateralized   |
           |<----------------------------+
           |                             |
           |    2. Llama liquidate()     |
           |<----------------------------+
           |                             |
           |    3. Liquidador paga deuda |
           |       ($1500 stablecoin)    |
           +<----------------------------+
           |                             |
           |    4. Liquidador recibe     |
           |       colateral con 10%    |
           |       descuento            |
           +----------------------------->
           |    ($1650 en ETH)           |
           |                             |
           |    5. Excedente va al       |
           |       dueno del CDP         |
           +---->  ($350 en ETH)         |
           |                             |
  +--------+---------+          +--------+---------+
  | CDP cerrado/     |          | Liquidador:      |
  | reducido         |          | Profit = $150    |
  +------------------+          +------------------+

INCENTIVOS:
- Liquidador: gana el descuento (10%) como profit
- Sistema: se mantiene solvente (colateral > deuda)
- Dueno CDP: pierde parte del colateral pero no todo
```

#### Keeper Bots

Los keeper bots son programas automatizados que monitorean el blockchain buscando posiciones liquidables:

```
+------------+     +------------+     +-----------+
|  Keeper    |     |  Mempool / |     | Contrato  |
|  Bot       |---->|  Blockchain|---->| CDP       |
+------------+     +------------+     +-----------+
     |                                      |
     |  1. Lee todos los CDPs               |
     |  2. Verifica ratios vs precio actual |
     |  3. Si ratio < minimo:              |
     |     -> Enviar tx liquidate()        |
     |  4. Compite con otros bots (MEV)    |
     +--------------------------------------+
```

### 4. Mecanismo de estabilizacion de precio

```
PRECIO DEL STABLECOIN SUBE SOBRE $1:

  Stablecoin = $1.02
       |
       v
  Arbitrajistas depositan colateral
  -> Mintean stablecoin a valor nominal ($1)
  -> Venden en mercado a $1.02
  -> Profit: $0.02 por token
  -> Supply aumenta -> precio baja a $1


PRECIO DEL STABLECOIN BAJA DE $1:

  Stablecoin = $0.98
       |
       v
  Usuarios con CDPs abiertos:
  -> Compran stablecoin a $0.98
  -> Repagan su deuda (valor nominal $1)
  -> Profit: $0.02 por token
  -> Supply disminuye -> precio sube a $1
```

---

## Ejercicio practico: SimpleStablecoin (CDP-based)

### Descripcion

Implementa un stablecoin CDP-based colateralizado con ETH. El sistema permite depositar ETH como colateral, mintear un stablecoin ERC-20, y tiene un mecanismo de liquidacion cuando las posiciones caen por debajo del ratio minimo.

### Arquitectura

```
+-------------------------------------------------------------------+
|                        SimpleStablecoin                            |
|                                                                    |
|  +------------------+     +------------------+                     |
|  | MockOracle       |     | ERC-20 Stablecoin|                     |
|  | ETH/USD price    |     | (mint/burn)      |                     |
|  +--------+---------+     +--------+---------+                     |
|           |                        |                               |
|           v                        v                               |
|  +------------------------------------------------+               |
|  |              CDP Manager                        |               |
|  |                                                 |               |
|  |  mapping(address => CDP)                        |               |
|  |    CDP { collateral, debt }                     |               |
|  |                                                 |               |
|  |  depositCollateral() --> msg.value -> CDP       |               |
|  |  mintStablecoin(amount) --> verifica ratio      |               |
|  |  burnStablecoin(amount) --> reduce deuda        |               |
|  |  withdrawCollateral(amount) --> verifica ratio  |               |
|  |  liquidate(user) --> si ratio < 150%            |               |
|  +------------------------------------------------+               |
+-------------------------------------------------------------------+

FLUJO DE LIQUIDACION:

  Precio ETH cae
       |
       v
  CDP ratio < 150%
       |
       v
  Liquidador llama liquidate(user)
       |
       v
  Liquidador transfiere stablecoin (= deuda del CDP)
       |
       v
  Liquidador recibe colateral ETH con 10% descuento
       |
       v
  CDP queda cerrado (collateral = 0, debt = 0)
```

### Archivos

- `contracts/SimpleStablecoin.sol` - contrato principal con logica CDP y ERC-20
- `contracts/MockOracle.sol` - oracle mock para precio ETH/USD
- `test/SimpleStablecoin.t.sol` - tests completos

---

## Vulnerabilidades relevantes

### 1. Oracle Failure / Manipulation

```
ATAQUE: Manipulacion de Oracle

  1. Atacante manipula precio del oracle (flash loan en DEX)
  2. Precio reportado de ETH sube artificialmente
  3. Atacante mintea mucho mas stablecoin del que deberia
  4. Precio vuelve a la normalidad
  5. Sistema queda insolvente

  MITIGACION:
  - Usar oracles descentralizados (Chainlink)
  - Price feed con multiples fuentes
  - Circuit breakers: si precio cambia >X% en Y tiempo, pausar
  - TWAP (Time-Weighted Average Price)

  Oracle reporta       Precio real
  ETH = $10,000        ETH = $3,000
       |                    |
       v                    v
  Ratio aparenta        Ratio real
  10000/1500 = 666%     3000/1500 = 200%
  Usuario mintea mas    Sistema insolvente
  stablecoin            cuando se corrige
```

### 2. Bank Run / Depeg

```
ESCENARIO BANK RUN:

  1. Confianza en el sistema baja (hack, rumor, etc.)
  2. Holders venden stablecoin masivamente
  3. Precio baja de $1 (depeg)
  4. Holders de CDPs no tienen incentivo de recomprar para cerrar deuda
  5. Mas ventas -> mas depeg -> liquidaciones masivas
  6. Liquidaciones en cascada bajan precio del colateral
  7. Sistema puede volverse insolvente

  Precio stablecoin    Confianza    Liquidaciones
       $1.00              alta          ninguna
       $0.95              media         algunas
       $0.80              baja          muchas
       $0.50              panico        cascada
       $0.10              colapso       sistema insolvente
```

### 3. Governance Attacks on Parameters

```
ATAQUE: Manipulacion de Parametros

  Atacante acumula governance tokens
       |
       v
  Propone reducir collateral ratio de 150% a 100%
       |
       v
  Si pasa: usuarios pueden mintear 1:1
       |
       v
  Sistema se vuelve insolvente ante cualquier caida de precio

  OTROS PARAMETROS CRITICOS:
  - Stability fee (interes)
  - Liquidation penalty
  - Debt ceiling (maximo de stablecoin en circulacion)
  - Tipos de colateral aceptados
```

### 4. Liquidation Failure

```
ESCENARIO: Caida rapida de precio

  t=0: ETH = $3000, Ratio = 200%  -> saludable
  t=1: ETH = $2200, Ratio = 147%  -> liquidable
  t=2: ETH = $1400, Ratio = 93%   -> insolvente (deuda > colateral)

  Si nadie liquida entre t=0 y t=2:
  - No hay incentivo (colateral < deuda)
  - Sistema absorbe la perdida
  - MakerDAO usa "MKR dilution" como backstop
```

---

## Recursos

- [MakerDAO Whitepaper](https://makerdao.com/whitepaper/)
- [MakerDAO Documentation](https://docs.makerdao.com/)
- [Understanding DAI](https://blog.makerdao.com/what-is-dai/)
- [Stablecoin Trilemma](https://stablecoins.wtf/)
- [Terra/UST Post-Mortem](https://jumpcrypto.com/writing/terra-and-ust/)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [Liquity Protocol](https://www.liquity.org/) - Alternative CDP design
- [SWC Registry](https://swcregistry.io/)

---

## Checkpoint

Antes de avanzar al Modulo 07, verifica que puedes:

- [ ] Explicar las diferencias entre stablecoins fiat-backed, crypto-backed y algoritmicos
- [ ] Describir el ciclo de vida completo de un CDP (apertura, minteo, cierre, liquidacion)
- [ ] Explicar por que el collateral ratio debe ser mayor a 100% y que pasa si no se mantiene
- [ ] Describir como funcionan los incentivos de liquidacion (descuento al liquidador)
- [ ] Explicar el death spiral de UST/Terra y por que los algoritmicos puros son riesgosos
- [ ] Identificar al menos 3 vectores de ataque en sistemas de stablecoin
- [ ] Tu SimpleStablecoin compila sin errores
- [ ] Todos los tests pasan con `forge test`
- [ ] Puedes explicar como el oracle afecta la solvencia del sistema
