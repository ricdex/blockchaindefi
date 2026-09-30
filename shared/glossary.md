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

**Assertion (Arbitrum)**
Afirmacion que un validador de Arbitrum publica en el contrato `Rollup` de Ethereum: "despues de ejecutar los batches hasta N, el estado de L2 es S". Queda abierta durante el challenge period (~6.4 dias en Arbitrum One). Si nadie la disputa con exito, L1 la acepta como definitiva y los retiros basados en ella se pueden ejecutar.

**Atomic Swap**
Intercambio de tokens entre dos partes sin intermediario, garantizado por smart contracts. Si una parte no cumple, la transaccion completa se revierte.

---

## B

**Besu (Hyperledger Besu)**
Cliente Ethereum open-source desarrollado bajo Hyperledger (Linux Foundation). Soporta redes publicas y privadas, con consenso modular (IBFT 2.0, QBFT, Clique) y transacciones privadas via Tessera. Ideal para redes enterprise y consorcio.

**Batch (rollup)**
Paquete de muchas transacciones de L2, comprimidas, que el sequencer publica en L1 (en Arbitrum, en el contrato `SequencerInbox`). Es la forma en que un rollup cumple con la disponibilidad de datos: con los batches, cualquiera puede re-ejecutar la L2 y reconstruir su estado.

**Blob (EIP-4844)**
Espacio de datos barato y temporal (~18 dias) que las transacciones de tipo 3 adjuntan a un bloque de Ethereum. Los rollups publican alli sus batches. La EVM no puede leer el contenido del blob; en L1 queda para siempre solo su compromiso criptografico (`blobVersionedHash`).

**Block**
Unidad de datos que contiene un conjunto de transacciones, un hash del bloque anterior, timestamp y otros metadatos. Los bloques forman la cadena (blockchain).

**Bridge**
Protocolo que conecta dos blockchains diferentes. Un activo nunca "viaja": el bridge lo bloquea (o quema) en una red y acredita (o emite) una representacion en la otra, asegurando que ambas cosas se correspondan. Su riesgo depende de quien verifica lo que paso en la red de origen. Ejemplos: Arbitrum Bridge (canonico), Wormhole, LayerZero, Axelar.

**Bridged Token**
Token en una red B que representa un activo bloqueado en una red A. Vale lo que valga la garantia del bridge: si el bridge es hackeado, la representacion queda sin respaldo. Ejemplo: USDC.e en Arbitrum (respaldado por USDC bloqueado en Ethereum), a diferencia del USDC de emision nativa que Circle acuna directamente en Arbitrum. No confundir con wrapped token.

**Bytecode**
Codigo compilado de un smart contract que se ejecuta en la EVM. Es el resultado de compilar Solidity (u otro lenguaje) y es lo que realmente se despliega en la blockchain.

---

## C

**Canonical Bridge**
Bridge "oficial" de una L2, formado por contratos en L1 que la propia L2 esta obligada a respetar. En un rollup, lo verifica el mismo Ethereum (datos publicados en L1 y estado disputable en L1), sin validadores externos. Ejemplo: el bridge de Arbitrum (contratos `Inbox`, `Bridge` y `Outbox` en Ethereum).

**Chain ID**
Numero que identifica a una red EVM (1 = Ethereum Mainnet, 42161 = Arbitrum One, 421614 = Arbitrum Sepolia, 31337 = Anvil). Se incluye en cada firma (EIP-155), asi que una transaccion firmada para una red no es valida en otra. La wallet usa el chain ID, y no el nombre ni el simbolo, para saber a que red habla.

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

**Deposit Cap**
Limite maximo de activos que un vault puede aceptar, implementado sobreescribiendo `maxDeposit` y `maxMint` en ERC-4626. Permite controlar el riesgo total del protocolo (TVL) y es comun en contextos institucionales donde el vault no puede escalar infinitamente por restricciones de la estrategia subyacente.

**DID (Decentralized Identifier)**
Identificador digital descentralizado que permite a una entidad tener una identidad verificable sin depender de una autoridad central. Estandar W3C.

**Donation Attack**
Ataque a vaults ERC-4626 donde el atacante transfiere tokens directamente al contrato (sin usar `deposit`) para alterar el ratio assets/shares. Un usuario que deposita despues puede ver sus shares redondeadas a 0 si el ratio es suficientemente alto. Es una variante del Inflation Attack. Se mitiga con Virtual Shares (`_decimalsOffset`).

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

**ERC-7540**
Estandar para vaults asincronicos (async vaults). Extiende ERC-4626 con un flujo de tres pasos: `requestDeposit → fulfillDeposit → claim`. Disenado para activos del mundo real (RWA) donde el settlement no es instantaneo (por ejemplo, un bono que tarda dias en liquidar). Define el rol de "operator" para delegar la gestion de solicitudes. La clave de diseño es que el precio se fija en el momento del `fulfill`, no al momento del `request`.

**EVM (Ethereum Virtual Machine)**
Maquina virtual que ejecuta el bytecode de los smart contracts. Es determinista, stack-based, y define el entorno de ejecucion de Ethereum y cadenas compatibles. Es una *especificacion*, no una red: Ethereum, Arbitrum, BNB Chain y Anvil ejecutan la misma EVM, pero cada una tiene su propio estado y su propio activo nativo.

**EVM-compatible**
Red que ejecuta la EVM (mismo bytecode, mismas direcciones, mismas herramientas). No implica usar ETH como gas (BNB Chain usa BNB, Polygon PoS usa POL) ni ser una L2 (BNB Chain es una cadena independiente). Describe la experiencia del desarrollador, no el modelo de seguridad.

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

**Fuzz Test**
Tipo de test en Foundry donde los inputs son generados aleatoriamente por el fuzzer para descubrir edge cases. Se escribe prefijando el nombre del test con `testFuzz_` y declarando parametros de tipo uint256, address, etc. Foundry genera cientos de combinaciones y reporta el contraejemplo minimo si alguna falla. Ejemplo: `function testFuzz_deposit(uint256 amount) public { ... }`.

---

## G

**Gas**
Unidad de medida del costo computacional de ejecutar operaciones en la EVM. Cada opcode tiene un costo en gas. El usuario paga gas price * gas used en ETH.

**Gas Snapshot**
Registro de los costos de gas de las funciones de un contrato generado con `forge snapshot`. Crea un archivo `.gas-snapshot` que permite comparar si un cambio en el codigo aumenta o disminuye el gas consumido. Util para detectar regresiones de gas en CI.

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

**Inflation Attack**
Ataque a vaults ERC-4626 donde el primer depositor acuna 1 wei de shares y luego dona activos directamente al contrato para inflar el precio por share a un valor enorme. Los depositos posteriores de victimas se redondean a 0 shares, perdiendo todos sus activos. Se mitiga con Virtual Shares (`_decimalsOffset`) o con un deposito minimo inicial al desplegar.

**Invariant**
Condicion que debe mantenerse verdadera en todo momento dentro de un protocolo. Ejemplo: en un AMM de producto constante, x * y = k es el invariante principal.

**Invariant Test (Stateful Fuzzing)**
Tipo de test avanzado en Foundry donde el fuzzer ejecuta secuencias aleatorias de llamadas a un contrato y verifica al final de cada secuencia que ciertas propiedades (invariantes) se mantienen. Se declaran con el prefijo `invariant_`. Ejemplo: "el total de activos en el vault siempre es mayor o igual a la suma de shares redimibles". Foundry ejecuta N secuencias de M pasos cada una (configurables con `depth` y `runs`).

---

## K

**Keeper**
Bot o servicio off-chain que ejecuta acciones on-chain cuando se cumplen ciertas condiciones (liquidaciones, rebalanceos, harvest de rewards). Incentivado economicamente.

---

## L

**L1 (Layer 1)**
Blockchain base que ofrece consenso, seguridad y disponibilidad de datos propios. Ethereum Mainnet es la L1 de Arbitrum, Base y Optimism.

**L2 (Layer 2)**
Red que ejecuta transacciones y mantiene su propio estado, pero delega en una L1 la parte que requiere confianza: publica alli sus datos (disponibilidad), guarda alli los fondos depositados (bridge canonico) y deja que la L1 decida que estado es valido (fraud o validity proofs). Resumen: "L2 ejecuta; L1 proporciona infraestructura de confianza". Ejemplos: Arbitrum, Optimism, zkSync. Una red EVM con su propio consenso (BNB Chain) no es una L2 aunque sea compatible.

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

**Native Asset (activo nativo)**
Activo que lleva el propio protocolo de la red en el campo `balance` de cada cuenta, sin smart contract. ETH es el activo nativo de Ethereum y tambien de Arbitrum (en Arbitrum es otro registro, respaldado por ETH bloqueado en L1). Ojo: "USDC nativo" usa la palabra en otro sentido (token emitido directamente por su emisor en esa red, sin bridge), pero sigue siendo un ERC-20.

**Native Gas Token**
Activo nativo con el que se paga el gas en una red. Tiene que ser nativo porque el protocolo necesita cobrar antes de ejecutar cualquier contrato. Ejemplos: ETH (Ethereum, Arbitrum, Base), BNB (BNB Chain), POL (Polygon PoS), AVAX (Avalanche C-Chain).

**Nonce**
Numero secuencial asociado a cada cuenta que se incrementa con cada transaccion enviada. Previene replay attacks y determina el orden de las transacciones de una cuenta.

---

## O

**Operator (ERC-7540)**
Cuenta autorizada por el propietario de los activos para gestionar solicitudes de deposito o retiro en su nombre dentro de un vault ERC-7540. Similar al par `approve`/`transferFrom` de ERC-20 pero aplicado al ciclo de vida asincrono del vault. Permite que un bot o contrato externo gestione operaciones sin que el usuario deba estar presente en cada paso.

**Oracle**
Servicio que proporciona datos externos (precios, clima, resultados) a smart contracts. Como los contratos no pueden acceder a internet, los oracles actuan como puente. Ejemplo: Chainlink.

**Oracle Manipulation**
Ataque en el que un actor manipula el precio reportado por un oracle (especialmente spot prices on-chain) para explotar un protocolo DeFi, por ejemplo manipulando un flash loan para alterar un precio TWAP de corto plazo.

---

## P

**Precompile**
Contrato "integrado" en el cliente de la red, en una direccion fija, que ejecuta codigo nativo en lugar de bytecode EVM. Ethereum tiene precompiles criptograficos (ej: `ecrecover` en `0x01`). Arbitrum agrega los suyos: `ArbSys` (`0x64`) para retiros y numero de bloque de L2, y `NodeInterface` (`0xC8`) para consultar batches. Solo existen en la red que los implementa.

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

**Rounding Direction (Vault)**
En vaults ERC-4626, las conversiones entre shares y assets tienen ambiguedad al redondear numeros enteros. El estandar especifica que las operaciones deben redondear a favor del vault (no del usuario) para evitar que micro-transacciones extraigan valor. Concretamente: `previewWithdraw` y `previewMint` redondean hacia arriba (el usuario paga mas), mientras que `previewRedeem` y `previewDeposit` redondean hacia abajo (el usuario recibe menos). Violar esta regla abre vectores de extraccion de valor.

**Rollup**
Solucion L2 que ejecuta transacciones off-chain y publica datos comprimidos o pruebas en L1. Optimistic rollups usan pruebas de fraude; ZK rollups usan pruebas de validez (zero-knowledge proofs).

---

## S

**Sandwich Attack**
Tipo de MEV en el que un atacante coloca una transaccion antes (front-run) y otra despues (back-run) de la transaccion de una victima para extraer valor via manipulacion de precio.

**SBT (Soulbound Token)**
Token no transferible vinculado a una wallet (propuesto por Vitalik Buterin). Usado para representar credenciales, reputacion o logros que no deben ser vendidos.

**Sequencer**
Componente de una L2 que recibe las transacciones, decide su orden y las ejecuta al instante (en Arbitrum, ~250 ms). Puede retrasar o censurar, pero no falsificar el estado. Contra la censura existe la inclusion forzada via L1. Tambien publica los batches en L1.

**Settlement (asentamiento)**
Punto en el que un resultado pasa a ser definitivo para el sistema que lo respalda. Una L2 "se asienta" en Ethereum cuando el contrato del rollup en L1 acepta su estado (tras el challenge period en un optimistic rollup, o tras verificar la prueba en un ZK rollup). Los retiros hacia L1 solo se liberan contra un estado asentado.

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
Contrato que acepta depositos de un activo y ejecuta una estrategia para generar rendimiento. ERC-4626 estandariza la interfaz de vaults tokenizados. Para casos asincronos (activos reales, settlement diferido), ERC-7540 extiende ERC-4626 con un flujo request → fulfill → claim.

**Virtual Shares (decimalsOffset)**
Mecanismo de mitigacion del Inflation Attack en ERC-4626. Simula que el vault comenzo con un numero grande de shares y activos virtuales (10^offset), haciendo que el ratio inicial de shares/assets no sea 1:1 sino 1:10^offset. Esto hace que inflar el precio a un nivel peligroso sea economicamente prohibitivo para el atacante. OpenZeppelin ERC4626 expone `_decimalsOffset()` para configurarlo. Un offset de 3 agrega 1000 shares virtuales por asset virtual.

**ve-Token (Vote-Escrowed Token)**
Modelo de gobernanza (popularizado por Curve) en el que los usuarios bloquean tokens por un periodo para obtener poder de voto y rewards. Mas tiempo bloqueado = mas peso.

**Verifiable Credential (VC)**
Credencial digital firmada criptograficamente que puede ser verificada sin contactar al emisor. Componente clave de la identidad descentralizada junto con DIDs.

---

## W

**Wrapped Token**
ERC-20 que envuelve un activo **en la misma red**: un contrato custodia el activo y emite tokens 1:1, canjeables en cualquier momento. Ejemplo: WETH en Ethereum es ETH nativo guardado en el contrato WETH, expuesto como ERC-20 para que los DEX puedan usar `approve`/`transferFrom`. No requiere confiar en ningun bridge. En la practica "wrapped" tambien se usa para tokens bridged ("Wormhole wETH"); conviene preguntar si hay una o dos redes de por medio.

---

## Y

**Yield Farming**
Estrategia de depositar activos en protocolos DeFi para maximizar rendimientos, moviendo capital entre distintas oportunidades (lending, liquidity provision, staking).

---

## Z

**Zero-Knowledge Proof (ZKP)**
Prueba criptografica que permite demostrar que una afirmacion es verdadera sin revelar la informacion subyacente. Usada en ZK rollups, identidad privada y votacion anonima. Variantes: zk-SNARKs, zk-STARKs.
