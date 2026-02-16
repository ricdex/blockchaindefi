# Ruta Developer - Construir en Blockchain

Este path se enfoca en **escribir codigo**. Vas a construir smart contracts desde cero, testearlos con Foundry, y aprender seguridad rompiendo y arreglando codigo real. Cada modulo incluye contratos de ejemplo, tests y ejercicios practicos.

---

## Prerequisitos

- Experiencia programando en algun lenguaje (JavaScript, Python, Go, Rust, etc.)
- Comodidad con la linea de comandos y git
- Foundry instalado y funcionando (`forge`, `cast`, `anvil`) -- ver [shared/tooling.md](../shared/tooling.md)
- Editor con soporte Solidity (VS Code + extension Solidity recomendado)

---

## Roadmap Visual

```
                        RUTA DEVELOPER
                        ==============

  01 Solidity ────> 02 Tokens ────> 03 DeFi ────> 04 Security
       |                                               |
       └──────────────────> 05 Oracles ────────────────┘
                               |
       ┌───────────────────────┼───────────────────────┐
       |                       |                       |
  06 Stablecoins         07 Governance           08 Identity
       |                       |                       |
       └───────────────────────┼───────────────────────┘
                               |
                        09 Advanced DeFi
                               |
                        10 Real World Assets
                               |
                        11 Private Networks
                               |
                        12 AI Agents (ERC-8004)
```

Los modulos 01-04 forman el **core obligatorio**. A partir del modulo 05, los modulos 06, 07 y 08 pueden estudiarse en paralelo. Los modulos 09 y 10 requieren haber completado los anteriores. El modulo 11 (Private Networks) requiere Docker y puede estudiarse despues del modulo 02. El modulo 12 (AI Agents) requiere modulos 01, 02, 04 y 08.

---

## Tabla de Modulos

| # | Modulo | Que construyes | Esfuerzo estimado | Dificultad |
|---|--------|----------------|-------------------|------------|
| 01 | [Solidity Fundamentals](01-solidity-fundamentals/) | MultiSig Wallet, contratos con access control | ~12 horas | Basico |
| 02 | [Tokens and Standards](02-tokens-and-standards/) | ERC-20, ERC-721, ERC-1155, ERC-4626 vault token | ~10 horas | Basico |
| 03 | [DeFi Primitives](03-defi-primitives/) | AMM simple, lending pool, flash loan receiver, vault | ~15 horas | Intermedio |
| 04 | [Security Patterns](04-security-patterns/) | Exploits de reentrancy, contratos corregidos, analisis con Slither | ~15 horas | Intermedio |
| 05 | [Oracles and Bridges](05-oracles-and-bridges/) | Integracion Chainlink, TWAP oracle, bridge mock | ~10 horas | Intermedio |
| 06 | [Stablecoins](06-stablecoins/) | Stablecoin colateralizada, mecanismo CDP | ~12 horas | Intermedio-Alto |
| 07 | [Governance and DAOs](07-governance-and-daos/) | Governor contract, timelock, sistema de votacion on-chain | ~10 horas | Intermedio |
| 08 | [Identity, DID and SBT](08-identity-did-sbt/) | Soulbound Tokens, registro DID, Verifiable Credentials | ~10 horas | Intermedio |
| 09 | [Advanced DeFi](09-advanced-defi/) | Estrategias compuestas, integraciones multi-protocolo, MEV awareness | ~15 horas | Alto |
| 10 | [Real World Assets](10-real-world-assets/) | Tokenizacion de activos reales (RWA), compliance on-chain | ~12 horas | Alto |
| 11 | [Private Networks](11-private-networks/) | Red Besu IBFT 2.0, deploy en red privada, FireFly multiparty | ~12 horas | Intermedio-Alto |
| 12 | [AI Agents ERC-8004](12-ai-agents-erc8004/) | Identity, Reputation y Validation registries para AI agents | ~12 horas | Intermedio-Alto |

**Total estimado: ~144 horas**

---

## Como Ejecutar

Cada modulo contiene contratos en `src/` y tests en `test/`. Los comandos principales son:

```bash
# Compilar contratos
forge build

# Ejecutar tests
forge test

# Ejecutar tests con output detallado
forge test -vvv

# Ver cobertura de tests
forge coverage

# Analisis estatico de seguridad (requiere Slither instalado)
slither src/
```

Para instrucciones detalladas de instalacion y configuracion, ver [shared/tooling.md](../shared/tooling.md).

---

## Conexion con la Ruta Architect

Cada modulo del developer path tiene un complemento en el architect path. Despues de construir, estudia el "por que" detras del "como":

| Despues de completar... | Explora en architect/ |
|--------------------------|----------------------|
| 01-solidity-fundamentals | [01-blockchain-internals](../architect/01-blockchain-internals/) - Como funciona la EVM por dentro |
| 02-tokens-and-standards | [02-protocol-design](../architect/02-protocol-design/) - Diseno de protocolos e invariantes |
| 03-defi-primitives | [03-tokenomics-models](../architect/03-tokenomics-models/) - Modelos economicos detras de AMMs y lending |
| 04-security-patterns | [04-security-architecture](../architect/04-security-architecture/) - Vision sistemica de seguridad y threat modeling |
| 05-oracles-and-bridges | [05-scalability](../architect/05-scalability/) + [06-cross-chain](../architect/06-cross-chain-architecture/) - L2, rollups e interoperabilidad |
| 06-stablecoins | [03-tokenomics-models](../architect/03-tokenomics-models/) - Mecanismos de peg y estabilidad |
| 07-governance-and-daos | [09-system-design-cases](../architect/09-system-design-cases/) - Gobernanza como componente de sistema |
| 08-identity-did-sbt | [07-identity-and-compliance](../architect/07-identity-and-compliance/) - Identidad, regulacion y privacy |
| 09-advanced-defi | [08-mev-and-ordering](../architect/08-mev-and-ordering/) - MEV, PBS y order flow |
| 10-real-world-assets | [09-system-design-cases](../architect/09-system-design-cases/) - Tokenizacion como caso de diseno |
| 11-private-networks | [10-enterprise-blockchain](../architect/10-enterprise-blockchain/) - Arquitectura enterprise con Besu y FireFly |
| 12-ai-agents-erc8004 | — AI agents on-chain (sin equivalente architect aun) |

---

## Nota sobre Security Mindset

Cada modulo incluye una seccion de **"Vulnerabilidades relevantes"** que conecta lo que estas construyendo con los vectores de ataque conocidos. La seguridad no es un tema aparte: es una forma de pensar que aplica en cada linea de codigo.

Ejemplos de lo que vas a encontrar:
- En **01-Solidity**: integer overflow, errores de access control
- En **03-DeFi Primitives**: flash loan attacks, manipulacion de precios
- En **05-Oracles**: oracle manipulation, stale data
- En **06-Stablecoins**: de-peg scenarios, liquidation cascades

La regla es simple: **si no puedes atacar tu propio contrato, no lo entiendes lo suficiente**.
