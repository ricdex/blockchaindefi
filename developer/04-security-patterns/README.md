# Modulo 04: Security Patterns

## Objetivo

Aprender a identificar, explotar y corregir las vulnerabilidades mas comunes en smart contracts de Solidity.
Al finalizar este modulo seras capaz de:

- Reconocer patrones de **reentrancy** y aplicar el patron **Checks-Effects-Interactions (CEI)**
- Entender **integer overflow/underflow** en contextos pre y post Solidity 0.8
- Implementar **access control** robusto y evitar el pitfall de `tx.origin`
- Comprender la mecanica de **flash loan attacks**, **front-running** y **sandwich attacks**
- Detectar **storage collisions** en patrones proxy con `delegatecall`
- Aplicar patrones **pull payment** para evitar **Denial of Service (DoS)**
- Usar herramientas de analisis estatico: **Slither** y **Mythril**

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (tipos, funciones, modifiers, storage)
- Modulo 02: Tokens and Standards (ERC-20, ERC-721)
- Modulo 03: DeFi Primitives (vaults, lending basico)
- Conocimiento basico de Foundry (`forge build`, `forge test`)

---

## Conceptos clave

### 1. Reentrancy

Ocurre cuando un contrato externo vuelve a llamar al contrato original antes de que este
termine de ejecutar su logica. El caso clasico: el contrato envia ETH y luego actualiza el estado.

```
                Contrato Victima                    Contrato Atacante
               +-----------------+                +-----------------+
               |                 |  1. withdraw() |                 |
               |  balances[A]=1  |<---------------|   attack()      |
               |                 |                |                 |
               |  2. send ETH   |--------------->|   receive() {   |
               |     a A         |                |     withdraw()  |
               |                 |<---------------|   }             |
               |  3. send ETH   |--------------->|   receive() {   |
               |     (otra vez!) |                |     withdraw()  |
               |                 |<---------------|   }             |
               |  ...            |                |   ...           |
               |                 |                |                 |
               |  4. balance = 0 |                |                 |
               |  (muy tarde!)   |                |                 |
               +-----------------+                +-----------------+
```

**Solucion: Patron CEI (Checks-Effects-Interactions)**

```
function withdraw() external {
    // 1. CHECKS: validar condiciones
    uint256 balance = balances[msg.sender];
    require(balance > 0, "No balance");

    // 2. EFFECTS: actualizar estado ANTES de la interaccion
    balances[msg.sender] = 0;

    // 3. INTERACTIONS: llamada externa al final
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Transfer failed");
}
```

Adicionalmente se puede usar un **ReentrancyGuard** (mutex lock):

```
bool private _locked;

modifier nonReentrant() {
    require(!_locked, "Reentrant call");
    _locked = true;
    _;
    _locked = false;
}
```

---

### 2. Integer Overflow / Underflow

**Pre Solidity 0.8**: los enteros hacian wrap-around silenciosamente.

```
uint8 x = 255;
x += 1;  // x == 0  (overflow silencioso)

uint8 y = 0;
y -= 1;  // y == 255 (underflow silencioso)
```

**Post Solidity 0.8**: el compilador revierte automaticamente en overflow/underflow.

**Excepcion**: bloques `unchecked {}` desactivan la verificacion (util para gas optimization,
pero peligroso si no se valida manualmente).

```solidity
unchecked {
    uint8 x = 255;
    x += 1; // x == 0, NO revierte
}
```

---

### 3. Access Control

```
  tx.origin vs msg.sender
  ========================

  Usuario (EOA) ----> Contrato Malicioso ----> Contrato Victima
       ^                                            |
       |                                            |
   tx.origin == Usuario                    msg.sender == Contrato Malicioso
                                           tx.origin == Usuario  <-- PELIGRO!
```

- `msg.sender`: el llamador directo (puede ser EOA o contrato)
- `tx.origin`: siempre la EOA que origino la transaccion

**Regla**: NUNCA usar `tx.origin` para autorizacion. Siempre usar `msg.sender`.

Patrones seguros:
- **Ownable**: un `owner` con funciones `onlyOwner`
- **Role-Based Access Control (RBAC)**: roles granulares (admin, minter, pauser)

---

### 4. Flash Loan Attacks

```
  +--------+     1. Pide prestamo      +-----------+
  |        |  (sin colateral)          |           |
  | Flash  |-------------------------->|  DeFi     |
  | Loan   |                           |  Protocol |
  | Pool   |     4. Devuelve           |           |
  |        |      prestamo + fee       |           |
  |        |<--------------------------|           |
  +--------+                           +-----------+
                                            |
                                     2. Manipula  3. Extrae
                                        precio     profit
                                            |         ^
                                            v         |
                                       +----------+
                                       |  AMM /   |
                                       |  Oracle  |
                                       +----------+
```

Un flash loan permite pedir prestado cualquier cantidad sin colateral,
siempre que se devuelva en la **misma transaccion**. Un atacante puede:
1. Pedir prestado una gran cantidad
2. Manipular un oracle o AMM con esa liquidez
3. Explotar un protocolo que depende de ese precio
4. Devolver el prestamo + fee

---

### 5. Front-running y Sandwich Attacks

**Front-running**: un atacante observa el mempool, ve una transaccion pendiente
y coloca su propia transaccion con mas gas para ejecutarse primero.

**Sandwich attack**:
```
  Mempool: [Victima: swap 100 ETH -> USDC]

  Atacante ve esto y:
  1. TX antes: compra USDC (sube precio)  -- mas gas
  2. TX victima: compra USDC (a precio inflado)
  3. TX despues: vende USDC (baja precio, profit)
```

**Mitigaciones**: deadlines, slippage limits, commit-reveal schemes, private mempools (Flashbots).

---

### 6. Storage Collision en Proxies (delegatecall)

```
  Proxy Contract                Implementation Contract
  +------------------+          +------------------+
  | slot 0: admin    |          | slot 0: owner    |  <-- COLISION!
  | slot 1: impl     |          | slot 1: balance  |  <-- COLISION!
  +------------------+          +------------------+
```

`delegatecall` ejecuta el codigo de otro contrato pero usa el storage del contrato que llama.
Si los layouts de storage no coinciden, se sobreescriben variables criticas.

**Solucion**: EIP-1967 (slots de storage predefinidos y aleatorios para el proxy).

---

### 7. Denial of Service (DoS) - Push vs Pull

**Push pattern (vulnerable)**:
```
// El contrato envia ETH a todos en un loop
for (uint i = 0; i < users.length; i++) {
    users[i].call{value: amounts[i]}("");  // si uno falla, TODOS fallan
}
```

**Pull pattern (seguro)**:
```
// Cada usuario retira su propio ETH
mapping(address => uint256) public pendingWithdrawals;

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    msg.sender.call{value: amount}("");
}
```

---

### 8. Herramientas de Analisis Estatico

**Slither** (Trail of Bits):
```bash
# Instalar
pip3 install slither-analyzer

# Ejecutar sobre un contrato
slither contracts/vulnerable/VulnerableVault.sol

# Solo detectores de alta severidad
slither contracts/ --filter-paths "test" --exclude-informational
```

**Mythril** (ConsenSys):
```bash
# Instalar
pip3 install mythril

# Analizar un contrato
myth analyze contracts/vulnerable/VulnerableVault.sol

# Con limite de profundidad
myth analyze contracts/vulnerable/VulnerableVault.sol --execution-timeout 90
```

---

## Ejercicio practico

### Enfoque CTF (Capture The Flag)

Para cada vulnerabilidad seguir este flujo:

1. **Estudiar** el contrato vulnerable (carpeta `contracts/vulnerable/`)
2. **Identificar** la vulnerabilidad
3. **Escribir un exploit** (ver `contracts/Attacker.sol`)
4. **Verificar** con tests que el exploit funciona (`test/`)
5. **Estudiar** la version segura (`contracts/secure/`)
6. **Verificar** con tests que el exploit ya no funciona

### Archivos del ejercicio

| Archivo | Descripcion |
|---------|-------------|
| `contracts/vulnerable/VulnerableVault.sol` | Vault con reentrancy |
| `contracts/vulnerable/VulnerableAccessControl.sol` | Access control con tx.origin |
| `contracts/vulnerable/VulnerableDOS.sol` | DoS por push payment |
| `contracts/secure/SecureVault.sol` | Vault con CEI + ReentrancyGuard |
| `contracts/secure/SecureAccessControl.sol` | Access control con msg.sender |
| `contracts/secure/SecurePullPayment.sol` | Pull payment pattern |
| `contracts/Attacker.sol` | Exploit de reentrancy |
| `test/ReentrancyAttack.t.sol` | Tests del exploit de reentrancy |
| `test/AccessControlAttack.t.sol` | Tests del exploit de tx.origin |
| `test/DOSAttack.t.sol` | Tests del exploit de DoS |

### Ejecutar tests

```bash
forge test --match-path test/ReentrancyAttack.t.sol -vvvv
forge test --match-path test/AccessControlAttack.t.sol -vvvv
forge test --match-path test/DOSAttack.t.sol -vvvv

# Todos los tests del modulo
forge test -vvv
```

---

## Vulnerabilidades relevantes

| Vulnerabilidad | Impacto | Ejemplo real |
|----------------|---------|--------------|
| Reentrancy | Robo total de fondos | The DAO Hack (2016) - $60M |
| Integer overflow | Creacion infinita de tokens | BEC Token (2018) |
| tx.origin phishing | Robo de fondos del owner | Multiples contratos custom |
| Flash loan + oracle manipulation | Drenaje de lending pools | bZx (2020), Harvest Finance |
| Front-running | Perdida de valor para usuarios | Generalizado en DEXs |
| Storage collision | Control total del proxy | Auditorias de Wormhole, varios |
| DoS push payment | Fondos bloqueados permanentemente | GovernMental Ponzi (2016) |

---

## Recursos

- [SWC Registry - Smart Contract Weakness Classification](https://swcregistry.io/)
- [Consensys - Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [OpenZeppelin - ReentrancyGuard](https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuard)
- [Trail of Bits - Slither](https://github.com/crytic/slither)
- [Mythril Documentation](https://mythril-classic.readthedocs.io/)
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) - CTF para practicar
- [Ethernaut by OpenZeppelin](https://ethernaut.openzeppelin.com/) - Wargame de seguridad
- [Rekt News](https://rekt.news/) - Postmortems de hacks reales
- [Secureum Bootcamp](https://secureum.substack.com/) - Material avanzado de seguridad
- [EIP-1967: Standard Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)

---

## Checkpoint

Antes de continuar al modulo 05, verifica que puedes:

- [ ] Explicar que es reentrancy y por que el patron CEI lo previene
- [ ] Implementar un `ReentrancyGuard` desde cero (sin OpenZeppelin)
- [ ] Describir la diferencia entre `tx.origin` y `msg.sender` con un diagrama
- [ ] Explicar como funciona un flash loan attack paso a paso
- [ ] Describir que es un sandwich attack y como mitigarlo
- [ ] Explicar por que `delegatecall` puede causar storage collisions
- [ ] Implementar el patron pull payment para evitar DoS
- [ ] Ejecutar Slither sobre un contrato y entender su output
- [ ] Pasar todos los tests del modulo: `forge test -vvv`
- [ ] Explotar exitosamente el VulnerableVault con el contrato Attacker
- [ ] Verificar que SecureVault resiste el mismo ataque
