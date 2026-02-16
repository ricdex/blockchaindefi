# Security Architecture

Seguridad sistémica para sistemas blockchain: threat modeling, auditorías, defensa en profundidad e incident response.

---

## 1. Objetivo

Al completar este módulo serás capaz de:

- Aplicar threat modeling (STRIDE adaptado) a smart contracts y protocolos DeFi
- Describir el proceso completo de una auditoría de seguridad
- Diseñar defensa en profundidad a nivel de código, protocolo y operaciones
- Crear un incident response playbook para un protocolo DeFi
- Analizar post-mortems de hacks reales y extraer lecciones aplicables
- Realizar un threat model completo para un protocolo hipotético

---

## 2. Prerequisitos

- Módulos 01, 02 y 03 completados
- Solidity básico: entender storage, calls, reentrancy
- Conocimiento de patrones de seguridad comunes (checks-effects-interactions)
- Familiaridad con al menos 2-3 hacks DeFi a nivel de noticias

---

## 3. Conceptos clave

### 3.1 Threat Modeling para Smart Contracts

El framework STRIDE, adaptado al contexto de blockchain:

| Categoría STRIDE        | Adaptación Blockchain                                  | Ejemplo                                    |
|-------------------------|--------------------------------------------------------|--------------------------------------------|
| **S**poofing            | Suplantación de identidad (msg.sender)                 | Falta de verificación de caller            |
| **T**ampering           | Manipulación de estado                                 | Reentrancy, flash loan manipulation        |
| **R**epudiation         | Falta de trazabilidad                                  | No emitir events en operaciones críticas   |
| **I**nformation Discl.  | Exposición de información                              | MEV: transacciones visibles en mempool     |
| **D**enial of Service   | Interrupción del servicio                              | Gas griefing, unbounded loops              |
| **E**levation of Priv.  | Escalación de privilegios                              | Access control bypass, proxy storage collision |

#### Attack Surfaces

```
  +----------------------------------------------------------+
  |                    ATTACK SURFACES                        |
  |                                                          |
  |  +------------------+  +------------------+              |
  |  | Contract Code    |  | Oracle           |              |
  |  | - reentrancy     |  | Dependencies     |              |
  |  | - overflow       |  | - price manip    |              |
  |  | - logic bugs     |  | - stale data     |              |
  |  | - access control |  | - oracle failure |              |
  |  +------------------+  +------------------+              |
  |                                                          |
  |  +------------------+  +------------------+              |
  |  | Governance       |  | Bridges          |              |
  |  | - flash loan     |  | - signature      |              |
  |  |   voting         |  |   verification   |              |
  |  | - low quorum     |  | - message replay |              |
  |  |   takeover       |  | - validator      |              |
  |  | - malicious      |  |   compromise     |              |
  |  |   proposals      |  |                  |              |
  |  +------------------+  +------------------+              |
  |                                                          |
  |  +------------------+                                    |
  |  | Admin Keys       |                                    |
  |  | - compromised    |                                    |
  |  |   private key    |                                    |
  |  | - insider threat |                                    |
  |  | - social eng.    |                                    |
  |  +------------------+                                    |
  +----------------------------------------------------------+
```

---

### 3.2 Audit Process

#### Fases de una auditoría

```
  +----------+     +----------+     +----------+     +----------+
  | Scoping  |---->|  Manual  |---->|  Tools   |---->|  Report  |
  |          |     |  Review  |     |          |     |          |
  +----------+     +----------+     +----------+     +----------+
   1-2 días         1-3 semanas      Paralelo         2-5 días
```

**1. Scoping:**
- Definir qué contratos se auditan
- Entender la arquitectura y los invariantes esperados
- Identificar dependencias externas
- Estimar esfuerzo (líneas de código, complejidad)

**2. Manual Review:**
- Lectura línea por línea del código
- Verificar business logic contra la documentación
- Buscar patrones de vulnerabilidad conocidos
- Analizar flujos de datos y control de acceso
- Verificar invariantes

**3. Automated Tools:**
- Static analysis: Slither, Mythril
- Fuzzing: Echidna, Foundry fuzzing
- Formal verification: Certora, Halmos
- Symbolic execution: Manticore

**4. Report:**
- Findings clasificados por severidad
- Código afectado con referencias
- Impacto detallado
- Recomendación de fix

#### Qué buscan los auditores

| Categoría         | Vulnerabilidades específicas                                    |
|-------------------|-----------------------------------------------------------------|
| Business logic    | Invariantes rotos, edge cases, incorrect assumptions            |
| Access control    | Missing `onlyOwner`, incorrect role checks, open initializers   |
| Reentrancy        | External calls before state updates, cross-function reentrancy  |
| Oracle            | Price manipulation, stale prices, decimal mismatches            |
| Precision loss    | Rounding errors, division before multiplication                 |
| Gas optimization  | Unbounded loops, expensive storage operations                   |
| Composability     | Flash loan interactions, sandwich attacks                       |
| Upgrade safety    | Storage collision, uninitialized proxy                          |

#### Formato del Report

```
  [S-01] Critical: Reentrancy in withdraw()

  Severity: Critical
  Status: Confirmed

  Description:
    La función withdraw() realiza una transferencia de ETH antes
    de actualizar el balance del usuario, permitiendo reentrancy.

  Impact:
    Un atacante puede drenar todos los fondos del contrato.

  Affected Code:
    src/Vault.sol#L45-L52

  Recommendation:
    Aplicar el patrón Checks-Effects-Interactions.
    Actualizar el balance ANTES de la transferencia.
    Considerar usar ReentrancyGuard de OpenZeppelin.
```

Severidades:
- **Critical**: pérdida directa de fondos, cualquier usuario puede explotar
- **High**: pérdida de fondos bajo condiciones específicas, o bypass de seguridad mayor
- **Medium**: funcionalidad incorrecta, pérdida menor, requiere condiciones específicas
- **Low**: best practices no seguidas, issues menores
- **Informational**: sugerencias de mejora, gas optimizations

---

### 3.3 Defense Layers

#### Defensa en profundidad para DeFi

```
  +============================================================+
  |                    CAPA 1: CÓDIGO                           |
  |  CEI pattern | OpenZeppelin | SafeMath | Access Control     |
  |  Formal verification | Comprehensive tests | Fuzzing        |
  +============================================================+
               |
  +============================================================+
  |                    CAPA 2: PROTOCOLO                         |
  |  Rate limits | Circuit breakers | Timelocks | Caps          |
  |  Oracle redundancy | Gradual rollout | Isolation modes      |
  +============================================================+
               |
  +============================================================+
  |                    CAPA 3: OPERACIONAL                       |
  |  Monitoring 24/7 | Alertas on-chain | Bug bounties          |
  |  Incident response plan | War room procedures               |
  |  Multisig operations | Hardware wallets                     |
  +============================================================+
               |
  +============================================================+
  |                    CAPA 4: ECONÓMICA                         |
  |  Insurance (Nexus Mutual) | Treasury reserves               |
  |  Gradual TVL growth | Risk parameters conservadores         |
  +============================================================+
```

#### Capa 1: Code Level

**CEI Pattern (Checks-Effects-Interactions):**
```
  1. CHECKS:  require(balance >= amount)     // validar
  2. EFFECTS: balance -= amount              // actualizar estado
  3. INTERACTIONS: token.transfer(to, amount) // interacción externa
```

**OpenZeppelin**: librería estándar auditada para:
- Access control (Ownable, AccessControl, roles)
- ReentrancyGuard
- Pausable
- SafeERC20 (manejo de tokens con comportamiento no estándar)

**Formal Verification**:
- Demostrar matemáticamente que el código cumple las especificaciones
- Herramientas: Certora Prover, Halmos, KEVM
- Costoso pero valioso para contratos de alto valor

#### Capa 2: Protocol Level

| Mecanismo          | Descripción                                           | Cuándo activar                      |
|--------------------|-------------------------------------------------------|-------------------------------------|
| Rate limits        | Limitar el monto por operación o por periodo          | Siempre activo                      |
| Circuit breakers   | Pausar operaciones si se detecta anomalía             | Movimiento de precio > X% en Y min  |
| Timelocks          | Delay entre propuesta y ejecución de cambios          | Governance y admin actions           |
| Withdrawal caps    | Limitar cuánto se puede sacar en un periodo           | Siempre activo                      |
| Isolation modes    | Nuevos assets con límites restrictivos                | Listing de nuevos assets             |

#### Capa 3: Operational

**Monitoring esencial:**
- TVL changes > X% en periodo corto
- Anomalías en transacciones (montos inusuales)
- Oracle price deviations
- Contract balance changes
- Governance proposals sospechosas

**Bug Bounties:**
- Plataformas: Immunefi, HackerOne, Code4rena
- Premios proporcionales al impacto (hasta millones para critical)
- Must: alcance claro, reglas de responsible disclosure, pago rápido

---

### 3.4 Incident Response Playbook

#### Fases

```
  +----------+     +----------+     +----------+     +----------+
  | Detect   |---->| Respond  |---->| Recover  |---->|  Post-   |
  |          |     |          |     |          |     | Mortem   |
  +----------+     +----------+     +----------+     +----------+
   Min 0-5          Min 5-60         Horas-Días       Día 1-7
```

**1. Detection (0-5 minutos):**
- Alertas automáticas: monitoreo on-chain (Forta, OpenZeppelin Defender, custom)
- Reportes de la comunidad: Twitter, Discord, bug bounty submissions
- Anomalías en dashboards: TVL drop, unusual gas spikes

**2. Response (5-60 minutos):**
- Activar canal de war room (Signal/Telegram/Discord privado)
- Si hay pause mechanism: **pausar inmediatamente** (no esperar a entender todo)
- Assessment inicial: qué contratos están afectados, cuánto está en riesgo
- Contactar: auditors, white-hat hackers, legal
- Comunicación pública: acknowledge el issue, no dar detalles técnicos aún

**3. Recovery (horas a días):**
- Desarrollar y auditar el fix
- Si es upgradeable: deploy fix via governance/multisig
- Si es immutable: deploy nueva versión + plan de migración
- Si se perdieron fondos: evaluar compensación (treasury, insurance, new token)
- Unpause con monitoring intensificado

**4. Post-Mortem (1-7 días):**
- Root cause analysis detallado
- Timeline del incidente
- Qué funcionó y qué no en la respuesta
- Acciones correctivas para prevenir recurrencia
- Publicar post-mortem transparente

---

### 3.5 Emergency Mechanisms

| Mecanismo            | Descripción                                           | Controlado por        |
|----------------------|-------------------------------------------------------|-----------------------|
| Pause                | Detener todas las operaciones del protocolo           | Guardian multisig     |
| Partial pause        | Detener solo ciertas funciones (e.g., borrows)        | Guardian multisig     |
| Guardian multisig    | Grupo de firmantes confiables para emergencias        | 3/5 o 4/7 multisig   |
| Governance override  | Governance puede overridear decisiones del guardian   | Token holders vote    |
| Timelock bypass      | Para emergencias, bypass del delay normal             | Guardian + conditions |

**Principio**: el guardian puede pausar pero NO puede cambiar parámetros o mover fondos. Eso requiere governance.

---

## 4. Análisis de hacks reales (Post-Mortems)

### 4.1 The DAO (2016) - $60M

**Qué pasó:**
- The DAO era un fondo de inversión descentralizado en Ethereum
- La función `splitDAO()` enviaba ETH antes de actualizar el balance
- Un atacante explotó reentrancy para drenar ~3.6M ETH

**Root cause:** violación del patrón CEI (Checks-Effects-Interactions). La interacción externa (envío de ETH) se realizaba antes de actualizar el estado.

**Impacto:** hard fork de Ethereum (ETH vs ETC). Cambió para siempre cómo se escribe Solidity.

**Lección:** siempre actualizar estado antes de interacciones externas. Usar reentrancy guards.

### 4.2 Wormhole Bridge (2022) - $320M

**Qué pasó:**
- Wormhole es un bridge cross-chain
- El atacante bypaseó la verificación de firmas de los guardians
- Minteó 120,000 wETH en Solana sin depositar ETH en Ethereum

**Root cause:** una función de verificación de firmas usaba un deprecated system program address que no validaba correctamente. El atacante forjó una firma válida.

**Impacto:** $320M perdidos. Jump Crypto (backer) repuso los fondos.

**Lección:** los bridges son el eslabón más débil. La verificación de firmas es crítica y debe ser exhaustivamente testeada. Deprecated code es peligroso.

### 4.3 Euler Finance (2023) - $197M

**Qué pasó:**
- Euler era un lending protocol en Ethereum
- El atacante usó flash loans para crear una posición de deuda artificial
- Luego "donó" los fondos a la reserva del protocolo, haciendo su posición liquidable de forma ventajosa
- La función de donación no tenía health check adecuado

**Root cause:** la función `donateToReserves()` permitía a un usuario empeorar su propia posición de salud sin verificación, creando una posición que podía ser self-liquidada con profit.

**Impacto:** $197M. La mayoría fue recuperada después de negociaciones con el atacante (whitehat bounty).

**Lección:** toda función que modifique una posición debe verificar el health factor post-operación. Las funciones "inofensivas" (como donar) pueden ser weaponized.

### 4.4 Curve Finance (2023) - $70M

**Qué pasó:**
- Varios pools de Curve fueron drenados
- La causa fue un bug en el compilador de Vyper (versiones 0.2.15, 0.2.16, 0.3.0)
- El bug causaba que el reentrancy guard no funcionara correctamente

**Root cause:** bug en el compilador del lenguaje de programación, no en el código fuente del protocolo. El reentrancy lock se almacenaba en un slot incorrecto debido a un bug en la gestión de storage del compilador.

**Impacto:** ~$70M. Parcialmente recuperado por MEV bots white-hat que front-rannearon al atacante.

**Lección:** la seguridad no termina en el código fuente. El compilador, las dependencias y toda la toolchain son attack surface. Diversificar: no usar versiones de compilador sin testing extensivo.

### Resumen comparativo

| Hack          | Año  | Monto  | Root Cause                        | Lección principal                    |
|---------------|------|--------|-----------------------------------|--------------------------------------|
| The DAO       | 2016 | $60M   | Reentrancy (CEI violation)        | Siempre estado antes de calls        |
| Wormhole      | 2022 | $320M  | Signature verification bypass     | Bridges son high-risk, audit bridges |
| Euler         | 2023 | $197M  | Missing health check en donate    | Toda mutación necesita health check  |
| Curve/Vyper   | 2023 | $70M   | Compiler bug (reentrancy guard)   | Toolchain es attack surface          |

---

## 5. Ejercicio de diseño

### Threat Model para un protocolo DeFi hipotético

**Protocolo**: "SecureLend" - Un lending protocol con stablecoin nativo (similar a MakerDAO + Aave).

**Funcionalidades:**
- Depositar collateral (ETH, WBTC, stETH)
- Mintear stablecoin (sUSD) contra collateral
- Liquidación de posiciones unhealthy
- Stability pool para liquidaciones
- Governance token (SLND) con ve-model

**Tarea**: Realizar un threat model completo.

#### A. Assets (qué proteger)
- Fondos depositados como collateral
- Stablecoin peg
- Governance integrity
- Protocol solvency

#### B. Threat Actors
- Atacantes externos (hackers)
- Insiders (team con admin keys)
- MEV searchers
- Governance attackers (acumular tokens)
- Oracle manipulators

#### C. Attack Vectors (para cada actor)
Identificar al menos 3 vectores por actor, incluyendo:
- Precondiciones necesarias
- Pasos del ataque
- Impacto estimado

#### D. Impact Matrix

| Vector de ataque        | Probabilidad | Impacto   | Riesgo    |
|-------------------------|-------------|-----------|-----------|
| (completar)             | Alta/Med/Baja| Crítico/Alto/Med/Bajo | (PxI) |

#### E. Mitigations
Para cada riesgo Alto o Crítico:
- Mitigación técnica específica
- Capa de defensa donde se implementa
- Costo de implementación
- Riesgo residual

**Formato**: documento estructurado con diagramas y matrices.

---

## 6. Trade-offs y decisiones

| Decisión                         | Opción A                      | Opción B                       | Consideración                         |
|----------------------------------|-------------------------------|--------------------------------|---------------------------------------|
| Upgradeability                   | Proxy upgradeable             | Immutable                      | Flexibilidad ante bugs vs confianza   |
| Admin keys                       | Multisig con timelock         | Sin admin (immutable)          | Capacidad de respuesta vs trustless   |
| Auditoría                        | 1 audit firm                  | Múltiples + contest            | Costo vs cobertura                    |
| Bug bounty scope                 | Solo critical                 | Todos los niveles              | Costo vs descubrimiento temprano      |
| Pause mechanism                  | Pause global                  | Pause granular                 | Simplicidad vs disponibilidad parcial |
| Oracle                           | Single source                 | Multi-source + fallback        | Simplicidad vs robustez               |
| Rate limits                      | Conservadores                 | Permisivos                     | Seguridad vs UX/capital efficiency    |
| Incident response                | Automated pause               | Human-triggered pause          | Velocidad vs false positives          |

---

## 7. Recursos

### Herramientas de seguridad
- [Slither](https://github.com/crytic/slither) - Static analyzer para Solidity
- [Echidna](https://github.com/crytic/echidna) - Fuzzer para smart contracts
- [Certora Prover](https://www.certora.com/) - Formal verification
- [Foundry](https://book.getfoundry.sh/) - Framework con fuzzing integrado
- [OpenZeppelin Defender](https://www.openzeppelin.com/defender) - Monitoring y automation

### Post-mortems y análisis
- [Rekt News](https://rekt.news/) - Cobertura de hacks DeFi
- [DeFi Hacks DB](https://defihacksdb.com/) - Base de datos de exploits
- [Immunefi Blog](https://immunefi.com/blog/) - Análisis técnicos de vulnerabilidades
- [Trail of Bits Blog](https://blog.trailofbits.com/) - Investigaciones de seguridad

### Papers y guías
- [SWC Registry](https://swcregistry.io/) - Smart Contract Weakness Classification
- [Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [OpenZeppelin Security Audits](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/audits)
- [Secureum Bootcamp](https://secureum.substack.com/) - Material educativo de seguridad

### Talks
- [Samczsun - Ethereum is a Dark Forest](https://www.youtube.com/watch?v=Wd0at2Pu6xY)
- [How to Audit Smart Contracts](https://www.youtube.com/watch?v=TmZ8gH-toX0) - Patrick Collins
- [Trail of Bits - Building Secure Smart Contracts](https://www.youtube.com/watch?v=lCKxRH7FRYA)

### Bug Bounty Platforms
- [Immunefi](https://immunefi.com/) - Bug bounties DeFi
- [Code4rena](https://code4rena.com/) - Competitive audits
- [Sherlock](https://www.sherlock.xyz/) - Audit contests + coverage

---

## 8. Checkpoint

Antes de avanzar al siguiente módulo, verifica que puedes:

- [ ] Aplicar STRIDE adaptado a un smart contract e identificar al menos 2 amenazas por categoría
- [ ] Describir las 4 fases de una auditoría de seguridad
- [ ] Clasificar findings por severidad (Critical/High/Medium/Low) con criterios claros
- [ ] Nombrar y describir al menos 3 herramientas de seguridad (Slither, Echidna, Certora)
- [ ] Diseñar defensa en profundidad con al menos 3 capas concretas
- [ ] Crear un incident response playbook con tiempos de respuesta definidos
- [ ] Explicar los 4 hacks reales analizados: qué pasó, root cause, lección
- [ ] Argumentar cuándo usar pause global vs granular
- [ ] Diseñar un sistema de monitoring con al menos 5 alertas específicas
- [ ] Completar el threat model del ejercicio de diseño
- [ ] Explicar por qué el bug de Vyper/Curve demuestra que el toolchain es attack surface
