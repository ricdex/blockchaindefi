# Modulo 03: DeFi Primitives

## Objetivo

Al completar este modulo seras capaz de:

- Entender el modelo de Automated Market Maker (AMM) con constant product (x*y=k)
- Implementar un AMM basico con liquidity provision y swaps
- Comprender impermanent loss con ejemplo numerico
- Conocer los fundamentos de lending/borrowing (collateral, interest, liquidation)
- Entender el estandar ERC-4626 para vaults
- Identificar vulnerabilidades criticas en protocolos DeFi

---

## Prerequisitos

- **Modulo 01** completado (Solidity fundamentals)
- **Modulo 02** completado (ERC-20 y tokens)
- Entender `transferFrom` y el patron `approve`
- Foundry con tests pasando

---

## Conceptos clave

### 1. Automated Market Maker (AMM)

Un AMM reemplaza el order book tradicional con una formula matematica que determina el precio.

#### Constant Product Formula: x * y = k

```
  Reserva TokenB
  ^
  |
  |  .
  |   .
  |    ..
  |      ...
  |         .....
  |              ..........
  |                         .................
  +-------------------------------------------------> Reserva TokenA

  La curva x * y = k
  Donde x = reserva de TokenA, y = reserva de TokenB
```

**Ejemplo de swap:**

```
Estado inicial:
  reserveA = 1000 (TokenA)
  reserveB = 1000 (TokenB)
  k = 1000 * 1000 = 1_000_000

Usuario quiere comprar TokenB con 100 TokenA:
  Nueva reserveA = 1000 + 100 = 1100
  Nueva reserveB = k / nueva_reserveA = 1_000_000 / 1100 = 909.09
  TokenB que recibe = 1000 - 909.09 = 90.91

Precio efectivo: pago 100 TokenA, recibo ~90.91 TokenB
Precio unitario: 100 / 90.91 = 1.1 TokenA por TokenB
(El precio "justo" era 1:1, pero el slippage lo encarece)
```

#### Flujo de un swap

```
  Usuario                         AMM Contract
    |                                  |
    |-- approve(AMM, amountIn) ------->|
    |                                  |
    |-- swap(tokenA, amountIn) ------->|
    |                                  |
    |   1. transferFrom(user, AMM, amountIn)
    |   2. Calcular amountOut con x*y=k
    |   3. Cobrar fee (0.3%)
    |   4. transfer(user, amountOut)
    |   5. Actualizar reservas
    |                                  |
    |<-- amountOut tokens -------------|
```

#### Liquidity Provision

Los liquidity providers (LPs) depositan ambos tokens en proporcion y reciben LP tokens que representan su participacion.

```
  LP deposita:                       LP retira:
  100 TokenA + 100 TokenB            Quema 50 LP tokens
         |                                  |
         v                                  v
  Recibe LP tokens                   Recibe TokenA + TokenB
  proporcional al pool               proporcional a su share
```

Formula de LP tokens en primer deposito:
```
lpTokens = sqrt(amountA * amountB)
```

Depositos subsiguientes:
```
lpTokens = min(
    (amountA * totalLP) / reserveA,
    (amountB * totalLP) / reserveB
)
```

### 2. Impermanent Loss

Cuando el precio relativo de los tokens cambia, el LP pierde valor comparado con simplemente holdear.

**Ejemplo numerico:**

```
Estado inicial:
  LP deposita: 1 ETH ($1000) + 1000 USDC
  Pool total:  1 ETH + 1000 USDC
  k = 1 * 1000 = 1000

ETH sube a $4000:
  Arbitrajistas ajustan el pool hasta que:
  x * y = 1000
  y/x = 4000  (el precio de ETH en USDC)

  Resolviendo:
  x = sqrt(1000 / 4000) = 0.5 ETH
  y = sqrt(1000 * 4000) = 2000 USDC

  Valor en pool: 0.5 ETH * $4000 + 2000 USDC = $4000
  Valor si holdeo: 1 ETH * $4000 + 1000 USDC = $5000

  Impermanent Loss = ($5000 - $4000) / $5000 = 20%
```

```
  IL segun cambio de precio:
  +------------------+-------+
  | Cambio de precio |  IL   |
  +------------------+-------+
  | 1.25x            | 0.6%  |
  | 1.50x            | 2.0%  |
  | 2x               | 5.7%  |
  | 3x               | 13.4% |
  | 4x               | 20.0% |
  | 5x               | 25.5% |
  +------------------+-------+
```

Se llama "impermanent" porque si el precio vuelve al original, la perdida desaparece. Si el LP retira cuando el precio es diferente, la perdida se vuelve permanente.

### 3. Lending y Borrowing (Conceptual)

Los protocolos de lending (Aave, Compound) permiten:

```
  Depositor                        Lending Pool                     Borrower
     |                                  |                               |
     |-- deposit(USDC) --------------->|                               |
     |                                  |                               |
     |   Recibe aTokens (interes)      |                               |
     |<-- aUSDC ----------------------|                               |
     |                                  |                               |
     |                                  |<-- deposit(ETH) collateral --|
     |                                  |                               |
     |                                  |-- borrow(USDC) ------------->|
     |                                  |                               |
     |                                  |   Health Factor =            |
     |                                  |   (collateral * LTV) / debt  |
     |                                  |                               |
     |                                  |   Si HF < 1: LIQUIDACION    |
```

Conceptos clave:
- **Collateral Factor / LTV**: cuanto puedes pedir prestado vs tu colateral (ej. 75%)
- **Interest Rate**: variable, basado en utilizacion del pool
- **Health Factor**: si baja de 1, tu posicion puede ser liquidada
- **Liquidation**: un tercero paga tu deuda y se lleva tu colateral con descuento

### 4. ERC-4626: Tokenized Vault Standard

ERC-4626 estandariza vaults que generan yield:

```
  Usuario deposita tokens ──> Vault genera yield ──> Usuario retira tokens + yield
       (deposit/mint)                                    (withdraw/redeem)

  Funciones clave:
  - deposit(assets, receiver) -> shares
  - withdraw(assets, receiver, owner) -> shares
  - convertToShares(assets) -> shares
  - convertToAssets(shares) -> assets
```

La relacion shares/assets cambia conforme el vault genera yield.

---

## Ejercicio practico: SimpleAMM

### Descripcion

Implementa un AMM de producto constante (x*y=k) para dos tokens ERC-20 con fee de 0.3%.

### Arquitectura

```
+------------------+          +------------------+
|   MockERC20 A    |          |   MockERC20 B    |
|   (TokenA)       |          |   (TokenB)       |
+--------+---------+          +--------+---------+
         |                             |
         +----------+  +  +-----------+
                    |  |  |
              +-----v--v--v------+
              |    SimpleAMM     |
              |                  |
              | reserveA         |
              | reserveB         |
              | LP tokens (ERC20)|
              | fee: 0.3%        |
              +------------------+
```

### Funcionalidades

1. **addLiquidity(amountA, amountB)**: depositar ambos tokens, recibir LP tokens
2. **removeLiquidity(lpAmount)**: quemar LP tokens, recibir ambos tokens
3. **swap(tokenIn, amountIn)**: intercambiar un token por otro
4. **getReserves()**: consultar reservas actuales
5. **getAmountOut(tokenIn, amountIn)**: calcular cuanto recibirias por un swap

### Archivos

- `contracts/IERC20.sol` - interfaz minima ERC-20
- `contracts/MockERC20.sol` - token de prueba con mint publico
- `contracts/SimpleAMM.sol` - el AMM con LP tokens
- `test/SimpleAMM.t.sol` - tests completos

---

## Vulnerabilidades relevantes

### 1. Price Manipulation en AMMs

Un atacante puede manipular el precio en un pool con poca liquidez:

```
1. Pool tiene 100 TokenA y 100 TokenB (k=10000)
2. Atacante compra 90 TokenB con ~900 TokenA
   Pool: 1000 TokenA, ~10 TokenB
3. Otro contrato consulta el precio del pool
   -> Precio de TokenB segun pool = 100:1 (inflado)
4. El contrato victima usa ese precio para algo (ej. liquidacion)
5. Atacante revierte el swap
```

**Mitigacion**: usar TWAP (Time-Weighted Average Price) o oracles externos.

### 2. First Depositor Attack en Vaults

```
1. Vault esta vacio
2. Atacante deposita 1 wei (1 share)
3. Atacante envia 1000 tokens directamente al vault (donation)
4. 1 share = 1001 tokens ahora
5. Victima deposita 999 tokens
   shares = 999 * 1 / 1001 = 0 (truncado a 0!)
6. Atacante retira su 1 share = todos los tokens

Resultado: atacante roba los tokens de la victima
```

**Mitigacion**: mintear "dead shares" al deployar, o usar un deposito minimo.

### 3. Lending sin Oracle: Riesgo de Precio Stale

Si un protocolo de lending usa el precio del pool como oracle:

```
Precio real de ETH: $2000
Atacante manipula pool: precio aparenta $200
Protocolo cree que el collateral vale 10x menos
-> Liquidacion injusta -> Atacante compra collateral barato
```

**Mitigacion**: siempre usar oracles confiables (Chainlink, Pyth) para precios.

### 4. Reentrancy en Swaps

Si el token involucrado en un swap tiene un hook (ERC-777, tokens con callback):

```
1. swap() calcula amountOut
2. swap() transfiere tokenOut al atacante
3. El token ejecuta un callback al atacante
4. El atacante re-entra en swap() con estado inconsistente
5. Doble gasto
```

**Mitigacion**: patron checks-effects-interactions, reentrancy guard.

### 5. Rounding Errors en LP Tokens

Con numeros pequenos, las divisiones enteras pueden causar perdida de precision:

```solidity
// Si amountA = 1, totalLP = 100, reserveA = 1000:
lpTokens = (1 * 100) / 1000 = 0  // LP recibe 0 tokens!
```

**Mitigacion**: usar `MINIMUM_LIQUIDITY` como Uniswap V2.

---

## Recursos

- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)
- [Uniswap V2 Core Contracts](https://github.com/Uniswap/v2-core)
- [Constant Product Market Maker (x*y=k)](https://docs.uniswap.org/contracts/v2/concepts/protocol-overview/how-uniswap-works)
- [Impermanent Loss Calculator](https://dailydefi.org/tools/impermanent-loss-calculator/)
- [Aave V3 Documentation](https://docs.aave.com/)
- [EIP-4626: Tokenized Vault Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [First Depositor Attack](https://mixbytes.io/blog/overview-of-the-first-depositor-frontrunning-vulnerability)

---

## Checkpoint

Antes de avanzar al Modulo 04, verifica que puedes:

- [ ] Explicar la formula x*y=k y calcular un swap a mano
- [ ] Describir impermanent loss con un ejemplo numerico
- [ ] Explicar como se calculan los LP tokens (primer deposito vs subsiguientes)
- [ ] Describir el flujo basico de un protocolo de lending (deposit, borrow, liquidate)
- [ ] Explicar que es ERC-4626 y para que sirve
- [ ] Describir la vulnerabilidad de price manipulation en AMMs
- [ ] Describir el first depositor attack en vaults
- [ ] Tu SimpleAMM compila y todos los tests pasan
- [ ] Puedes explicar por que el fee de 0.3% se descuenta antes del calculo
