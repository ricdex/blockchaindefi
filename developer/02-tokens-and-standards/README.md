# Modulo 02: Tokens and Standards

## Objetivo

Al completar este modulo seras capaz de:

- Distinguir un activo nativo, un token ERC-20, un wrapped token y un bridged token
- Entender el estandar ERC-20 a nivel de interfaz y de implementacion
- Comprender ERC-721 (NFTs) y ERC-1155 (multi-token) a nivel conceptual
- Implementar un ERC-20 completo desde cero (sin OpenZeppelin)
- Entender el patron `approve/transferFrom` y sus riesgos
- Implementar un mecanismo de vesting lineal con cliff
- Identificar vulnerabilidades comunes en tokens

---

## Prerequisitos

- **Modulo 01** completado (tipos, storage, modifiers, events, tests)
- Entendimiento de `msg.sender` y `mapping`
- Foundry funcionando con `forge test`

---

## Conceptos clave

### 0. Antes de ERC-20: ETH no es un token

En el modulo 01 viste que el ETH vive en el campo `balance` de cada cuenta y que un token vive en el storage de un contrato. De esa diferencia salen **cuatro tipos de activo** que vas a encontrar en cualquier wallet. Conviene saber distinguirlos a simple vista.

| Tipo | Quien lleva la cuenta | Ejemplo | Riesgo principal |
|------|-----------------------|---------|------------------|
| **Activo nativo** | El protocolo de la red (campo `balance`) | ETH en Ethereum, ETH en Arbitrum, BNB en BNB Chain | El de la red misma |
| **Token ERC-20** | Un contrato, en su `mapping` de balances | USDC, UNI, tu VestingToken | El emisor y el codigo del contrato |
| **Wrapped token** | Un contrato que custodia el activo nativo **en la misma red** y emite un ERC-20 1:1 | WETH en Ethereum | Casi ninguno: el contrato es trivial y siempre puedes desenvolver |
| **Bridged token** | Un contrato en la red B que representa un activo bloqueado en la red A | USDC.e en Arbitrum (respaldado por USDC bloqueado en Ethereum) | El bridge: si lo hackean, la representacion queda sin respaldo |

#### Por que existe WETH (wrapped ≠ bridged)

ETH no es un ERC-20: no tiene `approve` ni `transferFrom`. Un DEX que solo sabe mover ERC-20 no puede tocarlo. WETH resuelve eso **sin salir de la red**:

```
                 Ethereum Mainnet (una sola red, un solo estado)
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │  Alice ──deposit() + 1 ETH──────> Contrato WETH                    │
  │                                     - su balance nativo: +1 ETH    │
  │                                     - _balances[Alice]: +1 WETH    │
  │                                                                     │
  │  Alice <──1 ETH── withdraw(1) ─── Contrato WETH                    │
  │                                     - quema 1 WETH, devuelve 1 ETH │
  └─────────────────────────────────────────────────────────────────────┘
```

Todo ocurre en la misma red y en el mismo estado, asi que no hay que confiar en nadie: el ETH esta dentro del contrato y cualquiera puede verificarlo. Un **bridged** token, en cambio, siempre implica **dos redes** y un mecanismo (el bridge) que asegura que lo bloqueado en una coincide con lo emitido en la otra. Lo veras a fondo en el modulo 05.

#### La palabra "nativo" tiene dos significados

El ecosistema usa "nativo" para dos cosas distintas, y conviene separarlas:

1. **Activo nativo de la red**: el que lleva el protocolo y paga el gas (ETH en Arbitrum). No tiene contrato.
2. **Token de emision nativa**: un ERC-20 que el emisor acuna **directamente** en esa red, sin bridge. Por ejemplo, el "USDC nativo" de Arbitrum lo emite Circle en Arbitrum. Sigue siendo un ERC-20 (tiene contrato), pero no depende de un bridge.

#### Un token se identifica por (red, direccion), no por su simbolo

En Arbitrum One hay dos contratos distintos que dicen llamarse "USDC". Compruebalo tu mismo:

```bash
export ARB_RPC=https://arb1.arbitrum.io/rpc
export ETH_RPC=https://ethereum-rpc.publicnode.com

# USDC.e: version bridged (USDC bloqueado en Ethereum, representado en Arbitrum)
cast call 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8 "symbol()(string)" --rpc-url $ARB_RPC  # "USDC"
cast call 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8 "name()(string)"   --rpc-url $ARB_RPC  # "USD Coin (Arb1)"

# USDC nativo: emitido por Circle directamente en Arbitrum
cast call 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 "symbol()(string)" --rpc-url $ARB_RPC  # "USDC"
cast call 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 "name()(string)"   --rpc-url $ARB_RPC  # "USD Coin"

# El contrato del USDC nativo de Arbitrum... existe en Ethereum?
cast codesize 0xaf88d065e77c8cC2239327C5EDb3A432268e5831 --rpc-url $ETH_RPC                # 0 -> no existe
```

Mismo simbolo, dos contratos, dos emisores y dos modelos de riesgo. Y el contrato de Arbitrum no existe en Ethereum. Por eso las wallets y los protocolos identifican un token por el par **(chain ID, direccion del contrato)**, nunca por el simbolo, que cualquiera puede copiar.

#### Ejercicio rapido: envolver ETH en un fork de mainnet

Con Anvil puedes copiar el estado real de Ethereum y jugar con el WETH de verdad, sin gastar nada:

```bash
# Terminal 1: fork de Ethereum Mainnet (queda corriendo)
anvil --fork-url $ETH_RPC --port 8546

# Terminal 2
export FORK=http://127.0.0.1:8546
export WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2   # WETH en Ethereum Mainnet

# Wallet nueva (las cuentas por defecto de Anvil tienen codigo en mainnet, ver modulo 01 Paso 8)
cast wallet new                      # copia Address y Private key
export ME=0x...                      # Address
export KEY=0x...                     # Private key
cast rpc anvil_setBalance $ME $(cast to-wei 10) --rpc-url $FORK   # le damos 10 ETH en el fork

# 1. Envolver: el ETH pasa al contrato y recibes WETH
cast send $WETH "deposit()" --value 1ether --private-key $KEY --rpc-url $FORK
cast balance $ME --ether --rpc-url $FORK                             # ~9 ETH  (activo nativo)
cast call $WETH "balanceOf(address)(uint256)" $ME --rpc-url $FORK    # 1e18    (ERC-20 en el storage de WETH)

# 2. Desenvolver 0.4: se quema WETH y vuelve ETH nativo
cast send $WETH "withdraw(uint256)" $(cast to-wei 0.4) --private-key $KEY --rpc-url $FORK
cast call $WETH "balanceOf(address)(uint256)" $ME --rpc-url $FORK    # 6e17
```

Observa que usaste **dos comandos distintos** para ver cada saldo: `cast balance` le pregunta al protocolo y `balanceOf` le pregunta a un contrato. Esa es la diferencia entre un activo nativo y un token.

### 1. ERC-20: Token Fungible

ERC-20 es el estandar para tokens fungibles (cada unidad es igual a otra). Define una interfaz minima que todos los tokens deben implementar.

```
+-----------------------------------------------------------------+
|                        ERC-20 Interface                         |
+-----------------------------------------------------------------+
| FUNCIONES                          | EVENTS                     |
|------------------------------------|----------------------------|
| totalSupply() -> uint256           | Transfer(from, to, value)  |
| balanceOf(account) -> uint256      | Approval(owner, spender,   |
| transfer(to, amount) -> bool       |          value)            |
| allowance(owner, spender) -> uint256                            |
| approve(spender, amount) -> bool                                |
| transferFrom(from, to, amount) -> bool                          |
+-----------------------------------------------------------------+
```

#### Storage interno tipico

```solidity
mapping(address => uint256) private _balances;
mapping(address => mapping(address => uint256)) private _allowances;
uint256 private _totalSupply;
string private _name;
string private _symbol;
```

#### Flujo de transfer directo

```
Alice.transfer(Bob, 100)

_balances[Alice] -= 100
_balances[Bob]   += 100
emit Transfer(Alice, Bob, 100)
```

#### Flujo de approve + transferFrom

Este patron permite que un tercero (ej. un DEX) mueva tokens en nombre del owner:

```
Paso 1: Alice.approve(DEX, 500)
        _allowances[Alice][DEX] = 500
        emit Approval(Alice, DEX, 500)

Paso 2: DEX.transferFrom(Alice, Pool, 200)
        require(_allowances[Alice][DEX] >= 200)
        _balances[Alice]        -= 200
        _balances[Pool]         += 200
        _allowances[Alice][DEX] -= 200
        emit Transfer(Alice, Pool, 200)
```

```
  Alice                    DEX Contract               Pool
    |                          |                        |
    |--- approve(DEX, 500) --->|                        |
    |                          |                        |
    |   (Alice interactua      |                        |
    |    con el DEX)           |                        |
    |                          |                        |
    |                          |--- transferFrom ------>|
    |                          |    (Alice, Pool, 200)  |
    |                          |                        |
    |  _allowances[A][DEX]     |                        |
    |  500 -> 300              |                        |
```

### 2. ERC-721: Non-Fungible Token (NFT)

Cada token tiene un `tokenId` unico. Funciones clave:

```
ownerOf(tokenId) -> address
safeTransferFrom(from, to, tokenId)
approve(to, tokenId)
setApprovalForAll(operator, approved)
```

El concepto clave es que cada `tokenId` apunta a exactamente un `owner`, a diferencia de ERC-20 donde los tokens son intercambiables.

### 3. ERC-1155: Multi-Token

Combina fungibles y no-fungibles en un solo contrato:

```
balanceOf(account, id) -> uint256
balanceOfBatch(accounts, ids) -> uint256[]
safeTransferFrom(from, to, id, amount, data)
safeBatchTransferFrom(from, to, ids, amounts, data)
```

Ventaja: una sola transaccion puede transferir multiples tipos de tokens.

### 4. Vesting

Vesting es el mecanismo por el cual tokens se liberan gradualmente a un beneficiario:

```
Tokens
  ^
  |                          _______________
  |                         /
  |                        /
  |                       /
  |  (bloqueados)        /  (vesting lineal)
  |                     /
  |____________________/
  |     cliff          |
  +--------------------+--------------------> Tiempo
  startTime     startTime+cliff    startTime+duration
```

- **cliff**: periodo inicial donde no se libera nada
- **duration**: tiempo total del vesting
- **Vesting lineal**: despues del cliff, los tokens se liberan proporcionalmente al tiempo transcurrido

Formula de tokens liberados:

```
Si (now < startTime + cliff):
    vestedAmount = 0

Si (now >= startTime + duration):
    vestedAmount = totalAmount

Si no:
    vestedAmount = totalAmount * (now - startTime) / duration

claimable = vestedAmount - alreadyReleased
```

---

## Ejercicio practico: VestingToken

### Descripcion

Implementa un token ERC-20 desde cero (sin imports de OpenZeppelin) con un sistema de vesting integrado.

### Funcionalidades ERC-20

- `name()`, `symbol()`, `decimals()`
- `totalSupply()`, `balanceOf(account)`
- `transfer(to, amount)`, `approve(spender, amount)`
- `transferFrom(from, to, amount)`, `allowance(owner, spender)`

### Funcionalidades de Vesting

- `createVesting(beneficiary, totalAmount, startTime, duration, cliffDuration)` - solo owner
- `release(beneficiary)` - el beneficiario reclama tokens liberados
- `vestedAmount(beneficiary)` - cuanto se ha liberado en total (vested)
- `releasableAmount(beneficiary)` - cuanto puede reclamar ahora

### Archivos

- `contracts/VestingToken.sol` - ERC-20 + vesting
- `test/VestingToken.t.sol` - tests completos

---

## Vulnerabilidades relevantes

### 1. Allowance Front-Running

```
Situacion: Alice aprobo al DEX por 100 tokens.
Ahora quiere cambiar la allowance a 50.

1. Alice envia tx: approve(DEX, 50)
2. El DEX ve la tx pendiente en mempool
3. El DEX front-runs: transferFrom(Alice, X, 100)  <- usa la allowance vieja
4. Se mina el approve(DEX, 50)
5. El DEX usa: transferFrom(Alice, X, 50)          <- usa la nueva allowance

Resultado: el DEX gasto 150 en vez de 50.
```

**Mitigacion**: usar `increaseAllowance/decreaseAllowance` o primero setear a 0.

### 2. Missing Return Value Check

Algunos tokens (como USDT) no retornan `bool` en `transfer()`. Si tu contrato asume que siempre retorna `true`, puede fallar silenciosamente.

```solidity
// VULNERABLE: asume que transfer retorna bool
bool success = IERC20(token).transfer(to, amount);

// CORRECTO: usar SafeERC20 de OpenZeppelin o verificar con low-level call
// SafeERC20.safeTransfer(IERC20(token), to, amount);
```

### 3. Unlimited Allowance

Muchos frontends piden `approve(spender, type(uint256).max)` por "conveniencia". Si el spender (contrato) es comprometido, puede drenar todos los tokens.

### 4. Fee-on-Transfer Tokens

Algunos tokens cobran una comision en cada transfer. Si tu contrato asume que recibira exactamente `amount`, el balance real sera menor.

```solidity
// VULNERABLE: asume que recibira 100
token.transferFrom(user, address(this), 100);
deposited[user] += 100;  // pero el contrato recibio 99

// CORRECTO: medir el balance antes y despues
uint256 before = token.balanceOf(address(this));
token.transferFrom(user, address(this), 100);
uint256 actual = token.balanceOf(address(this)) - before;
deposited[user] += actual;
```

### 5. Rebase Tokens

Tokens como stETH cambian los balances automaticamente (rebase). Si tu contrato almacena un `balanceOf` y lo usa despues, el valor puede haber cambiado.

---

## Recursos

- [EIP-20: Token Standard](https://eips.ethereum.org/EIPS/eip-20)
- [EIP-721: Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [EIP-1155: Multi Token Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [OpenZeppelin ERC20 Implementation](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol)
- [Weird ERC20 Tokens](https://github.com/d-xo/weird-erc20) - catalogo de tokens con comportamiento inesperado
- [Token Allowance Front-Running](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit)

---

## Checkpoint

Antes de avanzar al Modulo 03, verifica que puedes:

- [ ] Explicar la diferencia entre activo nativo, ERC-20, wrapped token y bridged token, con un ejemplo de cada uno
- [ ] Explicar por que WETH no implica confiar en un bridge y USDC.e si
- [ ] Explicar por que un token se identifica por (chain ID, direccion) y no por su simbolo
- [ ] Envolver y desenvolver ETH en un fork de mainnet usando `cast`
- [ ] Escribir la interfaz ERC-20 de memoria (6 funciones + 2 events)
- [ ] Explicar el flujo `approve` + `transferFrom` y para que sirve
- [ ] Describir la vulnerabilidad de allowance front-running
- [ ] Explicar que es un fee-on-transfer token y por que es problematico
- [ ] Diferenciar entre ERC-20, ERC-721 y ERC-1155
- [ ] Tu VestingToken compila y todos los tests pasan
- [ ] Puedes explicar la formula de vesting lineal con cliff
- [ ] Entiendes por que se implementa desde cero (sin OZ) para aprendizaje
