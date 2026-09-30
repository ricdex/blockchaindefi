# Modulo 01: Solidity Fundamentals

## Objetivo

Al completar este modulo seras capaz de:

- Distinguir blockchain, EVM, Ethereum, ETH y tokens ERC-20, y explicar por que la misma direccion tiene balances distintos en cada red
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

### 0. Mapa mental: blockchain, EVM, Ethereum, ETH y tokens

Antes de escribir una linea de Solidity conviene separar cinco palabras que en el dia a dia se usan como sinonimos, pero que son cosas distintas. Casi todas las confusiones posteriores (L2, bridges, "por que no me llego el token") vienen de mezclarlas.

| Palabra | Que es realmente | Analogia | Pregunta que responde |
|---------|------------------|----------|-----------------------|
| **Blockchain** | Un *tipo de sistema*: un libro contable replicado en muchos nodos que se ponen de acuerdo (consenso) sobre el orden de las transacciones | Una base de datos compartida que nadie controla solo | Como se ponen de acuerdo? |
| **EVM** | Una *especificacion* de maquina virtual: como se ejecuta bytecode y como cambia el estado | x86 o la JVM: muchas maquinas distintas implementan la misma especificacion | Como se ejecuta el codigo? |
| **Ethereum Mainnet** | Una *red concreta*: sus nodos, su consenso (PoS), su chain ID (`1`) y **su propio estado** | Una computadora concreta, con su propio disco | Donde vive el estado? |
| **ETH** | El *activo nativo* de Ethereum: un numero en el campo `balance` de cada cuenta, que lleva el protocolo | El efectivo del sistema | Con que se paga el gas? |
| **Token ERC-20** | Un *smart contract* que guarda un `mapping(address => uint256)` en su storage | Una planilla dentro de un programa | Quien lleva la cuenta de este activo? |

La idea mas importante de la tabla: **la EVM es la especificacion, no la red**. Arbitrum, Base, BNB Chain, Polygon y Anvil ejecutan la misma EVM, pero cada una es otra "computadora" con **su propio disco** (su propio estado).

#### Donde vive el ETH y donde vive un token

```
Estado global de UNA red (ej: Ethereum Mainnet, chain ID 1)
┌──────────────────────────────────────────────────────────────────┐
│ Cuenta 0xAlice (EOA)                                             │
│   nonce:   7                                                     │
│   balance: 2.5 ETH           <── ETH nativo: lo lleva el PROTOCOLO│
│   code:    (vacio)                                               │
│                                                                  │
│ Cuenta 0xUSDC (contrato)                                         │
│   balance: 0 ETH                                                 │
│   code:    bytecode del ERC-20                                   │
│   storage:                                                       │
│     _balances[0xAlice] = 1000   <── token: lo lleva un CONTRATO  │
└──────────────────────────────────────────────────────────────────┘
```

Como se consulta cada uno:

```bash
# ETH de Alice: se le pregunta al protocolo (no hay contrato de por medio)
cast balance 0xAlice

# USDC de Alice: se le pregunta a UN contrato especifico
cast call 0xUSDC "balanceOf(address)(uint256)" 0xAlice
```

MetaMask hace exactamente esto por ti: para el ETH llama a `eth_getBalance`, y para cada token llama a `balanceOf` en el contrato que tenga registrado.

#### Por que ETH no necesita un smart contract

- El protocolo define que **toda cuenta tiene un campo `balance`**. Enviar ETH es una transaccion con `value`: la EVM resta de un lado y suma del otro, sin ejecutar codigo (si el destino es una EOA).
- El gas **tiene** que pagarse en el activo nativo. Piensalo como un huevo y la gallina: si el gas se pagara con un ERC-20, habria que ejecutar un contrato para cobrar... la ejecucion de contratos. El protocolo necesita un activo que pueda cobrar *antes* de ejecutar nada.
- Consecuencia practica: ETH no tiene `approve` ni `transferFrom`. Por eso existe **WETH** (lo vemos en el modulo 02).

#### "EVM-compatible" no significa "usa ETH"

Cada red elige su activo nativo, que es el que paga el gas:

| Red | Chain ID | Native gas token | Que es |
|-----|----------|------------------|--------|
| Ethereum Mainnet | 1 | ETH | L1 |
| Sepolia | 11155111 | SepoliaETH (sin valor) | Testnet de Ethereum |
| Arbitrum One | 42161 | ETH | L2 sobre Ethereum (modulo 05) |
| Base | 8453 | ETH | L2 sobre Ethereum |
| BNB Smart Chain | 56 | BNB | Blockchain independiente |
| Polygon PoS | 137 | POL | Cadena propia con checkpoints en Ethereum |
| Avalanche C-Chain | 43114 | AVAX | Blockchain independiente |
| Gnosis Chain | 100 | xDAI | Blockchain independiente |
| Anvil (local) | 31337 | "ETH" de juguete | Nodo en tu maquina |
| Besu (modulo 11) | El que definas en el genesis | Existe, pero el gas cuesta 0 (`--min-gas-price=0`) | Red privada |

Dos trampas frecuentes:

1. **El simbolo es solo una etiqueta.** Cuando agregas una red en MetaMask, *tu* escribes el "currency symbol". Que Arbitrum muestre "ETH" no significa que sea el mismo registro que el ETH de Ethereum: es un numero en el estado **de Arbitrum** (en el modulo 05 veras que esta respaldado por ETH bloqueado en Ethereum).
2. **Mismo codigo no significa misma red.** Un contrato desplegado en BNB Chain no sabe nada de Ethereum, aunque su bytecode sea identico.

#### Una direccion, muchas redes

Tu direccion se calcula **solo con matematica**, a partir de tu clave privada. En la formula no interviene ninguna red:

```
clave privada ──(secp256k1)──> clave publica ──(keccak256, ultimos 20 bytes)──> 0xf39F...2266
```

Por eso la misma direccion "existe" en todas las redes EVM a la vez. Lo que **no** se comparte es el estado: cada red tiene su propia fila para esa direccion.

```
                        0xf39F...2266   (misma direccion)
          ┌──────────────────┼───────────────────┬───────────────────┐
          ▼                  ▼                   ▼                   ▼
   Ethereum (1)       Arbitrum One (42161)   Sepolia (11155111)   Anvil (31337)
   balance: 0 ETH     balance: 0 ETH         balance: 0           balance: 10000 ETH
   nonce:   miles     nonce:   miles         nonce:   miles       nonce:   0
```

Tres consecuencias que debes poder explicar:

- **Balances distintos**: tener ETH en Ethereum no te da nada en Arbitrum. Para "llevarlo" hay que usar un bridge (modulo 05).
- **Nonces distintos**: cada red cuenta tus transacciones por separado.
- **Contratos distintos**: la direccion de un contrato se calcula con `keccak256(rlp(deployer, nonce))` usando el nonce **de esa red**. Un contrato existe solo en la red donde se desplego. Y en otra red, esa misma direccion puede estar vacia... o tener codigo de otra persona.

> Las firmas incluyen el chain ID (EIP-155). Por eso una transaccion firmada para Arbitrum no puede "reenviarse" en Ethereum: la firma no es valida alli.

En el **Paso 8** del ejercicio vas a comprobar todo esto con tus propios ojos.

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
> Ojo con el matiz: es el state trie **de esta red**. Anvil tiene el suyo, Ethereum Mainnet
> tiene el suyo y Arbitrum tiene el suyo. Los 10000 ETH de la cuenta 0 existen solo
> en el disco de tu Anvil (ver seccion 0 y Paso 8).
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

### Paso 8: Tu direccion en varias redes (sin gastar nada)

Hasta ahora todo paso dentro de Anvil. En este paso vas a comprobar la seccion 0: **una direccion es la misma en todas las redes EVM, pero cada red tiene su propio estado**. No necesitas faucet ni fondos: solo vas a *leer*.

#### 8.1 Con `cast`: la misma direccion en cuatro redes

Deja Anvil corriendo (con tu MultiSig desplegada) y agrega RPCs publicos de solo lectura:

```bash
export ME=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266     # cuenta 0 de Anvil
export ETH_RPC=https://ethereum-rpc.publicnode.com        # Ethereum Mainnet (L1)
export ARB_RPC=https://arb1.arbitrum.io/rpc               # Arbitrum One (L2)
export SEPOLIA_RPC=https://ethereum-sepolia-rpc.publicnode.com
```

**Pregunta 1: con que red estoy hablando?** El chain ID es la "identidad" de la red:

```bash
cast chain-id --rpc-url $RPC          # 31337    -> Anvil
cast chain-id --rpc-url $ETH_RPC      # 1        -> Ethereum Mainnet
cast chain-id --rpc-url $ARB_RPC      # 42161    -> Arbitrum One
cast chain-id --rpc-url $SEPOLIA_RPC  # 11155111 -> Sepolia
```

**Pregunta 2: la misma direccion tiene el mismo estado?**

```bash
for R in $RPC $ETH_RPC $ARB_RPC $SEPOLIA_RPC; do
  echo "chain $(cast chain-id --rpc-url $R) | balance $(cast balance $ME --ether --rpc-url $R) | nonce $(cast nonce $ME --rpc-url $R)"
done
```

Salida aproximada (los numeros de las redes publicas cambian con el tiempo):

```
chain 31337    | balance 9994.99...   | nonce 7       <- tu Anvil: lo que hiciste en este modulo
chain 1        | balance 0.0000...    | nonce 8288    <- Ethereum: miles de transacciones de otras personas
chain 42161    | balance 0.0000...    | nonce 15697   <- Arbitrum: otra historia distinta
chain 11155111 | balance 0.0000...    | nonce 47910   <- Sepolia: otra mas
```

Que esta pasando: la clave privada de la cuenta 0 de Anvil es **publica** (sale en la documentacion de Foundry). Miles de personas la usaron en redes reales, y cada red registro esa actividad **por separado**. Ademas hay bots que vacian al instante cualquier fondo que llegue a esa direccion.

> **Nunca envies fondos reales a las cuentas de Anvil.** Se pierden en segundos.

**Bonus: la misma direccion puede incluso tener codigo distinto en cada red**

```bash
cast code $ME --rpc-url $RPC       # 0x                     -> en tu Anvil es una EOA normal
cast code $ME --rpc-url $ETH_RPC   # 0xef0100...            -> en Ethereum tiene codigo!
```

El prefijo `0xef0100` es una delegacion EIP-7702: alguien con la clave publica "le instalo" codigo a esa cuenta en Ethereum (normalmente un bot que la vacia). En tu Anvil no paso nada de eso. Es la misma direccion, pero cada red tiene su estado, **incluido el codigo**.

**Pregunta 3: mi contrato existe en todas las redes?**

```bash
cast code $MULTISIG --rpc-url $RPC       # 0x6080604052...  -> bytecode: existe en Anvil
cast code $MULTISIG --rpc-url $ETH_RPC   # 0x               -> vacio: NO existe en Ethereum
cast code $MULTISIG --rpc-url $ARB_RPC   # 0x               -> vacio: NO existe en Arbitrum
```

Desplegar un contrato escribe su codigo en el estado **de una red**. Nada se copia a las demas.

#### 8.2 Con MetaMask: lo mismo, visto como usuario

1. Instala MetaMask y crea una cuenta **nueva y dedicada a pruebas** (nunca uses tu wallet personal para aprender).
2. Activa las redes de prueba: menu de redes → *Show test networks* → selecciona **Sepolia**.
3. Agrega **Arbitrum Sepolia** (desde [chainlist.org](https://chainlist.org/chain/421614) o a mano, en *Add network manually*):

   | Campo | Valor |
   |-------|-------|
   | Network name | Arbitrum Sepolia |
   | RPC URL | `https://sepolia-rollup.arbitrum.io/rpc` |
   | Chain ID | `421614` |
   | Currency symbol | `ETH` |
   | Block explorer | `https://sepolia.arbiscan.io` |

4. (Opcional) Agrega **Anvil**: RPC `http://127.0.0.1:8545`, chain ID `31337`, simbolo `ETH`.

Ahora observa, cambiando de red en el selector:

| Que observar | Que deberias ver | Que significa |
|--------------|------------------|---------------|
| La direccion `0x...` arriba | **No cambia** al cambiar de red | La direccion viene de tu clave, no de la red |
| El balance | Cambia segun la red (probablemente 0 en todas) | Cada red tiene su propio estado |
| El simbolo del gas | "SepoliaETH" en Sepolia, "ETH" en Arbitrum Sepolia | Es el native gas token **de esa red** |
| Tu direccion en [sepolia.etherscan.io](https://sepolia.etherscan.io) y en [sepolia.arbiscan.io](https://sepolia.arbiscan.io) | Dos exploradores distintos, dos historiales distintos | Cada red tiene su propio explorador porque tiene su propia cadena de bloques |

> **Experimento del simbolo**: al agregar una red a mano, prueba a poner `PATATA` como currency symbol. MetaMask te advertira, pero la red funciona igual. El simbolo es una etiqueta de *tu wallet*; lo que define la red es el **chain ID** y el **RPC**.

#### 8.3 Explicalo con tus palabras

Antes de seguir, responde sin mirar:

1. Si mandas 1 SepoliaETH a tu direccion, cuanto ETH ves en Arbitrum Sepolia? Por que?
2. Un amigo te dice: "mandame USDC a mi direccion, es la misma en todas las redes". Que le tienes que preguntar antes de enviar nada?
3. Por que `cast code $MULTISIG` devuelve bytecode en una red y `0x` en otra?

<details>
<summary>Respuestas</summary>

1. **Cero.** Sepolia y Arbitrum Sepolia son redes distintas, con estados distintos. Para tener ETH en Arbitrum Sepolia hay que hacer un bridge (lo haras en el modulo 05).
2. **En que red.** La direccion sirve en todas, pero el USDC de cada red es un contrato distinto. Si lo envias en una red que tu amigo no usa, el saldo queda en esa red (y si la direccion es un contrato, por ejemplo una multisig, puede que ni siquiera exista alli).
3. Porque el deploy escribio el codigo solo en el estado de Anvil. Cada red es un disco separado.

</details>

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
cast chain-id ...              Ver con que red estas hablando
cast nonce ...                 Ver cuantas txs envio una cuenta EN ESA RED
cast code ...                  Ver si una direccion tiene contrato EN ESA RED
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

- [ ] Explicar con tus palabras la diferencia entre blockchain, EVM, Ethereum Mainnet, ETH y un token ERC-20
- [ ] Explicar por que ETH no necesita un smart contract y por que el gas se paga en el activo nativo
- [ ] Nombrar dos redes EVM-compatibles que **no** usan ETH como gas
- [ ] Mostrar con `cast` que la misma direccion tiene balance y nonce distintos en Anvil, Ethereum y Arbitrum
- [ ] Explicar por que tu MultiSig existe en Anvil pero no en Ethereum Mainnet
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
