# Protocol Design

Cómo diseñar protocolos DeFi: invariantes, máquinas de estado, composabilidad, upgrades y modelos de fees.

---

## 1. Objetivo

Al completar este módulo serás capaz de:

- Definir invariantes matemáticas para un protocolo DeFi
- Modelar un protocolo como una máquina de estados con transiciones válidas
- Evaluar patrones de upgradeability y sus implicaciones de confianza
- Diseñar modelos de fees que alineen incentivos
- Analizar las decisiones de diseño de protocolos reales (Uniswap, Aave, Compound, Curve)
- Diseñar un protocolo de lending completo en papel

---

## 2. Prerequisitos

- Módulo 01 completado (Blockchain Internals)
- Matemáticas: álgebra básica, funciones continuas, concepto de invariante
- Familiaridad con al menos un protocolo DeFi como usuario (haber hecho un swap o deposit)
- Entender proxy patterns a nivel conceptual (no necesitas haberlos implementado)

---

## 3. Conceptos clave

### 3.1 Protocol Invariants

Un **invariant** es una propiedad matemática que debe cumplirse en todo momento, sin importar qué operaciones se ejecuten. Violar un invariant significa que el protocolo está roto.

#### AMM: Constant Product Formula

```
  x * y = k    (después de fees)

  Donde:
    x = reserva del token X
    y = reserva del token Y
    k = constante (solo cambia con add/remove liquidity)
```

Cuando un usuario hace swap de dx tokens X:

```
  x_new = x + dx
  y_new = k / x_new
  dy = y - y_new    (lo que recibe el usuario)

  Verificación: x_new * y_new = k  (debe mantenerse)
```

```
  Precio (y en función de x):

  y |
    |\.
    | \.
    |  \.
    |    \..
    |       \....
    |            \.........
    +----------------------------> x
           x * y = k
```

#### Lending: Collateral Ratio

```
  Para cada posición:
    collateral_value * collateral_factor > debt_value

  A nivel de protocolo:
    sum(all_deposits) >= sum(all_borrows)
    utilization_rate = total_borrows / total_deposits <= 1
```

Si `collateral_value * collateral_factor < debt_value`, la posición es liquidable.

#### Por qué importan los invariantes

- Son la **especificación formal** del protocolo
- Los tests deben verificar que se mantienen ante cualquier secuencia de operaciones
- Los auditors los usan como base del análisis
- Las vulnerabilidades frecuentemente son violaciones de invariantes

---

### 3.2 State Machine Design

Todo protocolo DeFi puede modelarse como una máquina de estados finita.

```
  +-------------+     deposit()     +-------------+
  |             |------------------>|             |
  |   EMPTY     |                   |   ACTIVE    |
  |  (no funds) |<------------------|  (has funds)|
  +-------------+     withdraw()    +------+------+
                                           |
                                    borrow() |
                                           v
                                    +------+------+
                                    |  LEVERAGED  |
                                    | (has debt)  |
                                    +------+------+
                                           |
                          price drops below |
                          liquidation       |
                          threshold         v
                                    +------+------+
                                    | LIQUIDATABLE|
                                    +------+------+
                                           |
                                 liquidate() |
                                           v
                                    +------+------+
                                    |  LIQUIDATED |
                                    +-------------+
```

**Reglas para diseñar la máquina de estados:**

1. Enumerar todos los estados posibles
2. Definir todas las transiciones válidas (funciones)
3. Definir precondiciones para cada transición (require/assert)
4. Verificar que no existen transiciones no deseadas
5. Verificar que no existen estados muertos (sin salida posible no intencional)

---

### 3.3 Composability

La composabilidad es la propiedad que permite que protocolos se usen como building blocks de otros protocolos.

```
  +----------+      +-----------+      +----------+
  | Uniswap  |----->|   Aave    |----->|  Yearn   |
  | (swap)   |      | (lending) |      | (vault)  |
  +----------+      +-----------+      +----------+
       ^                                     |
       |            +----------+             |
       +------------|  User    |<------------+
                    +----------+
```

**Niveles de composabilidad:**

1. **Token composability**: ERC-20 como interfaz universal. Cualquier token funciona con cualquier DEX.
2. **Protocol composability**: usar la salida de un protocolo como entrada de otro (LP tokens como collateral).
3. **Flash composability**: flash loans permiten componer operaciones atómicas sin capital.

**Riesgos de la composabilidad:**
- Dependencias en cascada: si un protocolo falla, los que dependen de él también
- Oracle manipulation: manipular el precio en un DEX puede afectar liquidaciones en un lending protocol
- Superficie de ataque amplificada: más integraciones = más vectores

---

### 3.4 Upgrade Patterns

#### Transparent Proxy

```
  +--------+         +-------+         +----------------+
  | User   |-------->| Proxy |-------->| Implementation |
  +--------+  call   |       | delegate|     V1         |
                     |       |  call   +----------------+
                     |       |
                     | admin |-------->+----------------+
                     | only  | upgrade | Implementation |
                     +-------+         |     V2         |
                                       +----------------+

  - El Proxy almacena el state (storage)
  - La Implementation contiene la lógica
  - Admin puede cambiar la implementation address
  - El storage layout debe ser compatible entre versiones
```

**Riesgo**: el admin puede cambiar la lógica arbitrariamente. Requiere confianza en el admin (multisig, timelock).

#### UUPS (Universal Upgradeable Proxy Standard)

- Similar al transparent proxy pero la función `upgradeTo()` está en la implementation, no en el proxy
- El proxy es más ligero (menos gas en cada call)
- Riesgo: si se despliega una implementation sin `upgradeTo()`, el contrato queda congelado

#### Diamond Pattern (EIP-2535)

```
  +--------+         +---------+
  | User   |-------->| Diamond |
  +--------+  call   |  Proxy  |
                     +----+----+
                          |
              +-----------+-----------+
              |           |           |
         +----+----+ +---+----+ +---+----+
         | Facet A | | Facet B| | Facet C|
         | (swap)  | | (lend) | | (admin)|
         +---------+ +--------+ +--------+
```

- Un proxy que puede delegar a múltiples implementations (facets)
- Cada función se enruta a un facet específico
- Permite upgrades granulares (cambiar solo un facet)
- Complejidad alta: difícil de auditar

#### Immutable con Migration

- Desplegar una nueva versión del contrato
- Migrar el estado (los usuarios mueven su posición)
- Sin proxy, sin riesgo de upgrade malicioso
- Desventaja: fricción para los usuarios, liquidez fragmentada

---

### 3.5 Fee Models

| Modelo                | Descripción                                    | Ejemplo            |
|-----------------------|------------------------------------------------|--------------------|
| Flat fee              | Tarifa fija por operación                      | 0.001 ETH por tx   |
| Percentage fee        | Porcentaje del monto                           | Uniswap 0.3%       |
| Tiered fees           | Porcentaje variable según tier                 | Uniswap V3 (0.01%, 0.05%, 0.3%, 1%) |
| Dynamic fee           | Basado en utilización u otra métrica           | Aave interest rate  |
| Protocol fee          | Parte del fee va al protocolo (treasury/token holders) | Uniswap fee switch |

#### Dynamic Fee (Utilization-Based)

```
  Interest
  Rate (%)
    |
    |                                    /
    |                                   /
    |                                  /  slope2
    |                                 /   (alto)
    |                      +---------+
    |                     /          optimal
    |                    / slope1    utilization
    |                   /  (bajo)    (e.g. 80%)
    |                  /
    |_________________/
    +----------------------------------------> Utilization (%)
    0                 80%                100%
```

Este modelo (usado por Aave/Compound) incentiva:
- **Baja utilización**: rates bajos, atraen borrowers
- **Alta utilización**: rates suben, incentivan repagos y nuevos depósitos
- **Optimal utilization**: punto de quiebre donde la pendiente cambia

---

### 3.6 Parameter Governance

Los parámetros críticos de un protocolo incluyen:
- Collateral factors por asset
- Interest rate model parameters (slopes, optimal utilization)
- Fee percentages
- Oracle sources
- Supported assets list

**Quién controla estos parámetros:**

| Mecanismo        | Velocidad | Descentralización | Riesgo                      |
|------------------|-----------|--------------------|-----------------------------|
| Admin EOA        | Inmediato | Nula               | Single point of failure     |
| Multisig         | Horas     | Baja-Media         | Colusión del multisig       |
| Timelock         | Días      | Media              | Lento para emergencias      |
| Governance vote  | Semanas   | Alta               | Voter apathy, baja participación |
| Immutable        | N/A       | Máxima             | No se puede adaptar         |

**Patrón común**: Governance para cambios normales + Guardian multisig para emergencias (pause).

---

## 4. Análisis de protocolos reales

### 4.1 Uniswap V2 vs V3: Concentrated Liquidity

**Uniswap V2**: liquidez uniforme a lo largo de toda la curva de precio (0 a infinito).

```
  Liquidez
    |
    |========================================
    |
    |   Liquidez distribuida uniformemente
    |   desde precio 0 hasta infinito
    |
    +----------------------------------------> Precio
    0                                     inf
```

**Uniswap V3**: los LPs eligen un rango de precio donde concentrar su liquidez.

```
  Liquidez
    |
    |              +----------+
    |              |          |
    |              |  LP1     |
    |         +----|-------+  |
    |         |    |       |  |
    |    +----|----+--+    |  |
    |    | LP2|   LP3 |    |  |
    |    |    |       |    |  |
    +----+----+-------+----+--+-----------> Precio
         Pa   Pb      Pc   Pd
```

**Decisiones de diseño V3:**
- **Capital efficiency**: si el precio se mueve en un rango estrecho, el LP gana fees como si tuviera mucha más liquidez
- **NFT positions**: cada posición es única (rango personalizado), representada como NFT en lugar de ERC-20 fungible
- **Multiple fee tiers**: 0.01% (stablecoins), 0.05% (pares correlacionados), 0.3% (standard), 1% (exóticos)
- **Trade-off**: mayor complejidad para LPs, riesgo de impermanent loss concentrado, posiciones fuera de rango no ganan fees

### 4.2 Aave V2 vs V3

**V2**: modelo estándar de lending pool compartido.

**V3 innovaciones:**
- **Efficiency Mode (eMode)**: para assets correlacionados (stETH/ETH), permite collateral factors más altos (hasta 97%)
- **Isolation Mode**: nuevos assets listados con límites de deuda y solo pueden usarse como collateral para stablecoins específicas
- **Portals**: transferencia de posiciones cross-chain a través de bridges aprobados
- **Mejor gestión de riesgo**: supply caps, borrow caps por asset

### 4.3 Compound V2 vs V3 (Comet)

**V2**: multi-asset pool. Depositas cualquier asset, pides prestado cualquier otro.

**V3 (Comet)**: simplificación radical.
- Solo se puede pedir prestado **un asset** (e.g., USDC)
- Múltiples assets de colateral
- Sin tokens de interés (cTokens)
- Más eficiente y más fácil de auditar
- Trade-off: menos flexible, pero más seguro

### 4.4 Curve: StableSwap Invariant

Curve usa una invariante híbrida entre constant sum (x + y = k) y constant product (x * y = k):

```
  A * (x + y) + x * y = A * D + (D/2)^2

  Donde:
    A = amplification coefficient (controla la "planitud")
    D = total liquidity en balance
```

```
  y |
    |  \                     constant sum (A -> inf)
    |   \    .....
    |    \ ./      \
    |     \.  Curve  \
    |     / \  swap   \
    |    /   \..........\
    |   /                 \  constant product (A -> 0)
    |  /                   \
    +----------------------------> x
```

- Con A alto: la curva se aplana cerca del punto de balance (bajo slippage para stablecoins)
- Con A bajo: se comporta como Uniswap (constant product)
- Diseño brillante para assets que deberían tener paridad 1:1

---

## 5. Ejercicio de diseño

### Diseñar un protocolo de lending en papel

Define completamente los siguientes componentes:

#### A. Core Invariants
- `total_deposits >= total_borrows` (siempre)
- `position_health = collateral_value * CF / debt_value > 1` (para cada posición no liquidable)
- `protocol_solvency = sum(deposits) + reserves >= sum(borrows)`

#### B. Interest Rate Model
- Define la curva de utilización con dos pendientes
- Parámetros: `base_rate`, `slope1`, `slope2`, `optimal_utilization`
- Fórmula para supply rate y borrow rate
- Cómo se acumula el interés (per-block vs per-second)

#### C. Liquidation Mechanism
- Cuándo una posición es liquidable (health factor < 1)
- Quién puede liquidar (permissionless)
- Incentivo: liquidation bonus (e.g., 5-10% descuento en collateral)
- Liquidación parcial vs total
- Cómo evitar que el protocolo quede con bad debt

#### D. Oracle Integration
- Qué tipo de oracle usar (Chainlink, TWAP, combinación)
- Cómo manejar oracle failures (circuit breaker, fallback)
- Frecuencia de actualización y su impacto en liquidaciones

#### E. Upgrade Strategy
- Proxy pattern elegido y justificación
- Timelock duration
- Proceso de governance para upgrades
- Emergency pause mechanism

#### F. Parameter Governance
- Quién puede cambiar qué parámetros
- Rangos válidos para cada parámetro (e.g., CF entre 0 y 0.95)
- Proceso para listar nuevos assets

#### G. Risk Parameters por Asset
- Tabla con: asset, collateral factor, liquidation bonus, borrow cap, supply cap
- Justificación basada en liquidez del mercado y volatilidad

**Formato de entrega**: documento estructurado con diagramas, fórmulas y justificaciones.

---

## 6. Trade-offs y decisiones

| Decisión                       | Opción A                       | Opción B                        | Consideración                             |
|--------------------------------|--------------------------------|---------------------------------|-------------------------------------------|
| Capital efficiency             | Pool compartido (Aave V2)      | Asset aislado (Compound V3)     | Más flexible vs más seguro                |
| Composabilidad                 | Maximizar integraciones        | Minimizar superficie            | Más uso vs menos riesgo sistémico         |
| Upgradeability                 | Proxy upgradeable              | Immutable + migration           | Agilidad vs trust minimization            |
| Fee model                      | Fijo                           | Dinámico                        | Predictibilidad vs eficiencia             |
| Liquidation                    | Parcial (% de la deuda)        | Total (toda la posición)        | UX vs protección del protocolo            |
| Oracle                         | Single source (Chainlink)      | Multi-source con fallback       | Simplicidad vs robustez                   |
| Governance                     | Token voting                   | Multisig + timelock             | Descentralización vs velocidad            |
| Listing new assets             | Permissionless                 | Governance-approved             | Accesibilidad vs gestión de riesgo        |

---

## 7. Recursos

### Papers y documentación de protocolos
- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)
- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf)
- [Aave V3 Technical Paper](https://github.com/aave/aave-v3-core/blob/master/techpaper/Aave_V3_Technical_Paper.pdf)
- [Compound V3 Documentation](https://docs.compound.finance/)
- [Curve StableSwap Paper](https://curve.fi/files/stableswap-paper.pdf)

### Talks
- [Hayden Adams - Uniswap V3 Design Decisions](https://www.youtube.com/watch?v=ClFR8aFOoTk)
- [Stani Kulechov - Building Aave](https://www.youtube.com/watch?v=aTp9er6S73M)
- [How to Build a DeFi Protocol](https://www.youtube.com/watch?v=l0vHMjJKVoE) - Finematics

### Artículos
- [A Note on Bundles of Complexity in DeFi](https://medium.com/gauntlet-networks/a-note-on-bundles-of-complexity-in-defi-3cae82da1e2d)
- [DeFi Composability as Superpower and Systemic Risk](https://medium.com/coinmonks/defi-composability-as-superpower-and-systemic-risk-f5a463be521)

### Herramientas
- [DeFi Llama](https://defillama.com/) - TVL y métricas de protocolos
- [Dune Analytics](https://dune.com/) - Queries on-chain para analizar protocolos
- [Gauntlet](https://www.gauntlet.network/) - Risk modeling para DeFi

---

## 8. Checkpoint

Antes de avanzar al siguiente módulo, verifica que puedes:

- [ ] Definir los invariantes core de un AMM y un lending protocol
- [ ] Modelar un protocolo como máquina de estados con todas las transiciones
- [ ] Explicar la diferencia entre Transparent Proxy, UUPS y Diamond Pattern
- [ ] Argumentar cuándo usar immutable vs upgradeable
- [ ] Diseñar un modelo de fees dinámico basado en utilización
- [ ] Explicar cómo Uniswap V3 logra mayor capital efficiency que V2
- [ ] Describir por qué Compound V3 eligió simplificar a single-borrow-asset
- [ ] Explicar la invariante StableSwap de Curve y el rol del parámetro A
- [ ] Completar el ejercicio de diseño del lending protocol
- [ ] Identificar al menos 3 riesgos de composabilidad entre protocolos
