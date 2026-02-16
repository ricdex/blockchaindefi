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

### Paso 0: Inicializar el proyecto Foundry

Si el proyecto no tiene `foundry.toml` ni `lib/` (estado limpio), inicializa desde cero:

```bash
cd developer/01-solidity-fundamentals

# Respaldar el README antes de forge init (lo sobreescribe)
cp README.md README.md.bak

# Inicializar Foundry
forge init --no-git --force

# Restaurar README y limpiar archivos template
mv README.md.bak README.md
rm -rf src/ script/
rm -f test/Counter.t.sol

# Instalar forge-std (dependencia de testing)
git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std
rm -rf lib/forge-std/.git
```

Luego edita `foundry.toml` para apuntar a `contracts/` en lugar de `src/`:

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
```

> Si el proyecto ya tiene `foundry.toml` y `lib/forge-std`, puedes saltarte este paso.

### Paso 1: Compilar

```bash
forge build
```

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

Anvil muestra 10 cuentas pre-fondeadas con 10000 ETH cada una, numeradas del 0 al 9:

```
Available Accounts (output de anvil)
==================
(0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266  (10000.000 ETH)
(1) 0x70997970C51812dc3A010C7d01b50e0d17dc79C8  (10000.000 ETH)
(2) 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC  (10000.000 ETH)
(3) 0x90F79bf6EB2c4f870365E785982E1f101E93b906  (10000.000 ETH)
...
(9) 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199  (10000.000 ETH)

Private Keys
==================
(0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
(1) 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
(2) 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
...
```

> Estas cuentas y keys son **siempre las mismas** en Anvil (son deterministicas).
> Son cuentas de prueba — nunca usar estas keys en redes reales.

Para este ejercicio usamos las cuentas asi:

```
Cuenta 0 → OWNER1   (owner de la MultiSig + quien despliega el contrato)
Cuenta 1 → OWNER2   (owner de la MultiSig)
Cuenta 2 → OWNER3   (owner de la MultiSig)
Cuenta 9 → RECEIVER (destinatario de prueba, no es owner)
```

Usamos la cuenta 9 como destinatario para que sea una cuenta separada de los owners
y sea facil distinguir los roles en el ejercicio.

**Terminal 2: Configurar variables y desplegar**

```bash
# Cuentas de Anvil que usaremos como owners de la MultiSig (cuentas 0, 1, 2)
export OWNER1_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export OWNER2_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export OWNER3_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

export OWNER1=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export OWNER2=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
export OWNER3=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

# Cuenta 9 de Anvil como destinatario de prueba (no es owner)
export RECEIVER=0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199

export RPC=http://localhost:8545
```

**Desplegar: 3 owners, 2 confirmaciones requeridas**

```bash
forge create contracts/MultiSigWallet.sol:MultiSigWallet \
  --rpc-url $RPC \
  --private-key $OWNER1_KEY \
  --broadcast \
  --constructor-args "[$OWNER1,$OWNER2,$OWNER3]" 2
```

Desglose del comando:

```
forge create contracts/MultiSigWallet.sol:MultiSigWallet
│            │                            │
│            │                            └─ Nombre del contrato (contract MultiSigWallet, linea 6)
│            └─ Ruta al archivo .sol
└─ Comando de Foundry para desplegar contratos

  --rpc-url $RPC              Nodo destino (Anvil en localhost:8545)
  --private-key $OWNER1_KEY   Cuenta que paga el gas del deploy
  --broadcast                 Envia la transaccion a la red (sin esto, solo simula)

  --constructor-args "[$OWNER1,$OWNER2,$OWNER3]" 2
                     │                           │
                     │                           └─ _required = 2 (linea 78: uint256 _required)
                     └─ _owners = array de 3 addresses (linea 78: address[] memory _owners)
```

Esto ejecuta el constructor (lineas 78-94 de MultiSigWallet.sol):
1. Valida que hay al menos 1 owner y que `_required` es valido (lineas 79-82)
2. Registra cada owner en el mapping `isOwner` y el array `owners` (lineas 84-91)
3. Guarda `required = 2` como quorum minimo (linea 93)

Output esperado:

```
No files changed, compilation skipped
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266    <- cuenta que desplego (OWNER1)
Deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3   <- direccion del contrato (USAR ESTA)
Transaction hash: 0x8421b4...                              <- hash de la tx de deploy
```

> **Importante**: sin `--broadcast` el comando solo simula y NO despliega. Si ves
> `Warning: To broadcast this transaction, add --broadcast`, agrega la flag.

Del output, copiar la direccion de `Deployed to:` y exportarla:

```bash
export MULTISIG=0x5FbDB2315678afecb367f032d93F642f64180aa3
```

> **Nota**: `MULTISIG` es la direccion **del contrato**, no de una cuenta de usuario.
> La MultiSig es un smart contract que actua como wallet: recibe, guarda y envia fondos
> segun las reglas de quorum definidas en el constructor.

**Verificar que el contrato esta desplegado:**

```bash
cast call $MULTISIG "getTransactionCount()(uint256)" --rpc-url $RPC
# Debe retornar: 0
```

> Si da error `does not have any code`, significa que Anvil fue reiniciado y la direccion ya no tiene contrato. Soluciones:
> 1. Verificar que Anvil sigue corriendo en la otra terminal
> 2. Redesplegar el contrato con `forge create` de nuevo
> 3. Actualizar la variable `$MULTISIG` con la nueva direccion

**Fondear el contrato con ETH:**

> **Concepto clave: Balance intrinseco en Ethereum**
>
> En Ethereum, **toda direccion** (sea cuenta de usuario EOA o contrato) tiene un balance de ETH.
> Este balance NO es una variable dentro del contrato — vive en el **state trie** de Ethereum,
> una estructura de datos a nivel de protocolo que la EVM mantiene automaticamente.
>
> ```
> State trie de Ethereum:
> ┌──────────────────────────────────┬──────────────┐
> │ Direccion                        │ Balance      │
> ├──────────────────────────────────┼──────────────┤
> │ 0xf39F... (OWNER1 - EOA)        │ 10000 ETH   │
> │ 0x7099... (OWNER2 - EOA)        │ 10000 ETH   │
> │ 0x5FbD... (MULTISIG - contrato) │ 0 ETH       │  <- empieza en 0
> └──────────────────────────────────┴──────────────┘
> ```
>
> El contrato MultiSig empieza con **0 ETH**. Para que pueda enviar fondos a otros,
> primero alguien debe transferirle ETH. El contrato puede recibirlo gracias a:
>
> ```solidity
> receive() external payable {}   // permite que el contrato reciba ETH
> ```
>
> Despues de fondear con 5 ETH:
>
> ```
> │ 0xf39F... (OWNER1)             │ 9995 ETH    │  <- -5 ETH
> │ 0x5FbD... (MULTISIG)           │ 5 ETH       │  <- +5 ETH
> ```
>
> Cuando los owners aprueban y ejecutan una transaccion, **el contrato envia
> ETH desde su propio balance** — los owners solo firman, no ponen fondos:
>
> ```solidity
> // En execute() - el contrato envia ETH al destinatario
> (bool success, ) = tx.to.call{value: tx.value}(tx.data);
> //                              ^^^^^^^^
> //                              sale del balance del contrato
> ```
>
> Es como una caja fuerte compartida: primero le metes dinero,
> y despues necesitas N de M llaves para autorizar cada retiro.

```bash
cast send $MULTISIG --value 5ether --private-key $OWNER1_KEY --rpc-url $RPC

# Verificar balance del contrato
cast balance $MULTISIG --rpc-url $RPC
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
# submit(address to, uint256 value, bytes data)
cast send $MULTISIG "submit(address,uint256,bytes)" \
  $RECEIVER \
  1000000000000000000 \
  0x00 \
  --private-key $OWNER1_KEY \
  --rpc-url $RPC
```

> **Nota**: usamos `0x00` en lugar de `0x` para bytes vacios. `cast` necesita al menos
> un byte para reconocerlo como argumento valido de tipo `bytes`.

Desglose del comando:

```
cast send $MULTISIG "submit(address,uint256,bytes)" $RECEIVER 1000000000000000000 0x00
│         │          │                               │         │                  │
│         │          │                               │         │                  └─ _data = 0x00 (vacio, sin calldata)
│         │          │                               │         └─ _value = 1 ETH en wei
│         │          │                               └─ _to = direccion del destinatario
│         │          └─ Firma de la funcion (linea 111-114 de MultiSigWallet.sol)
│         └─ Direccion del contrato MultiSig
└─ Comando de Foundry para enviar una transaccion (modifica estado)

  --private-key $OWNER1_KEY   Cuenta que firma y paga gas (debe ser owner, linea 115: onlyOwner)
  --rpc-url $RPC              Nodo destino (Anvil)
```

> **`cast send` vs `cast call`**:
> - `cast send` = transaccion real, modifica estado, cuesta gas
> - `cast call` = lectura, no modifica nada, no cuesta gas

Que pasa internamente al ejecutar este comando:

```
1. cast codifica los argumentos en ABI y envia la transaccion al contrato
2. La EVM ejecuta submit() (linea 111):
   a. Modifier onlyOwner (linea 53): verifica que OWNER1 esta en isOwner mapping
   b. Crea un struct Transaction (linea 118-126):
      Transaction {
          to:            RECEIVER           (linea 38: struct campo to)
          value:         1000000000000000000 (linea 39: struct campo value)
          data:          0x                  (linea 40: struct campo data)
          executed:      false               (linea 41: aun no se ejecuta)
          confirmations: 0                   (linea 42: nadie ha confirmado)
      }
   c. Lo agrega al array transactions[] (linea 46) con txId = 0
   d. Emite evento TransactionSubmitted (linea 128)
```

Verificar:

```bash
# getTransactionCount() -> debe ser 1
cast call $MULTISIG "getTransactionCount()(uint256)" --rpc-url $RPC

# getTransaction(0) -> detalle de txId=0
cast call $MULTISIG "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0 --rpc-url $RPC
# (RECEIVER, 1000000000000000000, 0x, false, 0)
#  to        value                data  executed  confirmations
```

**2. Confirm: Owner1 confirma**

```bash
cast send $MULTISIG "confirm(uint256)" 0 --private-key $OWNER1_KEY --rpc-url $RPC
```

Desglose del comando:

```
cast send $MULTISIG "confirm(uint256)" 0
│         │          │                  │
│         │          │                  └─ _txId = 0 (la transaccion que propuso Owner1)
│         │          └─ Firma de la funcion (linea 133 de MultiSigWallet.sol)
│         └─ Direccion del contrato
└─ Envia transaccion

  --private-key $OWNER1_KEY   Quien confirma (debe ser owner y no haber confirmado ya)
```

Que pasa internamente:

```
1. La EVM ejecuta confirm(0) (linea 133):
   a. Modifier onlyOwner (linea 53): verifica que es owner
   b. Modifier txExists (linea 57): verifica que txId=0 existe en transactions[]
   c. Modifier notExecuted (linea 62): verifica que executed == false
   d. Modifier notConfirmed (linea 67): verifica que confirmed[0][OWNER1] == false
   e. Incrementa confirmations de 0 a 1 (linea 137)
   f. Marca confirmed[0][OWNER1] = true (linea 138)
   g. Emite evento TransactionConfirmed (linea 140)
```

**3. Confirm: Owner2 confirma (se alcanza quorum: 2/3)**

```bash
cast send $MULTISIG "confirm(uint256)" 0 --private-key $OWNER2_KEY --rpc-url $RPC
```

> Mismo flujo que arriba pero con OWNER2. Ahora confirmations = 2 (>= required).

Verificar confirmaciones:

```bash
cast call $MULTISIG "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0 --rpc-url $RPC
# Ultimo campo (confirmations) ahora es 2
```

**4. Execute: Owner3 ejecuta**

```bash
# Balance del receiver ANTES
cast balance $RECEIVER --rpc-url $RPC

# Ejecutar
cast send $MULTISIG "execute(uint256)" 0 --private-key $OWNER3_KEY --rpc-url $RPC

# Balance del receiver DESPUES (deberia tener +1 ETH)
cast balance $RECEIVER --rpc-url $RPC
```

Desglose del comando:

```
cast send $MULTISIG "execute(uint256)" 0
│         │          │                  │
│         │          │                  └─ _txId = 0
│         │          └─ Firma de la funcion (linea 145 de MultiSigWallet.sol)
│         └─ Direccion del contrato
└─ Envia transaccion

  --private-key $OWNER3_KEY   Quien ejecuta (cualquier owner puede, si hay quorum)
```

Que pasa internamente:

```
1. La EVM ejecuta execute(0) (linea 145):
   a. Modifiers: onlyOwner, txExists, notExecuted (mismas validaciones)
   b. Verifica quorum (linea 150): confirmations(2) >= required(2) -> OK
   c. Marca executed = true (linea 154)
   d. Transfiere ETH (linea 156):
      txn.to.call{value: txn.value}(txn.data)
      │         │                    │
      │         │                    └─ data = 0x (sin calldata adicional)
      │         └─ value = 1 ETH (sale del balance del CONTRATO)
      └─ to = RECEIVER
   e. Si la transferencia falla, revierte (linea 157)
   f. Emite evento TransactionExecuted (linea 159)

Estado despues:
  MULTISIG balance: 5 ETH - 1 ETH = 4 ETH
  RECEIVER balance: 10000 ETH + 1 ETH = 10001 ETH
```

**5. Verificar que quedo ejecutada**

```bash
cast call $MULTISIG "getTransaction(uint256)(address,uint256,bytes,bool,uint256)" 0 --rpc-url $RPC
# El campo "executed" ahora es true
```

### Paso 6: Experimentar con revocacion

```bash
# Owner1 propone segunda transaccion (txId=1)
cast send $MULTISIG "submit(address,uint256,bytes)" \
  $RECEIVER 500000000000000000 0x00 \
  --private-key $OWNER1_KEY --rpc-url $RPC

# Owner1 y Owner2 confirman
cast send $MULTISIG "confirm(uint256)" 1 --private-key $OWNER1_KEY --rpc-url $RPC
cast send $MULTISIG "confirm(uint256)" 1 --private-key $OWNER2_KEY --rpc-url $RPC

# Owner1 se arrepiente y revoca
cast send $MULTISIG "revoke(uint256)" 1 --private-key $OWNER1_KEY --rpc-url $RPC

# Intentar ejecutar -> FALLA (solo 1 confirmacion, se necesitan 2)
cast send $MULTISIG "execute(uint256)" 1 --private-key $OWNER3_KEY --rpc-url $RPC
# REVERT: NotEnoughConfirmations(1, 1, 2)
```

### Paso 7: Probar access control

```bash
# Cuenta que NO es owner intenta submit -> FALLA
export NON_OWNER_KEY=0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a

cast send $MULTISIG "submit(address,uint256,bytes)" \
  $RECEIVER 1000000000000000000 0x00 \
  --private-key $NON_OWNER_KEY --rpc-url $RPC
# REVERT: NotOwner(0x...)
```

### Troubleshooting

| Error | Causa | Solucion |
|-------|-------|----------|
| `does not have any code` | Anvil fue reiniciado o la direccion es incorrecta | Redesplegar con `forge create` y actualizar `$MULTISIG` |
| `NotOwner` | La private key no corresponde a un owner | Usar `OWNER1_KEY`, `OWNER2_KEY` o `OWNER3_KEY` |
| `NotEnoughConfirmations` | Faltan confirmaciones | Necesitas >= 2 confirms antes de `execute` |
| `TxAlreadyExecuted` | La transaccion ya fue ejecutada | Proponer una nueva transaccion con `submit` |
| `TxAlreadyConfirmed` | Este owner ya confirmo esta tx | Cada owner solo puede confirmar una vez |

### Como leer errores de cast send

Cuando una transaccion va a fallar, `cast send` **no la envia**. Primero simula la
transaccion para estimar el gas, y si la simulacion revierte, muestra el error sin
gastar gas. Ejemplo:

```
Error: Failed to estimate gas: server returned an error response:
  error code 3: execution reverted:
  custom error 0x9d8c9bc8:
  0000000000000000000000000000000000000000000000000000000000000000
  000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266,
  data: "0x9d8c9bc8..."
  TxAlreadyConfirmed(0, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
```

Se lee asi:

```
Failed to estimate gas       ← cast simula antes de enviar; si revierte, no envia
                                (no es un error de gas, es que la tx va a fallar)

execution reverted           ← la EVM hizo revert al simular

custom error 0x9d8c9bc8      ← selector del error: primeros 4 bytes del keccak256
                                de la firma del error
                                keccak256("TxAlreadyConfirmed(uint256,address)")
                                = 0x9d8c9bc8...

data: "0x9d8c9bc8..."        ← argumentos del error codificados en ABI
                                txId = 0
                                address = 0xf39F...

TxAlreadyConfirmed(0, 0xf39F...)  ← Foundry decodifica el error automaticamente
                                     porque tiene el ABI del contrato compilado
```

> Los custom errors (definidos en lineas 19-29 del contrato) son mas baratos en gas
> que strings (`require(cond, "mensaje")`) y Foundry los decodifica automaticamente.
> Si ves un error con selector hex que Foundry no decodifica, puedes buscarlo manualmente:
>
> ```bash
> cast 4byte 0x9d8c9bc8
> # TxAlreadyConfirmed(uint256,address)
> ```

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
