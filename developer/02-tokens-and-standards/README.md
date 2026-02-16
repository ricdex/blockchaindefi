# Modulo 02: Tokens and Standards

## Objetivo

Al completar este modulo seras capaz de:

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

- [ ] Escribir la interfaz ERC-20 de memoria (6 funciones + 2 events)
- [ ] Explicar el flujo `approve` + `transferFrom` y para que sirve
- [ ] Describir la vulnerabilidad de allowance front-running
- [ ] Explicar que es un fee-on-transfer token y por que es problematico
- [ ] Diferenciar entre ERC-20, ERC-721 y ERC-1155
- [ ] Tu VestingToken compila y todos los tests pasan
- [ ] Puedes explicar la formula de vesting lineal con cliff
- [ ] Entiendes por que se implementa desde cero (sin OZ) para aprendizaje
