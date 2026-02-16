# Ruta Architect - Disenar Sistemas Blockchain

Este path se enfoca en **diseno de sistemas**, trade-offs y decisiones de arquitectura. No requiere escribir codigo (aunque entender Solidity ayuda significativamente). Cada modulo es un documento de diseno, no un proyecto de codigo. Los ejercicios son del tipo "disenar en papel": diagramas, analisis de trade-offs y evaluacion de decisiones.

---

## Prerequisitos

- Modulos 01 a 04 del developer path completados (o conocimiento equivalente de Solidity, tokens, DeFi basico y patrones de seguridad)
- Entendimiento de conceptos de sistemas distribuidos: consenso, consistencia eventual, particiones de red
- Familiaridad con analisis de trade-offs en sistemas de software
- (Recomendado) experiencia disenando APIs o sistemas backend

---

## Roadmap Visual

```
                      RUTA ARCHITECT
                      ==============

  01 Blockchain Internals ──> 02 Protocol Design ──> 03 Tokenomics
                                      |
  04 Security Architecture ───────────┤
                                      |
  05 Scalability ──────────> 06 Cross-chain Architecture
                                      |
  07 Identity & Compliance ───────────┤
                                      |
  08 MEV & Ordering ──────────────────┘
                                      |
                            09 System Design Cases
                                      |
                            10 Enterprise Blockchain
```

Los modulos 01-03 establecen los fundamentos. Los modulos 04-08 pueden estudiarse con cierta flexibilidad en el orden, pero todos convergen en el modulo 09 donde se analizan casos reales completos. El modulo 10 (Enterprise Blockchain) se recomienda despues del 07 y 09.

---

## Tabla de Modulos

| # | Modulo | Area de enfoque | Esfuerzo estimado | Dificultad |
|---|--------|-----------------|--------------------|------------|
| 01 | [Blockchain Internals](01-blockchain-internals/) | Consenso, EVM internals, state trie, gas model | ~8 horas | Intermedio |
| 02 | [Protocol Design](02-protocol-design/) | Diseno de protocolos DeFi, invariantes, composability | ~10 horas | Intermedio |
| 03 | [Tokenomics Models](03-tokenomics-models/) | Modelos economicos, incentivos, emision, mecanismos de peg | ~10 horas | Intermedio-Alto |
| 04 | [Security Architecture](04-security-architecture/) | Threat modeling, superficie de ataque, formal verification | ~10 horas | Alto |
| 05 | [Scalability](05-scalability/) | L2 rollups, data availability, sharding, throughput | ~10 horas | Alto |
| 06 | [Cross-chain Architecture](06-cross-chain-architecture/) | Bridges, messaging protocols, interoperabilidad | ~8 horas | Alto |
| 07 | [Identity and Compliance](07-identity-and-compliance/) | Identidad descentralizada, compliance regulatorio, privacy | ~8 horas | Intermedio-Alto |
| 08 | [MEV and Ordering](08-mev-and-ordering/) | MEV extraction, PBS, order flow, subastas de bloques | ~8 horas | Alto |
| 09 | [System Design Cases](09-system-design-cases/) | Casos reales: Uniswap, Aave, MakerDAO, analisis end-to-end | ~12 horas | Alto |
| 10 | [Enterprise Blockchain](10-enterprise-blockchain/) | Besu, FireFly, consorcio, arquitectura hibrida publica/privada | ~8 horas | Intermedio-Alto |

**Total estimado: ~92 horas**

---

## Conexion con la Ruta Developer

Cada modulo tiene un complemento practico en el developer path. Despues de estudiar el diseno, construye para consolidar:

| Modulo architect | Complemento en developer/ |
|------------------|--------------------------|
| 01-blockchain-internals | [01-solidity-fundamentals](../developer/01-solidity-fundamentals/) - Escribir contratos entendiendo la EVM |
| 02-protocol-design | [02-tokens-and-standards](../developer/02-tokens-and-standards/) - Implementar los standards que disenas |
| 03-tokenomics-models | [03-defi-primitives](../developer/03-defi-primitives/) + [06-stablecoins](../developer/06-stablecoins/) - Construir los mecanismos economicos |
| 04-security-architecture | [04-security-patterns](../developer/04-security-patterns/) - Explotar y corregir vulnerabilidades reales |
| 05-scalability | [05-oracles-and-bridges](../developer/05-oracles-and-bridges/) - Integrar con L2 y datos externos |
| 06-cross-chain-architecture | [05-oracles-and-bridges](../developer/05-oracles-and-bridges/) - Implementar messaging cross-chain |
| 07-identity-and-compliance | [08-identity-did-sbt](../developer/08-identity-did-sbt/) - Construir DID y Soulbound Tokens |
| 08-mev-and-ordering | [09-advanced-defi](../developer/09-advanced-defi/) - Estrategias avanzadas con awareness de MEV |
| 09-system-design-cases | [07-governance-and-daos](../developer/07-governance-and-daos/) + [10-real-world-assets](../developer/10-real-world-assets/) - Gobernanza y tokenizacion en la practica |
| 10-enterprise-blockchain | [11-private-networks](../developer/11-private-networks/) - Levantar red Besu, desplegar contratos, usar FireFly |

---

## Formato de Cada Modulo

Cada modulo es un **documento de diseno**, no un proyecto de codigo. La estructura tipica incluye:

- **Contexto y motivacion**: por que existe este problema
- **Conceptos clave**: definiciones y modelos mentales
- **Trade-offs**: analisis comparativo de diferentes enfoques
- **Patrones y anti-patrones**: decisiones arquitectonicas comunes
- **Casos de estudio**: como lo resolvieron protocolos reales
- **Ejercicios**: problemas de diseno para resolver en papel

Los ejercicios son del tipo:
- "Disena un sistema de lending que soporte X, Y y Z. Que trade-offs asumes?"
- "Analiza la arquitectura de Uniswap v3. Que decisiones cambiarias y por que?"
- "Modela las amenazas de un bridge cross-chain. Donde estan los puntos de falla?"

---

## Enfoque Recomendado

Este path se aprovecha mejor en grupo:

1. **Leer individualmente** el modulo antes de la sesion grupal
2. **Discutir trade-offs** en grupo: no hay respuestas unicas, hay decisiones con consecuencias
3. **Cuestionar supuestos**: preguntar "que pasa si..." y "por que no..."
4. **Dibujar diagramas**: la arquitectura se entiende mejor de forma visual
5. **Conectar con la realidad**: analizar protocolos existentes (Etherscan, documentacion oficial, post-mortems de hacks)

> La meta no es memorizar arquitecturas. Es desarrollar el criterio para **evaluar trade-offs** y tomar decisiones informadas ante problemas nuevos.
