# Blockchain DeFi - Ruta de Aprendizaje Completa

Ruta de aprendizaje integral para sistemas financieros basados en blockchain, desde smart contracts hasta temas avanzados como identidad descentralizada (DID), stablecoins y seguridad. El repositorio esta organizado en dos perspectivas complementarias:

- **Developer** (construir): escribir, testear y desplegar contratos inteligentes y protocolos DeFi.
- **Architect** (disenar sistemas): entender las decisiones de arquitectura, trade-offs y modelos economicos detras de los protocolos.

**Dirigido a**: personas que ya saben programar y tienen una nocion basica de que es blockchain. No es un curso introductorio de programacion.

---

## Roadmap

```
  DEVELOPER (build)                          ARCHITECT (design)
  ================                           ==================

  01-solidity-fundamentals          <-->     01-blockchain-internals
         |                                          |
  02-tokens-and-standards           <-->     02-protocol-design
         |                                          |
  03-defi-primitives                <-->     03-tokenomics-models
         |                                          |
  04-security-patterns              <-->     04-security-architecture
         |                                          |
  05-oracles-and-bridges            <-->     05-scalability
         |                                          |
  06-stablecoins                    <-->     06-cross-chain-architecture
         |                                          |
  07-governance-and-daos            <-->     07-identity-and-compliance
         |                                          |
  08-identity-did-sbt               <-->     08-mev-and-ordering
         |                                          |
  09-advanced-defi                  <-->     09-system-design-cases
         |                                          |
  10-real-world-assets                       10-enterprise-blockchain
         |
  11-private-networks
         |
  12-ai-agents-erc8004

  ============================================================
                    shared/
        glossary.md  tooling.md  testnet-setup.md
        erc-standards.md
```

---

## Tabla de Contenidos

### Developer Path

| Modulo | Tema |
|--------|------|
| [01-solidity-fundamentals](developer/01-solidity-fundamentals/) | Tipos, funciones, storage, modifiers, herencia |
| [02-tokens-and-standards](developer/02-tokens-and-standards/) | ERC-20, ERC-721, ERC-1155, ERC-4626 |
| [03-defi-primitives](developer/03-defi-primitives/) | AMM, lending, flash loans, vaults |
| [04-security-patterns](developer/04-security-patterns/) | Reentrancy, access control, upgrades, auditorias |
| [05-oracles-and-bridges](developer/05-oracles-and-bridges/) | Chainlink, TWAP, bridges, mensajeria cross-chain |
| [06-stablecoins](developer/06-stablecoins/) | Algoritmicos, colateralizados, CDP |
| [07-governance-and-daos](developer/07-governance-and-daos/) | Governor, timelock, votacion on-chain |
| [08-identity-did-sbt](developer/08-identity-did-sbt/) | DID, Soulbound Tokens, Verifiable Credentials |
| [09-advanced-defi](developer/09-advanced-defi/) | Composabilidad, MEV, estrategias avanzadas |
| [10-real-world-assets](developer/10-real-world-assets/) | Tokenizacion de activos reales (RWA) |
| [11-private-networks](developer/11-private-networks/) | Besu IBFT 2.0, FireFly, redes privadas |
| [12-ai-agents-erc8004](developer/12-ai-agents-erc8004/) | ERC-8004, AI agents on-chain, registries |

### Architect Path

| Modulo | Tema |
|--------|------|
| [01-blockchain-internals](architect/01-blockchain-internals/) | Consenso, EVM, state trie, gas model |
| [02-protocol-design](architect/02-protocol-design/) | Diseno de protocolos DeFi, invariantes |
| [03-tokenomics-models](architect/03-tokenomics-models/) | Modelos economicos, incentivos, emision |
| [04-security-architecture](architect/04-security-architecture/) | Threat modeling, superficie de ataque, formal verification |
| [05-scalability](architect/05-scalability/) | L2, rollups, data availability, sharding |
| [06-cross-chain-architecture](architect/06-cross-chain-architecture/) | Bridges, messaging protocols, interoperabilidad |
| [07-identity-and-compliance](architect/07-identity-and-compliance/) | Identidad, compliance, regulacion, privacy |
| [08-mev-and-ordering](architect/08-mev-and-ordering/) | MEV, PBS, order flow, subastas |
| [09-system-design-cases](architect/09-system-design-cases/) | Casos reales: Uniswap, Aave, MakerDAO, etc. |
| [10-enterprise-blockchain](architect/10-enterprise-blockchain/) | Besu, FireFly, redes consorcio, arquitectura enterprise |

---

## Correspondencia entre Paths

Muchos modulos del developer path tienen un modulo equivalente en el architect path. La idea es que puedas estudiar un tema desde ambos angulos.

| Developer | Architect | Tema comun |
|-----------|-----------|------------|
| 01-solidity-fundamentals | 01-blockchain-internals | Fundamentos de como funciona la EVM y Solidity |
| 02-tokens-and-standards | 02-protocol-design | Standards como building blocks de protocolos |
| 03-defi-primitives | 03-tokenomics-models | Mecanismos DeFi y sus modelos economicos |
| 04-security-patterns | 04-security-architecture | Seguridad a nivel codigo vs. a nivel sistema |
| 05-oracles-and-bridges | 05-scalability + 06-cross-chain-architecture | Conectividad con datos externos y otras cadenas |
| 06-stablecoins | 03-tokenomics-models | Estabilidad de precio y mecanismos de peg |
| 07-governance-and-daos | 09-system-design-cases | Gobernanza como componente de sistema |
| 08-identity-did-sbt | 07-identity-and-compliance | Identidad descentralizada y cumplimiento |
| 09-advanced-defi | 08-mev-and-ordering | Estrategias avanzadas y orden de transacciones |
| 10-real-world-assets | 09-system-design-cases | Tokenizacion RWA como caso de diseno de sistema |
| 11-private-networks | 10-enterprise-blockchain | Redes privadas: hands-on vs arquitectura enterprise |
| 12-ai-agents-erc8004 | — | AI agents on-chain con ERC-8004 (identity, reputation, validation) |

---

## Prerequisitos

- Experiencia programando en algun lenguaje (JavaScript, Python, Go, etc.)
- Comprension basica de que es blockchain: bloques, transacciones, wallets
- Comodidad con la terminal y git
- (Opcional) experiencia con alguna testnet

---

## Stack Tecnologico

| Herramienta | Uso |
|-------------|-----|
| **Foundry** (forge, cast, anvil) | Framework principal de desarrollo y testing |
| **Solidity 0.8.x** | Lenguaje de smart contracts |
| **Slither** | Analisis estatico de seguridad |
| **Mythril** | Ejecucion simbolica para encontrar vulnerabilidades |
| **OpenZeppelin Contracts** | Libreria de contratos auditados |
| **Chainlink** | Oracles y feeds de datos |
| **Hyperledger Besu** | Cliente Ethereum para redes privadas/consorcio |
| **Hyperledger FireFly** | Orquestacion multiparty enterprise |
| **Docker** | Contenedores para redes Besu locales |

Para instrucciones detalladas de instalacion y uso, ver [shared/tooling.md](shared/tooling.md).

---

## Como Usar Este Repositorio

### Orden sugerido

1. **Si vienes del desarrollo**: empieza por `developer/01-solidity-fundamentals` y avanza secuencialmente. Cuando termines un modulo, revisa el modulo correspondiente en `architect/` para entender el "por que" detras del "como".

2. **Si vienes de arquitectura o producto**: empieza por `architect/01-blockchain-internals` y complementa con los ejercicios practicos del `developer/` path.

3. **Si quieres ir rapido**: elige un tema especifico (por ejemplo, stablecoins) y estudia tanto `developer/06-stablecoins` como `architect/03-tokenomics-models`.

### Estructura de cada modulo

Cada modulo contiene (o contendra):
- `README.md` con la teoria y explicaciones
- Contratos de ejemplo en `src/`
- Tests en `test/`
- Ejercicios propuestos

## Recursos Compartidos

- [shared/glossary.md](shared/glossary.md) - Glosario con 60+ terminos clave de blockchain, DeFi, seguridad y mas.
- [shared/erc-standards.md](shared/erc-standards.md) - Guia de estandares ERC: tokens, NFTs, identidad, infraestructura, AI agents.
- [shared/tooling.md](shared/tooling.md) - Guia de herramientas: Foundry, Slither, Mythril, Besu, FireFly, extensiones de VS Code.
- [shared/testnet-setup.md](shared/testnet-setup.md) - Guia de testnets: faucets, RPC, configuracion para deploy.
