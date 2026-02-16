# Modulo 09: Advanced DeFi

## Objetivo

Al completar este modulo seras capaz de:

- Entender como funcionan los flash loans: prestamos sin colateral dentro de una sola transaccion
- Identificar casos de uso reales: arbitrage, collateral swaps, self-liquidation
- Comprender MEV (Maximal Extractable Value) y sus implicaciones en el ecosistema
- Disenar estrategias de yield aggregation y auto-compounding
- Implementar un FlashLoanProvider y un FlashLoanBorrower funcionales y testeados
- Reconocer vulnerabilidades especificas de DeFi avanzado

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (storage, modifiers, events)
- Modulo 02: Tokens and Standards (ERC-20 completo)
- Modulo 03: DeFi Primitives (AMM, lending basics)
- Modulo 04: Security Patterns (reentrancy, access control)
- Foundry instalado y funcional (`forge`, `cast`, `anvil`)

---

## Conceptos clave

### 1. Flash Loans

Un flash loan es un prestamo **sin colateral** que debe tomarse y devolverse dentro de la **misma transaccion**. Si el borrower no devuelve el monto + fee antes de que termine la transaccion, toda la operacion se revierte automaticamente.

```
Transaccion unica (todo o nada):
+------------------------------------------------------------------+
|                                                                  |
|  1. Borrower solicita flash loan                                 |
|       |                                                          |
|       v                                                          |
|  2. Pool transfiere tokens al Borrower                           |
|       |                                                          |
|       v                                                          |
|  3. Pool llama borrower.onFlashLoan(amount, fee, data)           |
|       |                                                          |
|       v                                                          |
|  4. Borrower ejecuta logica (arbitrage, swap, etc.)              |
|       |                                                          |
|       v                                                          |
|  5. Borrower devuelve amount + fee al Pool                       |
|       |                                                          |
|       v                                                          |
|  6. Pool verifica balance >= balanceAnterior + fee               |
|       |                                                          |
|       v                                                          |
|  SI: transaccion exitosa    NO: REVERT (todo se deshace)         |
|                                                                  |
+------------------------------------------------------------------+
```

**Caracteristicas fundamentales:**

- **Atomicidad**: todo ocurre en un solo bloque, en una sola transaccion
- **Sin colateral**: no necesitas depositar nada para pedir prestado
- **Sin riesgo para el lender**: si no se devuelve, la transaccion revierte
- **Fee**: tipicamente 0.05% - 0.3% del monto prestado

### 2. Casos de uso de Flash Loans

#### Arbitrage

```
+-------------+     borrow      +-----------+
| Flash Loan  | --------------> |  Borrower |
|    Pool     |                 |  Contract |
+-------------+                 +-----------+
      ^                           |       |
      |                      buy  |       | sell
      |                      low  |       | high
      |                           v       v
      |                      +---------+  +---------+
      |    repay + fee       | DEX A   |  | DEX B   |
      +<-------------------  | (cheap) |  | (pricey)|
                             +---------+  +---------+

Ganancia = (precioB - precioA) * amount - fee - gas
```

#### Collateral Swap

Cambiar el colateral de un prestamo sin cerrar la posicion:

```
1. Flash loan para obtener fondos
2. Repagar deuda en protocolo de lending
3. Retirar colateral original
4. Depositar nuevo colateral
5. Pedir prestado de nuevo
6. Repagar flash loan con lo prestado
```

#### Self-Liquidation

Cerrar una posicion de lending antes de ser liquidado (y pagar penalizacion):

```
1. Flash loan para obtener la deuda
2. Repagar la deuda del protocolo
3. Retirar el colateral liberado
4. Vender parte del colateral para repagar flash loan
5. Quedarse con el colateral restante (sin penalizacion de liquidacion)
```

### 3. MEV (Maximal Extractable Value)

MEV es el valor maximo que un productor de bloques (o un searcher) puede extraer reordenando, insertando o censurando transacciones dentro de un bloque.

```
Mempool (transacciones pendientes)
+--------------------------------------------+
|  tx1: User compra 100 ETH en Uniswap      |
|  tx2: User vende Token X                   |
|  tx3: Liquidation en Aave                  |
+--------------------------------------------+
         |
         v
   Searcher/Builder detecta oportunidad
         |
         v
+--------------------------------------------+
|  Bloque ordenado por MEV:                  |
|                                            |
|  tx_front: Searcher compra antes que User  |  <- Frontrunning
|  tx1: User compra (precio mas alto)        |  <- Victima
|  tx_back: Searcher vende despues           |  <- Backrunning
|                                            |
|  Ganancia del searcher = slippage forzado  |
+--------------------------------------------+
```

#### Tipos de MEV

```
+-------------------+-----------------------------------------------+
| Tipo              | Descripcion                                   |
+-------------------+-----------------------------------------------+
| Frontrunning      | Ejecutar antes que la victima para mover      |
|                   | el precio a tu favor                          |
+-------------------+-----------------------------------------------+
| Backrunning       | Ejecutar inmediatamente despues de una tx     |
|                   | grande para capturar arbitrage                |
+-------------------+-----------------------------------------------+
| Sandwich Attack   | Frontrun + backrun alrededor de la victima    |
|                   | para extraer valor del slippage               |
+-------------------+-----------------------------------------------+
| Liquidations      | Competir para ser el primero en liquidar      |
|                   | posiciones under-collateralized               |
+-------------------+-----------------------------------------------+
| JIT Liquidity     | Proveer liquidez justo antes de un swap       |
|                   | grande y retirarla inmediatamente despues      |
+-------------------+-----------------------------------------------+
```

#### Ecosistema MEV (post-Merge)

```
+----------+     bundles     +----------+     bloque     +-----------+
| Searcher | -------------> | Builder  | -------------> | Proposer  |
| (busca   |                | (arma el |                | (valida y |
|  MEV)    |                |  bloque) |                |  propone) |
+----------+                +----------+                +-----------+
     |                           |                           |
     | Flashbots Protect         | MEV-Boost                 | Ethereum
     | Private mempool           | PBS (Proposer-Builder     | Beacon Chain
     |                           |  Separation)              |
```

### 4. Yield Aggregation

Los yield aggregators optimizan automaticamente el rendimiento de los depositos moviendo fondos entre protocolos.

```
+-------------------+
|   Usuario deposita|
|   en Vault        |
+---------+---------+
          |
          v
+-------------------+
|   Strategy        |
|   Contract        |
+---------+---------+
          |
    +-----+------+--------+
    |            |         |
    v            v         v
+--------+  +--------+  +--------+
| Aave   |  | Comp.  |  | Curve  |
| 3.2%   |  | 4.1%   |  | 5.0%   |  <- Strategy elige el mejor
+--------+  +--------+  +--------+

Auto-compounding:
1. Depositar en protocolo con mejor yield
2. Recolectar rewards periodicamente
3. Re-invertir rewards (compound)
4. Repetir
```

**Componentes clave:**

- **Vault**: contrato donde usuarios depositan (emite shares)
- **Strategy**: logica de inversion (donde y como colocar fondos)
- **Keeper/Harvester**: bot que ejecuta el auto-compounding
- **Performance fee**: porcentaje del yield que cobra el protocolo

---

## Ejercicio practico: Flash Loan Provider y Borrower

### Descripcion

Implementa un sistema de flash loans con dos contratos:

1. **FlashLoanProvider**: pool de liquidez que ofrece flash loans
2. **FlashLoanBorrower**: contrato ejemplo que toma un flash loan y simula arbitrage

### Arquitectura

```
Liquidity Providers          Flash Loan Flow

  LP1 --deposit()--->  +-------------------+
  LP2 --deposit()--->  | FlashLoanProvider |
  LP3 --deposit()--->  |                   |
                       | - poolBalance     |
  LP1 <--withdraw()--  | - deposits[]      |
                       | - fee: 0.1%       |
                       +--------+----------+
                                |
                       flashLoan(borrower, amount, data)
                                |
                                v
                       +-------------------+
                       | FlashLoanBorrower |
                       |                   |
                       | onFlashLoan()     |
                       |  1. recibe tokens |
                       |  2. ejecuta logica|
                       |  3. aprueba       |
                       |     repago        |
                       +-------------------+
```

### Archivos

- `contracts/FlashLoanProvider.sol` - pool con flash loans
- `contracts/FlashLoanBorrower.sol` - borrower de ejemplo
- `contracts/MockERC20.sol` - token ERC-20 para testing
- `test/FlashLoan.t.sol` - tests completos

---

## Como ejecutar

### Paso 0: Inicializar el proyecto Foundry

Si el proyecto no tiene `foundry.toml` ni `lib/` (estado limpio):

```bash
cd developer/09-advanced-defi

cp README.md README.md.bak
forge init --no-git --force
mv README.md.bak README.md
rm -rf src/ script/
rm -f test/Counter.t.sol

git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std
rm -rf lib/forge-std/.git
```

Edita `foundry.toml`:

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
```

### Paso 1: Compilar y testear

```bash
forge build
forge test -vv
```

### Paso 2: Deploy en Anvil

**Terminal 1: Levantar Anvil**

```bash
anvil
```

**Terminal 2: Configurar variables y desplegar**

```bash
export PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export DEPLOYER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export RPC=http://localhost:8545
```

**1. Desplegar MockERC20 (token para el pool):**

```bash
forge create contracts/MockERC20.sol:MockERC20 \
  --rpc-url $RPC \
  --private-key $PK \
  --constructor-args "Flash Token" "FTK"
```

Desglose del comando:

```
forge create contracts/MockERC20.sol:MockERC20
│            │                       │
│            │                       └─ Nombre del contrato (linea 21 de MockERC20.sol)
│            └─ Ruta al archivo .sol
└─ Comando de Foundry para desplegar

  --constructor-args "Flash Token" "FTK"
                     │              │
                     │              └─ _symbol (linea 21: string memory _symbol)
                     └─ _name (linea 21: string memory _name)

Ejecuta el constructor (lineas 21-24 de MockERC20.sol):
1. Guarda name = "Flash Token" (linea 22)
2. Guarda symbol = "FTK" (linea 23)
```

Output esperado:

```
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Deployed to: 0x...                                        <- address del MockERC20 (USAR ESTA)
Transaction hash: 0x...
```

```bash
export TOKEN=0x...  # Deployed to del output
```

**2. Desplegar FlashLoanProvider:**

```bash
forge create contracts/FlashLoanProvider.sol:FlashLoanProvider \
  --rpc-url $RPC \
  --private-key $PK \
  --constructor-args $TOKEN
```

Desglose del comando:

```
  --constructor-args $TOKEN
                     │
                     └─ _token (linea 76: address _token)

Ejecuta el constructor (lineas 76-78 de FlashLoanProvider.sol):
1. Guarda token = IERC20($TOKEN) (linea 77)
   El pool opera sobre este token ERC-20
```

```bash
export PROVIDER=0x...  # Deployed to del output
```

**3. Desplegar FlashLoanBorrower:**

```bash
forge create contracts/FlashLoanBorrower.sol:FlashLoanBorrower \
  --rpc-url $RPC \
  --private-key $PK \
  --constructor-args $PROVIDER $TOKEN
```

Desglose del comando:

```
  --constructor-args $PROVIDER $TOKEN
                     │         │
                     │         └─ _token (linea 51: address _token)
                     └─ _provider (linea 51: address _provider)

Ejecuta el constructor (lineas 51-54 de FlashLoanBorrower.sol):
1. Guarda provider = address del FlashLoanProvider (linea 52)
2. Guarda token = IERC20($TOKEN) (linea 53)
3. Inicializa shouldRepay = true (linea 54)
```

### Paso 3: Flujo completo en Anvil

```bash
# Mintear tokens y fondear el pool
cast send $TOKEN "mint(address,uint256)" $DEPLOYER 1000000000000000000000 \
  --private-key $PK --rpc-url $RPC

# Aprobar al provider para mover tokens
cast send $TOKEN "approve(address,uint256)" $PROVIDER 1000000000000000000000 \
  --private-key $PK --rpc-url $RPC

# Depositar liquidez en el pool (1000 tokens)
cast send $PROVIDER "deposit(uint256)" 1000000000000000000000 \
  --private-key $PK --rpc-url $RPC

# Verificar balance del pool
cast call $PROVIDER "poolBalance()(uint256)" --rpc-url $RPC
# 1000000000000000000000 (1000 tokens)

# Dar tokens al borrower para pagar el fee
cast send $TOKEN "mint(address,uint256)" $BORROWER 10000000000000000000 \
  --private-key $PK --rpc-url $RPC

# Ejecutar flash loan (100 tokens)
cast send $PROVIDER "flashLoan(address,uint256,bytes)" \
  $BORROWER 100000000000000000000 0x \
  --private-key $PK --rpc-url $RPC
```

---

## Vulnerabilidades relevantes

### 1. Flash Loan Price Manipulation

El ataque mas comun con flash loans: manipular un oraculo de precio on-chain.

```
Ataque tipico:
1. Flash loan de gran cantidad de Token A
2. Swap masivo en DEX: Token A -> Token B (mueve el precio)
3. El protocolo victima lee el precio del DEX (oraculo on-chain)
4. Ejecutar accion en protocolo victima con precio manipulado
   (ej: pedir prestado mas de lo que deberia, liquidar posiciones)
5. Revertir el swap
6. Repagar flash loan
7. Quedarse con la ganancia

Prevencion:
- NUNCA usar spot price de un DEX como oraculo
- Usar TWAP (Time-Weighted Average Price)
- Usar oracles externos (Chainlink)
- Verificar que el precio no cambio drasticamente en el mismo bloque
```

```solidity
// VULNERABLE: precio spot de un pool
uint256 price = reserveA / reserveB;  // manipulable con flash loan

// CORRECTO: oraculo externo con TWAP
uint256 price = chainlinkOracle.latestAnswer();
```

### 2. MEV Extraction / Sandwich Attacks

```
// VULNERABLE: swap sin proteccion de slippage
router.swapExactTokensForTokens(
    amountIn,
    0,               // amountOutMin = 0, acepta cualquier precio
    path,
    msg.sender,
    deadline
);

// CORRECTO: slippage protection
uint256 expectedOut = oracle.getExpectedOutput(amountIn);
uint256 minOut = expectedOut * 995 / 1000;  // 0.5% slippage max
router.swapExactTokensForTokens(
    amountIn,
    minOut,           // revert si el output es menor
    path,
    msg.sender,
    block.timestamp + 300  // deadline de 5 minutos
);
```

### 3. Composability Risk (Lego Attack Surface)

```
DeFi Composability:

+-------+    +-------+    +-------+    +-------+
| Proto |    | Proto |    | Proto |    | Proto |
|   A   |--->|   B   |--->|   C   |--->|   D   |
+-------+    +-------+    +-------+    +-------+

Si Proto B tiene un bug o cambia comportamiento:
- Proto C y D pueden fallar en cascada
- Un atacante puede explotar la cadena completa

Ejemplo real:
- Protocolo A: lending que acepta Token X como colateral
- Protocolo B: DEX con pool de Token X
- Atacante: flash loan -> manipula pool de B -> borrow en A con precio inflado
```

### 4. Reentrancy en Flash Loans

```solidity
// VULNERABLE: el callback del borrower puede re-entrar
function flashLoan(address borrower, uint256 amount) external {
    uint256 balanceBefore = token.balanceOf(address(this));
    token.transfer(borrower, amount);

    // El borrower puede llamar flashLoan de nuevo aqui
    IFlashLoanReceiver(borrower).onFlashLoan(amount, fee, "");

    require(token.balanceOf(address(this)) >= balanceBefore + fee);
}

// CORRECTO: usar nonReentrant modifier
function flashLoan(address borrower, uint256 amount) external nonReentrant {
    // ...
}
```

---

## Recursos

- [Aave V3 Flash Loans Documentation](https://docs.aave.com/developers/guides/flash-loans)
- [Uniswap V3 Flash Swaps](https://docs.uniswap.org/contracts/v3/guides/flash-integrations)
- [Flashbots Documentation](https://docs.flashbots.net/)
- [MEV Explore](https://explore.flashbots.net/)
- [Ethereum is a Dark Forest - Paradigm](https://www.paradigm.xyz/2020/08/ethereum-is-a-dark-forest)
- [Flash Loan Attacks - rekt.news](https://rekt.news/)
- [Yearn Finance Vault Design](https://docs.yearn.fi/)
- [EIP-3156: Flash Loans Standard](https://eips.ethereum.org/EIPS/eip-3156)
- [SWC Registry](https://swcregistry.io/)

---

## Checkpoint

Antes de avanzar al Modulo 10, verifica que puedes:

- [ ] Explicar como funciona un flash loan y por que es seguro para el lender
- [ ] Describir al menos 3 casos de uso reales de flash loans
- [ ] Explicar que es MEV y como funcionan los sandwich attacks
- [ ] Describir el flujo searcher -> builder -> proposer en Ethereum post-Merge
- [ ] Explicar como funciona un yield aggregator (vault + strategy + compounder)
- [ ] Describir por que usar spot price de un DEX como oraculo es peligroso
- [ ] Tu FlashLoanProvider compila y pasa todos los tests
- [ ] Tu FlashLoanBorrower ejecuta un flash loan exitosamente en tests
- [ ] Puedes explicar que pasa si el borrower no devuelve los fondos
- [ ] Entiendes el riesgo de composability en protocolos DeFi interconectados
