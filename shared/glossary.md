# Glosario Blockchain y DeFi

Terminos organizados alfabeticamente. Cada entrada usa el termino tecnico en ingles con su definicion en espanol.

---

## A

**A2A Protocol (Agent-to-Agent)**
Protocolo de Google para descubrimiento y comunicacion entre agentes de IA. Define "Agent Cards" con metadata del agente, soporta HTTP y WebSocket como transporte. Complementa ERC-8004 que provee identidad y reputacion on-chain.

**Access Control**
Mecanismo que restringe quien puede llamar funciones de un smart contract. Patrones comunes: `Ownable`, `AccessControl` de OpenZeppelin, y modifiers personalizados.

**Account Abstraction**
Modelo que permite que las cuentas de usuario (EOA) se comporten como smart contracts, habilitando recuperacion de llaves, pagos de gas por terceros y logica personalizada de autenticacion.

**AMM (Automated Market Maker)**
Protocolo que permite intercambiar tokens sin order book, usando pools de liquidez y una formula matematica (por ejemplo, x * y = k en Uniswap v2) para determinar precios.

**Agent Registration File**
Archivo JSON que describe a un agente registrado en ERC-8004. Incluye campos obligatorios (name, description, image, services) y opcionales (registrations, supportedTrust, active). El URI del agente en el Identity Registry apunta a este archivo.

**Atomic Swap**
Intercambio de tokens entre dos partes sin intermediario, garantizado por smart contracts. Si una parte no cumple, la transaccion completa se revierte.

---

## B

**Besu (Hyperledger Besu)**
Cliente Ethereum open-source desarrollado bajo Hyperledger (Linux Foundation). Soporta redes publicas y privadas, con consenso modular (IBFT 2.0, QBFT, Clique) y transacciones privadas via Tessera. Ideal para redes enterprise y consorcio.

**Block**
Unidad de datos que contiene un conjunto de transacciones, un hash del bloque anterior, timestamp y otros metadatos. Los bloques forman la cadena (blockchain).

**Bridge**
Protocolo que permite transferir activos o mensajes entre dos blockchains diferentes. Ejemplos: Wormhole, LayerZero, Axelar.

**Bytecode**
Codigo compilado de un smart contract que se ejecuta en la EVM. Es el resultado de compilar Solidity (u otro lenguaje) y es lo que realmente se despliega en la blockchain.

---

## C

**Consortium Network**
Red blockchain operada por un grupo predefinido de organizaciones que comparten la validacion. A diferencia de una red publica (abierta a todos) o privada (una sola entidad), el consorcio distribuye el control entre multiples participantes conocidos. Ejemplos: redes Besu con IBFT 2.0.

**CDP (Collateralized Debt Position)**
Posicion en la que un usuario deposita colateral (por ejemplo, ETH) para generar una stablecoin (por ejemplo, DAI). Si el colateral cae por debajo de cierto ratio, la posicion puede ser liquidada.

**Collateral Ratio**
Proporcion entre el valor del colateral depositado y la deuda generada. Un ratio de 150% significa que por cada $100 de deuda, hay $150 en colateral.

**Consensus**
Mecanismo por el cual los nodos de una red blockchain acuerdan el estado valido de la cadena. Ejemplos: Proof of Work (PoW), Proof of Stake (PoS), PBFT.

**Constant Product Formula**
Formula x * y = k usada por AMMs como Uniswap v2. Garantiza que el producto de las reservas de dos tokens en un pool se mantiene constante despues de cada swap.

---

## D

**DAO (Decentralized Autonomous Organization)**
Organizacion gobernada por smart contracts y votacion on-chain de holders de tokens de gobernanza. Las decisiones (cambios de parametros, asignacion de fondos) requieren aprobacion comunitaria.

**Data Availability**
Garantia de que los datos de las transacciones estan accesibles para que cualquier nodo pueda verificar la validez del estado. Critico en soluciones L2 y rollups.

**DID (Decentralized Identifier)**
Identificador digital descentralizado que permite a una entidad tener una identidad verificable sin depender de una autoridad central. Estandar W3C.

---

## E

**EIP (Ethereum Improvement Proposal)**
Propuesta formal para cambios en el protocolo Ethereum o estandares de la comunidad. Los ERCs son un subconjunto de EIPs enfocados en estandares de aplicacion.

**EOA (Externally Owned Account)**
Cuenta controlada por una llave privada (la cuenta tipica de un usuario). A diferencia de un contrato, no tiene codigo asociado.

**ERC-20**
Estandar para tokens fungibles en Ethereum. Define funciones como `transfer`, `approve`, `balanceOf` y `totalSupply`.

**ERC-721**
Estandar para tokens no fungibles (NFTs). Cada token tiene un ID unico y puede representar un activo digital diferente.

**ERC-1155**
Estandar multi-token que permite manejar tokens fungibles y no fungibles en un solo contrato, optimizando gas en operaciones batch.

**ERC-8004 (Trustless Agents)**
Estandar para registrar, evaluar y validar agentes de IA on-chain. Define tres registries: Identity (ERC-721 para identidad de agentes), Reputation (feedback de clientes) y Validation (verificacion por validators independientes). Propuesto por MetaMask, Ethereum Foundation, Google y Coinbase.

**ERC-4626**
Estandar para vaults tokenizados. Define una interfaz comun para depositar activos, obtener shares, y retirar, facilitando composabilidad entre protocolos DeFi.

**EVM (Ethereum Virtual Machine)**
Maquina virtual que ejecuta el bytecode de los smart contracts. Es determinista, stack-based, y define el entorno de ejecucion de Ethereum y cadenas compatibles.

---

## F

**Faucet**
Servicio que distribuye tokens de prueba (testnet ETH) de forma gratuita para que desarrolladores puedan testear aplicaciones sin costo. Cada testnet tiene sus propios faucets con diferentes requisitos y limites diarios.

**Finality**
Garantia de que una transaccion confirmada no puede ser revertida. En PoW es probabilistica (mas bloques = mas seguridad). En PoS puede ser determinista con mecanismos de finalizacion.

**Finality (Immediate)**
Tipo de finalidad donde una transaccion es irrevocable en cuanto se incluye en un bloque. Caracteristica de protocolos BFT como IBFT 2.0 y QBFT, donde 2/3+ de validators confirman cada bloque antes de producirlo. No hay reorganizaciones ni bloques huerfanos.

**FireFly (Hyperledger FireFly)**
Plataforma de orquestacion multiparty para aplicaciones Web3 enterprise. Proporciona APIs REST para tokens, messaging, data exchange y event streams sobre redes blockchain. Soporta conectores para Ethereum, Besu, Fabric y otros.

**Flash Loan**
Prestamo sin colateral que debe ser tomado y devuelto (con fee) dentro de la misma transaccion. Si no se devuelve, toda la transaccion se revierte. Usado para arbitraje, liquidaciones y reestructuracion de deuda.

**Front-running**
Ataque en el que un actor observa una transaccion pendiente en el mempool y coloca su propia transaccion antes (con mas gas) para obtener ventaja economica.

---

## G

**Gas**
Unidad de medida del costo computacional de ejecutar operaciones en la EVM. Cada opcode tiene un costo en gas. El usuario paga gas price * gas used en ETH.

**Governor**
Contrato de gobernanza (tipicamente basado en OpenZeppelin Governor) que gestiona propuestas, votaciones y ejecucion de acciones aprobadas por una DAO.

---

## H

**Hash**
Funcion criptografica que transforma datos de cualquier tamano en un valor de tamano fijo (256 bits en Ethereum con keccak256). Es determinista, irreversible y resistente a colisiones.

**Hooks**
Puntos de extension en protocolos como Uniswap v4 que permiten ejecutar logica personalizada antes o despues de operaciones (swaps, adicion de liquidez, etc.).

---

## I

**IBFT 2.0 (Istanbul Byzantine Fault Tolerant)**
Protocolo de consenso BFT para redes Ethereum permisionadas. Requiere 2/3+1 de los validators para confirmar cada bloque, tolerando hasta 1/3 de nodos maliciosos. Provee finality inmediata (sin forks). Usado en Hyperledger Besu para redes privadas y consorcio.

**Impermanent Loss**
Perdida temporal que sufre un proveedor de liquidez en un AMM cuando el precio relativo de los tokens en el pool cambia respecto al momento del deposito. Se vuelve permanente solo al retirar.

**Invariant**
Condicion que debe mantenerse verdadera en todo momento dentro de un protocolo. Ejemplo: en un AMM de producto constante, x * y = k es el invariante principal.

---

## K

**Keeper**
Bot o servicio off-chain que ejecuta acciones on-chain cuando se cumplen ciertas condiciones (liquidaciones, rebalanceos, harvest de rewards). Incentivado economicamente.

---

## L

**L2 (Layer 2)**
Solucion de escalabilidad construida sobre una blockchain base (L1) que procesa transacciones fuera de la cadena principal pero hereda sus garantias de seguridad. Ejemplos: Arbitrum, Optimism, zkSync.

**Liquidation**
Proceso en el que el colateral de un usuario es vendido automaticamente porque su posicion cayo por debajo del ratio minimo requerido. Protege al protocolo de deuda insolvente.

**Liquidity Pool**
Par de tokens depositados en un smart contract que permite intercambios (swaps) via un AMM. Los proveedores de liquidez depositan tokens y reciben fees proporcionales a su participacion.

---

## M

**MCP (Model Context Protocol)**
Protocolo de Anthropic para conectar modelos de IA con herramientas y datos externos. Define "Tools" como funciones invocables por el agente, con transporte via stdio o HTTP. En el contexto de ERC-8004, los endpoints MCP pueden registrarse como services en el Agent Registration File.

**Mempool**
Conjunto de transacciones pendientes que esperan ser incluidas en un bloque. Los validadores/miners seleccionan transacciones del mempool, generalmente priorizando por gas price.

**Merkle Tree**
Estructura de datos en arbol donde cada hoja es el hash de un dato y cada nodo interno es el hash de sus hijos. Permite verificar la inclusion de un dato con una prueba compacta (Merkle proof).

**MEV (Maximal Extractable Value)**
Valor maximo que un productor de bloques (o searcher) puede extraer al reordenar, incluir o excluir transacciones dentro de un bloque. Incluye arbitraje, liquidaciones y sandwich attacks.

**Modifier**
Patron de Solidity que permite agregar precondiciones a funciones (por ejemplo, `onlyOwner`). Se ejecuta antes (o alrededor) del cuerpo de la funcion.

---

## N

**Nonce**
Numero secuencial asociado a cada cuenta que se incrementa con cada transaccion enviada. Previene replay attacks y determina el orden de las transacciones de una cuenta.

---

## O

**Oracle**
Servicio que proporciona datos externos (precios, clima, resultados) a smart contracts. Como los contratos no pueden acceder a internet, los oracles actuan como puente. Ejemplo: Chainlink.

**Oracle Manipulation**
Ataque en el que un actor manipula el precio reportado por un oracle (especialmente spot prices on-chain) para explotar un protocolo DeFi, por ejemplo manipulando un flash loan para alterar un precio TWAP de corto plazo.

---

## P

**Permissioned Network**
Red blockchain donde la participacion (como validator, transactor o lector) requiere autorizacion explicita. Contrasta con redes permissionless como Ethereum mainnet. Permite controlar quien valida bloques y quien envia transacciones.

**Privacy Group**
Conjunto de nodos en una red Besu que participan en transacciones privadas. Solo los miembros del privacy group pueden ver el contenido de las transacciones privadas. Gestionado por Tessera (private transaction manager).

**PBS (Proposer-Builder Separation)**
Separacion de roles en la produccion de bloques: el builder construye el bloque (ordenando transacciones) y el proposer lo propone a la red. Reduce centralizacion y conflictos de interes por MEV.

**Proxy Pattern**
Patron de upgradabilidad en el que un contrato proxy delega todas las llamadas a un contrato de implementacion. Permite actualizar la logica sin cambiar la direccion del contrato. Variantes: Transparent Proxy, UUPS.

---

## Q

**Quorum**
Numero minimo de votos (o porcentaje del supply de gobernanza) requerido para que una propuesta en una DAO sea valida. Previene que decisiones se tomen con participacion insignificante.

---

## R

**Reentrancy**
Vulnerabilidad en la que un contrato externo llama de vuelta al contrato victima antes de que este termine de actualizar su estado. El patron checks-effects-interactions y el `ReentrancyGuard` de OpenZeppelin lo previenen.

**Rollup**
Solucion L2 que ejecuta transacciones off-chain y publica datos comprimidos o pruebas en L1. Optimistic rollups usan pruebas de fraude; ZK rollups usan pruebas de validez (zero-knowledge proofs).

---

## S

**Sandwich Attack**
Tipo de MEV en el que un atacante coloca una transaccion antes (front-run) y otra despues (back-run) de la transaccion de una victima para extraer valor via manipulacion de precio.

**SBT (Soulbound Token)**
Token no transferible vinculado a una wallet (propuesto por Vitalik Buterin). Usado para representar credenciales, reputacion o logros que no deben ser vendidos.

**Sidechain**
Blockchain independiente conectada a una cadena principal via un bridge. Tiene su propio mecanismo de consenso y seguridad, a diferencia de un L2 que hereda la seguridad de L1.

**Slippage**
Diferencia entre el precio esperado y el precio real de ejecucion de un swap. Aumenta con ordenes grandes relativas al tamano del pool. Se configura un slippage tolerance maximo en la UI.

**Storage Collision**
Vulnerabilidad en contratos proxy donde la implementacion y el proxy usan los mismos slots de storage, causando que datos se sobreescriban. Se previene con patrones como EIP-1967.

---

## T

**Tessera**
Private transaction manager para Hyperledger Besu. Gestiona el envio, almacenamiento y distribucion de transacciones privadas entre nodos autorizados. Encripta el payload de transacciones privadas y lo distribuye solo a los participantes del privacy group.

**Testnet**
Red blockchain de prueba que replica el comportamiento de mainnet pero usa tokens sin valor real. Permite testear smart contracts y aplicaciones sin riesgo economico. Principales testnets de Ethereum: Sepolia y Holesky.

**Timelock**
Contrato que impone un retraso entre la aprobacion de una accion y su ejecucion. Da tiempo a los usuarios para reaccionar ante cambios (salir del protocolo, votar en contra).

**TVL (Total Value Locked)**
Valor total de activos depositados en un protocolo DeFi. Metrica comun para medir el tamano y adopcion de un protocolo.

**TWAP (Time-Weighted Average Price)**
Precio promedio ponderado por tiempo. Usado como oracle resistente a manipulacion porque requiere mantener el precio alterado durante un periodo extenso, no solo un bloque.

---

## V

**Vault**
Contrato que acepta depositos de un activo y ejecuta una estrategia para generar rendimiento. ERC-4626 estandariza la interfaz de vaults tokenizados.

**ve-Token (Vote-Escrowed Token)**
Modelo de gobernanza (popularizado por Curve) en el que los usuarios bloquean tokens por un periodo para obtener poder de voto y rewards. Mas tiempo bloqueado = mas peso.

**Verifiable Credential (VC)**
Credencial digital firmada criptograficamente que puede ser verificada sin contactar al emisor. Componente clave de la identidad descentralizada junto con DIDs.

---

## W

**Wrapped Token**
Token que representa otro activo en una blockchain diferente o en un formato compatible. Ejemplo: WETH (Wrapped ETH) es una version ERC-20 de ETH nativo.

---

## Y

**Yield Farming**
Estrategia de depositar activos en protocolos DeFi para maximizar rendimientos, moviendo capital entre distintas oportunidades (lending, liquidity provision, staking).

---

## Z

**Zero-Knowledge Proof (ZKP)**
Prueba criptografica que permite demostrar que una afirmacion es verdadera sin revelar la informacion subyacente. Usada en ZK rollups, identidad privada y votacion anonima. Variantes: zk-SNARKs, zk-STARKs.
