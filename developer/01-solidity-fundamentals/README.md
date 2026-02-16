# Modulo 01: Solidity Fundamentals

## Objetivo

Al completar este modulo seras capaz de:

- Entender el sistema de tipos de Solidity y como se almacenan en storage
- Escribir contratos con funciones, modifiers, events y manejo de errores
- Comprender las diferencias entre storage, memory y calldata
- Implementar patrones de access control basicos
- Identificar vulnerabilidades comunes en contratos simples
- Construir una MultiSig Wallet funcional y testeada

---

## Prerequisitos

- Conocimientos basicos de programacion (variables, funciones, loops)
- Entendimiento conceptual de blockchain y Ethereum (que es una transaccion, que es gas, que es una address)
- Foundry instalado (`forge`, `cast`, `anvil`)
- Editor con soporte Solidity (VS Code + extension Solidity)

---

## Conceptos clave

### 1. Sistema de tipos

Solidity es un lenguaje **statically typed**. Los tipos mas importantes son:

```
Tipo          Tamano        Ejemplo
-----------   -----------   ----------------------------
uint256       32 bytes      uint256 balance = 100;
uint8         1 byte        uint8 decimals = 18;
int256        32 bytes      int256 delta = -50;
bool          1 byte        bool active = true;
address       20 bytes      address owner = msg.sender;
bytes32       32 bytes      bytes32 hash = keccak256(...);
bytes         dinamico      bytes data = hex"cafe";
string        dinamico      string name = "Token";
```

#### Mappings

```solidity
// key => value (no iterable, no length)
mapping(address => uint256) public balances;
mapping(address => mapping(address => bool)) public approved;
```

#### Arrays

```solidity
uint256[] public dynamicArray;     // tamano variable
uint256[10] public fixedArray;     // tamano fijo, 10 elementos
```

#### Structs y Enums

```solidity
struct Proposal {
    address proposer;
    uint256 votes;
    bool executed;
}

enum Status { Pending, Active, Closed }
```

### 2. Storage Layout

La EVM almacena estado en **slots** de 32 bytes. Entender esto es critico para optimizacion de gas y para evitar bugs con `delegatecall`.

```
+--------+----------------------------------+
| Slot 0 | uint256 totalSupply              |  32 bytes completos
+--------+----------------------------------+
| Slot 1 | address owner (20B) + bool (1B)  |  empaquetados en 1 slot
+--------+----------------------------------+
| Slot 2 | uint256[] length                 |  los datos estan en keccak256(2)
+--------+----------------------------------+
| Slot 3 | mapping base                     |  valor en keccak256(key . 3)
+--------+----------------------------------+
```

**Reglas de empaquetamiento (packing):**
- Variables consecutivas que caben en 32 bytes se empaquetan en el mismo slot
- `mapping` y `dynamic array` siempre usan un slot nuevo
- El orden de declaracion importa para el gas

```
// MAL - 3 slots (desperdicio)          // BIEN - 2 slots (empaquetado)
uint128 a;   // slot 0 (16B)           uint128 a;   // slot 0 (16B)
uint256 b;   // slot 1 (32B)           uint128 c;   // slot 0 (16B) <- empaquetado
uint128 c;   // slot 2 (16B)           uint256 b;   // slot 1 (32B)
```

### 3. Storage vs Memory vs Calldata

```
+-----------+------------------+-------------------+--------------------+
| Ubicacion | Persistencia     | Costo             | Uso tipico         |
+-----------+------------------+-------------------+--------------------+
| storage   | permanente       | alto (SSTORE)     | estado del contrato|
| memory    | durante llamada  | medio             | vars temporales    |
| calldata  | solo lectura     | bajo              | params de funciones|
+-----------+------------------+-------------------+--------------------+
```

```solidity
function process(string calldata input) external {   // calldata: read-only, barato
    string memory temp = string.concat(input, "!");   // memory: temporal, modificable
    storedValue = temp;                                // storage: persistente, caro
}
```

### 4. Funciones: Visibility y Mutability

```
Visibility:
+----------+-------------------+------------------+------------------+
|          | Desde el contrato | Contratos hijos  | Externo          |
+----------+-------------------+------------------+------------------+
| public   |       SI          |       SI         |       SI         |
| external |       NO*         |       NO         |       SI         |
| internal |       SI          |       SI         |       NO         |
| private  |       SI          |       NO         |       NO         |
+----------+-------------------+------------------+------------------+
* external se puede llamar internamente con this.func() pero es mas caro

Mutability:
+----------+------------------------------------------+
| view     | Lee storage pero no modifica             |
| pure     | No lee ni modifica storage               |
| payable  | Puede recibir ETH                        |
| (none)   | Puede leer y modificar storage            |
+----------+------------------------------------------+
```

### 5. Modifiers

Los modifiers permiten agregar precondiciones reutilizables:

```solidity
modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;   // <- aqui se ejecuta el cuerpo de la funcion
}

modifier nonReentrant() {
    require(!locked, "Reentrant call");
    locked = true;
    _;
    locked = false;
}
```

### 6. Events

Los events son logs que se almacenan en la blockchain pero **no son accesibles desde contratos**. Son baratos y utiles para indexar off-chain.

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
//                       ^indexed = filtrable en logs (max 3 indexed por event)

emit Transfer(msg.sender, recipient, amount);
```

### 7. Error Handling

```solidity
// require: validacion de input / precondiciones
require(amount > 0, "Amount must be > 0");

// revert: para logica mas compleja
if (balance < amount) revert InsufficientBalance(balance, amount);

// Custom errors (mas baratos en gas que strings)
error InsufficientBalance(uint256 available, uint256 required);
error Unauthorized(address caller);
```

### 8. receive() y fallback()

```
                     msg.data esta vacio?
                        /            \
                      SI              NO
                      /                \
               receive()            fallback()
               existe?               existe?
               /     \               /     \
             SI       NO           SI       NO
             /         \           /         \
         receive()   fallback()  fallback()  REVERT
                     existe?
                     /     \
                   SI       NO
                   /         \
               fallback()  REVERT
```

```solidity
receive() external payable {
    // Se ejecuta cuando el contrato recibe ETH sin data
}

fallback() external payable {
    // Se ejecuta cuando se llama una funcion que no existe
    // o cuando se envia ETH con data y no hay receive
}
```

---

## Ejercicio practico: MultiSig Wallet

### Descripcion

Implementa una billetera multifirma (MultiSig) que requiere M de N confirmaciones de owners para ejecutar transacciones.

### Arquitectura

```
  Owner A ──submit(to, value, data)──> MultiSigWallet
                                            |
  Owner B ──confirm(txId)──────────────>    |
                                            |
  Owner C ──confirm(txId)──────────────>    |
                                            |
           required = 2 de 3                |
                                            |
  Owner A ──execute(txId)──────────────> [txn.to].call{value}(data)
```

### Funcionalidades

1. **Constructor**: recibe lista de owners y numero minimo de confirmaciones
2. **receive()**: permite recibir ETH, emite `Deposit`
3. **submit()**: un owner propone una transaccion
4. **confirm()**: un owner confirma una transaccion pendiente
5. **execute()**: si hay suficientes confirmaciones, ejecuta la transaccion
6. **revoke()**: un owner revoca su confirmacion

### Archivos

- `contracts/MultiSigWallet.sol` - contrato principal
- `test/MultiSigWallet.t.sol` - tests con Foundry

---

## Como ejecutar

### Paso 1: Compilar

Desde el directorio del modulo:

```bash
cd developer/01-solidity-fundamentals
forge build
```

> El proyecto ya esta configurado con `foundry.toml` (src = `contracts/`, test = `test/`, libs en `lib/`). No necesitas correr `forge init`.

### Paso 2: Ejecutar tests

```bash
# Todos los tests
forge test

# Con output detallado (nombre de cada test + resultado)
forge test -vv

# Con traces completos (util para debuggear fallos)
forge test -vvvv

# Un test especifico
forge test --match-test test_fullFlow_submitConfirmExecute -vvv

# Solo los tests del contrato MultiSigWallet
forge test --match-contract MultiSigWalletTest
```

Salida esperada con `-vv`:

```
Ran 31 tests for test/MultiSigWallet.t.sol:MultiSigWalletTest
[PASS] test_confirm_emitsEvent()
[PASS] test_confirm_incrementsConfirmations()
[PASS] test_confirm_revertsForNonOwner()
...
[PASS] test_fullFlow_submitConfirmExecute()
[PASS] test_multipleTransactions()

Suite result: ok. 31 passed; 0 failed; 0 skipped
```

### Paso 3: Ver cobertura

```bash
forge coverage
```

### Paso 4: Interactuar en vivo con Anvil + cast

Los tests de Foundry (`forge test`) ejecutan todo en una EVM en memoria que se destruye al terminar. Para interactuar paso a paso como si fuera una blockchain real, usamos **Anvil** (nodo local) + **cast** (cliente de linea de comandos).

> **Importante**: Anvil es efimero. Si lo reinicias, pierdes todos los contratos desplegados y debes repetir desde el deploy.

**Terminal 1: Levantar Anvil (dejar corriendo)**

```bash
anvil
```

Anvil muestra 10 cuentas pre-fondeadas con 10000 ETH cada una. Anotar las direcciones y private keys.

**Terminal 2: Configurar variables y desplegar**

```bash
# Private keys de las cuentas de Anvil (cuentas 0, 1, 2)
export OWNER1_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export OWNER2_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export OWNER3_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

# Direcciones correspondientes
export OWNER1=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export OWNER2=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
export OWNER3=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

export RPC=http://localhost:8545
```

**Desplegar: 3 owners, 2 confirmaciones requeridas**

```bash
forge create contracts/MultiSigWallet.sol:MultiSigWallet \
  --rpc-url $RPC \
  --private-key $OWNER1_KEY \
  --constructor-args "[$OWNER1,$OWNER2,$OWNER3]" 2
```

Del output, copiar la direccion de `Deployed to:` y exportarla:

```bash
# Reemplazar con la direccion real del output
export WALLET=0x5FbDB2315678afecb367f032d93F642f64180aa3
```

**Verificar que el contrato esta desplegado:**

```bash
cast call $WALLET "getTransactionCount()(uint256)" --rpc-url $RPC
# Debe retornar: 0
```

> Si da error `does not have any code`, significa que Anvil fue reiniciado y la direccion ya no tiene contrato. Soluciones:
> 1. Verificar que Anvil sigue corriendo en la otra terminal
> 2. Redesplegar el contrato con `forge create` de nuevo
> 3. Actualizar la variable `$WALLET` con la nueva direccion

**Fondear la wallet con ETH:**

```bash
cast send $WALLET --value 5ether --private-key $OWNER1_KEY --rpc-url $RPC

# Verificar balance
cast balance $WALLET --rpc-url $RPC
# 5000000000000000000 (5 ETH en wei)
```

### Paso 5: Flujo completo paso a paso

```
FLUJO:

  1. Owner1 propone enviar 1 ETH        submit()
  2. Owner1 confirma                     confirm(0)
  3. Owner2 confirma (2/3 = quorum)      confirm(0)
  4. Owner3 ejecuta                      execute(0)
  5. Destinatario recibe 1 ETH
```

**1. Submit: Owner1 propone enviar 1 ETH**

```bash
# Cuenta 9 de Anvil como destinatario
export RECEIVER=0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199

# submit(address to, uint256 value, bytes data)
cast send $WALLET "submit(address,uint256,bytes)" \
  $RECEIVER \
  1000000000000000000 \
  0x \
  --private-key $OWNER1_KEY \
  --rpc-url $RPC
```

Verificar:

```bash
# getTransactionCount() -> debe ser 1
cast call $WALLET "getTransactionCount()(uint256)" --rpc-url $RPC

# getTransaction(0) -> detalle de txId=0
cast call $WALLET "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0 --rpc-url $RPC
# (RECEIVER, 1000000000000000000, 0x, false, 0)
#  to        value                data  executed  confirmations
```

**2. Confirm: Owner1 confirma**

```bash
cast send $WALLET "confirm(uint256)" 0 --private-key $OWNER1_KEY --rpc-url $RPC
```

**3. Confirm: Owner2 confirma (se alcanza quorum: 2/3)**

```bash
cast send $WALLET "confirm(uint256)" 0 --private-key $OWNER2_KEY --rpc-url $RPC
```

Verificar confirmaciones:

```bash
cast call $WALLET "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0 --rpc-url $RPC
# Ultimo campo (confirmations) ahora es 2
```

**4. Execute: Owner3 ejecuta**

```bash
# Balance del receiver ANTES
cast balance $RECEIVER --rpc-url $RPC

# Ejecutar
cast send $WALLET "execute(uint256)" 0 --private-key $OWNER3_KEY --rpc-url $RPC

# Balance del receiver DESPUES (deberia tener +1 ETH)
cast balance $RECEIVER --rpc-url $RPC
```

**5. Verificar que quedo ejecutada**

```bash
cast call $WALLET "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0 --rpc-url $RPC
# El campo "executed" ahora es true
```

### Paso 6: Experimentar con revocacion

```bash
# Owner1 propone segunda transaccion (txId=1)
cast send $WALLET "submit(address,uint256,bytes)" \
  $RECEIVER 500000000000000000 0x \
  --private-key $OWNER1_KEY --rpc-url $RPC

# Owner1 y Owner2 confirman
cast send $WALLET "confirm(uint256)" 1 --private-key $OWNER1_KEY --rpc-url $RPC
cast send $WALLET "confirm(uint256)" 1 --private-key $OWNER2_KEY --rpc-url $RPC

# Owner1 se arrepiente y revoca
cast send $WALLET "revoke(uint256)" 1 --private-key $OWNER1_KEY --rpc-url $RPC

# Intentar ejecutar -> FALLA (solo 1 confirmacion, se necesitan 2)
cast send $WALLET "execute(uint256)" 1 --private-key $OWNER3_KEY --rpc-url $RPC
# REVERT: NotEnoughConfirmations(1, 1, 2)
```

### Paso 7: Probar access control

```bash
# Cuenta que NO es owner intenta submit -> FALLA
export NON_OWNER_KEY=0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a

cast send $WALLET "submit(address,uint256,bytes)" \
  $RECEIVER 1000000000000000000 0x \
  --private-key $NON_OWNER_KEY --rpc-url $RPC
# REVERT: NotOwner(0x...)
```

### Troubleshooting

| Error | Causa | Solucion |
|-------|-------|----------|
| `does not have any code` | Anvil fue reiniciado o la direccion es incorrecta | Redesplegar con `forge create` y actualizar `$WALLET` |
| `NotOwner` | La private key no corresponde a un owner | Usar `OWNER1_KEY`, `OWNER2_KEY` o `OWNER3_KEY` |
| `NotEnoughConfirmations` | Faltan confirmaciones | Necesitas >= 2 confirms antes de `execute` |
| `TxAlreadyExecuted` | La transaccion ya fue ejecutada | Proponer una nueva transaccion con `submit` |
| `TxAlreadyConfirmed` | Este owner ya confirmo esta tx | Cada owner solo puede confirmar una vez |

### Resumen de comandos

```
forge build                    Compilar contratos
forge test -vv                 Ejecutar todos los tests
forge test -vvvv               Tests con traces (debug)
forge coverage                 Ver cobertura
anvil                          Levantar nodo local
forge create ...               Desplegar contrato en Anvil
cast send ...                  Enviar transaccion (modifica estado)
cast call ...                  Leer estado (sin gas, sin transaccion)
cast balance ...               Ver balance ETH de una cuenta
```

---

## Vulnerabilidades relevantes

### 1. Unchecked External Calls

```solidity
// VULNERABLE: no verifica si la llamada fallo
payable(to).transfer(amount);  // solo 2300 gas, puede fallar silenciosamente

// CORRECTO: verificar el resultado
(bool success, ) = to.call{value: amount}("");
require(success, "Transfer failed");
```

### 2. Missing Access Control

```solidity
// VULNERABLE: cualquiera puede llamar
function withdraw(uint256 amount) external {
    payable(msg.sender).transfer(amount);
}

// CORRECTO: solo el owner
function withdraw(uint256 amount) external onlyOwner {
    payable(msg.sender).transfer(amount);
}
```

### 3. tx.origin vs msg.sender

```
User A ──tx──> Malicious Contract ──call──> Your Contract
                                            msg.sender = Malicious Contract
                                            tx.origin  = User A

// VULNERABLE: un contrato malicioso puede hacer phishing
require(tx.origin == owner);   // NUNCA usar tx.origin para auth

// CORRECTO:
require(msg.sender == owner);  // msg.sender es quien llama directamente
```

### 4. Integer Overflow/Underflow

Desde Solidity 0.8.0 los overflows hacen revert automaticamente. Pero en versiones anteriores o con `unchecked {}`:

```solidity
// En 0.8+, esto revierte automaticamente:
uint8 x = 255;
x += 1;  // REVERT

// Pero dentro de unchecked, NO revierte:
unchecked {
    uint8 x = 255;
    x += 1;  // x == 0, overflow silencioso
}
```

---

## Recursos

- [Solidity Documentation](https://docs.soliditylang.org/en/v0.8.20/)
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity by Example](https://solidity-by-example.org/)
- [Understanding Ethereum Storage](https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html)
- [SWC Registry - Smart Contract Weakness Classification](https://swcregistry.io/)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

---

## Checkpoint

Antes de avanzar al Modulo 02, verifica que puedes:

- [ ] Explicar la diferencia entre `storage`, `memory` y `calldata`
- [ ] Describir como funciona el storage layout (slots de 32 bytes, packing)
- [ ] Escribir un contrato con `modifier`, `event` y custom errors
- [ ] Explicar por que `tx.origin` no debe usarse para autenticacion
- [ ] Describir el flujo de `receive()` vs `fallback()`
- [ ] Tu MultiSig Wallet compila sin errores (`forge build`)
- [ ] Todos los tests pasan con `forge test` (31 tests)
- [ ] Puedes desplegar en Anvil e interactuar con `cast`
- [ ] Puedes explicar el flujo: submit -> confirm -> execute
- [ ] Puedes explicar cada linea del contrato MultiSig
