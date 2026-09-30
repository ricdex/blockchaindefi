# Modulo 05: Oracles and Bridges

## Objetivo

Entender como los smart contracts obtienen datos del mundo real (oracles) y como diferentes
blockchains se comunican entre si (bridges). Al finalizar este modulo seras capaz de:

- Explicar el **oracle problem** y por que es fundamental en DeFi
- Integrar **Chainlink Price Feeds** usando `AggregatorV3Interface`
- Entender **Chainlink VRF** para numeros aleatorios verificables
- Explicar por que un activo **nunca se mueve** entre redes y que hace realmente un bridge
- Seguir un deposito de ETH de Ethereum a Arbitrum: ETH bloqueado en L1, ETH nativo acreditado en L2
- Comprender la arquitectura de **bridges**: lock-and-mint, burn-and-mint y sus trust assumptions
- Desplegar un contrato en Arbitrum con Remix + MetaMask y rastrear que quedo guardado en Ethereum L1
- Identificar vulnerabilidades en oracles: stale data, oracle manipulation
- Construir un sistema de **collateral + liquidation** usando price feeds

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals
- Modulo 02: Tokens and Standards (ERC-20)
- Modulo 03: DeFi Primitives (lending, collateral)
- Modulo 04: Security Patterns (reentrancy, access control)
- Modulo 01, seccion 0 y Paso 8 (misma direccion en varias redes) y Modulo 02, seccion 0 (tipos de activo)

---

## Conceptos clave

### 1. El Oracle Problem

Los smart contracts viven en un entorno determinista y aislado. No pueden
hacer HTTP requests, leer APIs externas, ni acceder a datos fuera de la blockchain.

```
  Mundo real                  Blockchain
  +------------------+       +------------------+
  |  Precio ETH/USD  |       |  Smart Contract  |
  |  Clima           |  ???  |  necesita datos  |
  |  Resultados      |------>|  del mundo real  |
  |  deportivos      |       |  pero no puede   |
  |  ...             |       |  acceder a ellos |
  +------------------+       +------------------+

  Solucion: ORACLES
  +------------------+       +------------------+       +------------------+
  |  Fuentes de      |       |     Oracle       |       |  Smart Contract  |
  |  datos reales    |------>|  (intermediario  |------>|  lee datos del   |
  |                  |       |   on-chain)      |       |  oracle          |
  +------------------+       +------------------+       +------------------+
```

**El problema**: si el oracle provee datos incorrectos o es manipulado,
todo el sistema DeFi que depende de el colapsa.

---

### 2. Tipos de Oracles

| Tipo | Descripcion | Ejemplo |
|------|-------------|---------|
| **Centralized** | Un solo proveedor | API de un exchange |
| **Decentralized** | Red de nodos | Chainlink |
| **On-chain** | Calculado de datos on-chain | Uniswap TWAP |
| **Off-chain** | Datos de APIs externas | Chainlink Price Feeds |
| **Inbound** | Datos del mundo real -> blockchain | Precios, clima |
| **Outbound** | Blockchain -> mundo real | Notificaciones, pagos |

---

### 3. Chainlink Price Feeds

Chainlink es la solucion de oracle mas utilizada. Una red de nodos independientes
obtiene datos de multiples fuentes, los agrega y publica on-chain.

```
  +--------+   +--------+   +--------+
  | Node 1 |   | Node 2 |   | Node 3 |   ... N nodos
  | Binance|   | Coinbase|  | Kraken |
  +---+----+   +---+----+   +---+----+
      |            |             |
      v            v             v
  +--------------------------------------+
  |       Aggregator Contract            |
  |  (mediana de todas las respuestas)   |
  |                                      |
  |  latestRoundData() returns:          |
  |    - roundId                         |
  |    - answer (precio)                 |
  |    - startedAt                       |
  |    - updatedAt                       |
  |    - answeredInRound                 |
  +--------------------------------------+
              |
              v
  +--------------------------------------+
  |       Tu Smart Contract              |
  |  AggregatorV3Interface(feed)         |
  |    .latestRoundData()                |
  +--------------------------------------+
```

**Interface clave: AggregatorV3Interface**

```solidity
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,        // El precio (con decimals() decimales)
        uint256 startedAt,
        uint256 updatedAt,    // Timestamp de la ultima actualizacion
        uint80 answeredInRound
    );
}
```

**Ejemplo de uso seguro**:
```solidity
function getPrice(address feed) internal view returns (int256) {
    (
        uint80 roundId,
        int256 answer,
        ,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = AggregatorV3Interface(feed).latestRoundData();

    // Validaciones criticas:
    require(answer > 0, "Invalid price");
    require(updatedAt > 0, "Round not complete");
    require(answeredInRound >= roundId, "Stale price");
    require(block.timestamp - updatedAt < 3600, "Price too old");

    return answer;
}
```

---

### 4. Chainlink VRF (Verifiable Random Function)

Generar numeros aleatorios on-chain es imposible de forma determinista y segura.
Chainlink VRF provee aleatoriedad verificable criptograficamente.

```
  Tu Contrato                   Chainlink VRF
  +------------------+         +------------------+
  |                  |  1. requestRandomWords()    |
  | requestRandom()  |-------->| Genera numero    |
  |                  |         | aleatorio + proof |
  |                  |  2. fulfillRandomWords()    |
  | callback()       |<--------| Devuelve numero  |
  |                  |         | + prueba cripto   |
  +------------------+         +------------------+
```

**Usos**: loterias, NFT random traits, seleccion de jurados, gaming.

---

### 5. Bridges: por que un activo nunca "se mueve" entre redes

Empecemos por la idea que mas cuesta y que explica todo lo demas:

> **Un activo no puede salir de su red.** El ETH de Ethereum es un numero en el estado de Ethereum, y ninguna otra red puede escribir en ese estado. Lo que hace un bridge es **bloquear (o quemar) en una red y acreditar (o emitir) en otra**, y asegurar que ambas cosas se correspondan.

La pregunta de seguridad de cualquier bridge es siempre la misma: **quien le asegura a la red B que en la red A realmente se bloqueo algo?** De la respuesta depende todo el riesgo.

#### 5.1 Caso principal: el bridge canonico de Arbitrum (ETH)

Arbitrum es una L2 de Ethereum (la arquitectura completa esta en [architect/05-scalability](../../architect/05-scalability/)). Su bridge "oficial", el **canonico**, es un conjunto de contratos desplegados **en Ethereum L1**:

| Contrato en L1 | Rol | Arbitrum One | Arbitrum Sepolia |
|----------------|-----|--------------|------------------|
| `Inbox` | Puerta de entrada: recibe depositos y mensajes hacia L2 | `0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f` | `0xaAe29B0366299461418F5324a79Afc425BE5ae21` |
| `Bridge` | **La boveda**: aqui queda bloqueado todo el ETH depositado | `0x8315177aB297bA92A06054cE80a67Ed4DBd7ed3a` | `0x38f918D0E9F1b721EDaA41302E399fa1B79333a9` |
| `SequencerInbox` | Recibe los batches de transacciones de L2 (datos) | `0x1c479675ad559DC151F6Ec7ed3FbF8ceE79582B6` | `0x6c97864CE4bEf387dE0b3310A44230f7E3F1be0D` |
| `Outbox` | Puerta de salida: ejecuta retiros ya confirmados | `0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840` | `0x65f07C7D521164a4d5DaC6eB8Fac8DA067A3B78F` |

**Deposito (L1 → L2): lock en L1, credito nativo en L2**

```
  ETHEREUM L1 (Sepolia)                                ARBITRUM L2 (Arbitrum Sepolia)
  ┌──────────────────────────────────┐                ┌─────────────────────────────────┐
  │ 1. Alice llama                   │                │                                 │
  │    Inbox.depositEth()            │                │                                 │
  │    con value = 0.01 ETH          │                │                                 │
  │              │                   │                │                                 │
  │              ▼                   │  2. mensaje    │ 3. Los nodos de Arbitrum leen   │
  │    Bridge (boveda)               │ ─────────────> │    el mensaje de L1 y aplican   │
  │    balance: +0.01 ETH            │  (queda en L1) │    una tx de deposito:          │
  │    (bloqueado)                   │                │    balance[Alice] += 0.01 ETH   │
  │                                  │                │                                 │
  │ Alice en L1: -0.01 ETH (y gas)   │                │ Alice en L2: +0.01 ETH NATIVO   │
  └──────────────────────────────────┘                └─────────────────────────────────┘
```

Tres detalles que conviene tener claros:

- El ETH **sigue en Ethereum**, dentro del contrato `Bridge`. Puedes verlo con `cast balance` (en el laboratorio lo haras).
- En Arbitrum aparece **ETH nativo**, es decir, el activo que paga el gas, en el campo `balance` del estado de Arbitrum. **No** es un wETH ni un ERC-20. Esto es posible porque Arbitrum eligio el ETH como su activo nativo y lo respalda con la boveda de L1.
- El mensaje de deposito no depende de un grupo de validadores externos: esta escrito **en Ethereum**, y Arbitrum esta obligado a procesarlo (si el sequencer lo ignora, el usuario puede forzar su inclusion despues de un tiempo).

**Retiro (L2 → L1): burn en L2, liberacion en L1 despues del challenge period**

```
  ARBITRUM L2                                           ETHEREUM L1
  1. Alice llama ArbSys.withdrawEth(alice)
     con value = 0.01 ETH  → se quema en L2
                  │
  2. La tx va en un batch a L1, y un validador
     publica una "assertion" (el nuevo estado)
                  │
                  ▼
                                  3. Challenge period (~6.4 dias en Arbitrum One)
                                     Cualquiera puede disputar si el estado es falso
                                                      │
                                                      ▼
                                  4. Alice ejecuta Outbox.executeTransaction(...)
                                     Bridge libera 0.01 ETH a Alice en L1
```

El retiro tarda porque L1 tiene que **aceptar como definitivo el estado de L2** en el que se quemo el ETH, y eso solo pasa cuando nadie pudo demostrar que ese estado era falso.

#### 5.2 Tokens ERC-20 por el bridge canonico: aqui si hay "otra" direccion

Con un ERC-20 (por ejemplo USDC en L1), el bridge canonico usa contratos *gateway*: bloquea los tokens en L1 y **emite** en L2 un ERC-20 nuevo, con **otra direccion**, controlado por el bridge. Asi nacio el **USDC.e** de Arbitrum (`0xFF97...5CC8`), que viste en el modulo 02. Ese token es un *bridged token*: vale lo que vale el USDC bloqueado en L1.

#### 5.3 Los patrones generales

Todos los bridges son variaciones de estos dos patrones:

**Lock-and-Mint** (bloquear en origen, emitir una representacion en destino):
```
  Red A                                  Red B
  +-----------------+                   +---------------------------+
  |  Usuario envia  |                   |                           |
  |  100 USDC al    |  quien verifica   |  Contrato del bridge      |
  |  bridge (lock)  |  el lock? ------> |  emite 100 "USDC puenteado"|
  |                 |                   |  (un ERC-20 distinto)     |
  |  USDC bloqueado |                   |                           |
  +-----------------+                   +---------------------------+
```

> El caso del ETH en Arbitrum es un lock-and-mint especial: lo que se "emite" en destino no es un ERC-20 sino el **activo nativo** de la L2. Si el destino fuera una red cuyo activo nativo no es ETH (por ejemplo BNB Chain), el ETH llegaria como un ERC-20 envuelto (por ejemplo "Binance-Peg ETH"), porque alli el balance nativo es BNB.

**Burn-and-Mint** (quemar en origen, emitir en destino, sin boveda):
```
  Red A                                  Red B
  +-----------------+                   +-----------------+
  |  Usuario quema  |  atestacion del   |  El EMISOR      |
  |  100 USDC       |  emisor --------> |  emite 100 USDC |
  |  (burn)         |                   |  (mint)         |
  +-----------------+                   +-----------------+
```

Solo puede hacerlo quien tiene permiso de emitir en ambas redes, normalmente el propio emisor. Ejemplo: CCTP de Circle, que mueve el **USDC nativo** entre redes sin crear versiones bridged.

#### 5.4 Trust assumptions: quien verifica?

| Tipo de bridge | Quien asegura que el lock ocurrio | Ejemplo | Si falla... |
|----------------|-----------------------------------|---------|-------------|
| Canonico de un rollup | **El propio Ethereum**: el mensaje esta en L1 y el estado de L2 se disputa en L1 | Arbitrum Bridge | Tendria que fallar Ethereum o los contratos del rollup |
| Validadores externos (multisig) | Un grupo de firmantes | Ronin, Harmony Horizon | Si comprometen N de M llaves, roban la boveda |
| Emisor (burn-and-mint) | La entidad emisora | CCTP (USDC) | Confias en el emisor (ya confiabas, es su token) |

Por eso los grandes hacks de bridges (tabla de la seccion 6) fueron casi todos de bridges con validadores externos: la boveda de L1 estaba protegida por un punto de confianza mucho mas debil que la propia blockchain.

---

### 6. Vulnerabilidades de Oracles y Bridges

**Stale Oracle Data**:
```
// VULNERABLE: no verifica si el precio esta actualizado
(, int256 price, , , ) = feed.latestRoundData();
// Si el oracle no se actualiza en horas, el precio puede ser incorrecto

// SEGURO: verifica el timestamp
(, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();
require(block.timestamp - updatedAt < MAX_STALENESS, "Stale price");
```

**Oracle Manipulation**:
```
  Atacante con Flash Loan
  +---------------------------------------------+
  |  1. Pide prestado $100M en flash loan       |
  |  2. Swap masivo en Uniswap (mueve precio)   |
  |  3. Protocolo que usa Uniswap como oracle   |
  |     lee precio manipulado                    |
  |  4. Atacante explota el precio falso         |
  |  5. Devuelve el flash loan                   |
  +---------------------------------------------+

  Mitigacion: usar TWAP (Time-Weighted Average Price)
  o Chainlink (off-chain, no manipulable en una TX)
```

**Bridge Attacks** (historicos):
| Hack | Monto | Causa |
|------|-------|-------|
| Ronin Bridge (2022) | $625M | Validators comprometidos (5/9) |
| Wormhole (2022) | $326M | Bug en verificacion de firma |
| Nomad (2022) | $190M | Bug en inicializacion del proxy |
| Harmony Horizon (2022) | $100M | Multisig 2/5 comprometido |

---

## Ejercicio practico

### Proyecto: PriceFeedConsumer (Sistema de Collateral con Liquidacion)

Construir un sistema donde:
1. Usuarios depositan ETH como collateral
2. Pueden borrowear un monto en USD basado en el precio ETH/USD
3. Si el precio de ETH cae, la posicion se vuelve liquidatable
4. Cualquiera puede liquidar posiciones sub-collateralizadas
5. Stale price data causa revert

### Archivos del ejercicio

| Archivo | Descripcion |
|---------|-------------|
| `contracts/MockAggregatorV3.sol` | Mock de Chainlink para testing |
| `contracts/PriceFeedConsumer.sol` | Sistema de collateral + liquidacion |
| `test/PriceFeedConsumer.t.sol` | Tests completos del sistema |
| `contracts/ChainProbe.sol` | Contrato del laboratorio L1 → L2: "donde estoy?" visto desde la EVM |
| `contracts/MockArbSys.sol` | Simula el precompile ArbSys de Arbitrum en tests locales |
| `test/ChainProbe.t.sol` | Tests de ChainProbe (con y sin ArbSys simulado) |

### Ejecutar tests

```bash
forge test --match-path test/PriceFeedConsumer.t.sol -vvvv

# Todos los tests del modulo
forge test -vvv
```

---

## Laboratorio: de Ethereum L1 a Arbitrum L2, capa por capa

En este laboratorio vas a recorrer con tus propias manos el camino completo:

```
Ethereum L1 (Sepolia) ──bridge──> Arbitrum L2 (Arbitrum Sepolia) ──ETH para gas──> deploy de un contrato
                                                                                          │
         ¿que termina guardado en L1? <──────────── batch + assertion ─────────────────────┘
```

En cada paso vas a responder dos preguntas: **en que red ocurrio esto** y **que quedo guardado donde**. No hace falta memorizar nombres de contratos; lo importante es que al final puedas contar la historia capa por capa.

### Preparacion

- MetaMask con una cuenta **de pruebas** y las redes Sepolia y Arbitrum Sepolia configuradas (modulo 01, Paso 8.2)
- Un poco de SepoliaETH (0.05 alcanza). Faucets en [shared/testnet-setup.md](../../shared/testnet-setup.md)
- Foundry (`cast`) y un navegador con [Remix](https://remix.ethereum.org)

```bash
export ME=0xTU_DIRECCION_DE_METAMASK
export SEPOLIA_RPC=https://ethereum-sepolia-rpc.publicnode.com
export ARB_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc

# Contratos de Arbitrum Sepolia que viven en Sepolia (L1)
export INBOX=0xaAe29B0366299461418F5324a79Afc425BE5ae21
export BRIDGE=0x38f918D0E9F1b721EDaA41302E399fa1B79333a9
export SEQ_INBOX=0x6c97864CE4bEf387dE0b3310A44230f7E3F1be0D

# Precompiles de Arbitrum (direcciones fijas que solo existen en L2)
export ARB_SYS=0x0000000000000000000000000000000000000064
export NODE_INTERFACE=0x00000000000000000000000000000000000000C8
```

### Paso 1: Foto inicial (misma direccion, dos redes)

```bash
cast balance $ME --ether --rpc-url $SEPOLIA_RPC       # ej: 0.05  -> tienes SepoliaETH en L1
cast balance $ME --ether --rpc-url $ARB_SEPOLIA_RPC   # ej: 0     -> nada en L2
```

En MetaMask veras lo mismo al cambiar de red: **la misma direccion con dos balances**. Anota ambos numeros, porque los vas a comparar al final.

> **Comprueba tu modelo mental**: con 0 ETH en Arbitrum Sepolia, puedes desplegar un contrato alli? No. El gas de Arbitrum se paga con el ETH **nativo de Arbitrum**, y el que tienes en Sepolia no sirve para eso.

### Paso 2: Bridge (deposito L1 → L2)

Elige **una** de las dos opciones:

**Opcion A: interfaz web.** Entra a [bridge.arbitrum.io](https://bridge.arbitrum.io), activa el modo testnet en la configuracion, elige *Sepolia → Arbitrum Sepolia* y deposita 0.01 ETH. Firma con MetaMask en la red Sepolia.

**Opcion B: `cast` directo contra el contrato.** Asi ves exactamente que contrato recibe tu ETH. Necesitas la private key de tu cuenta de pruebas.

```bash
export KEY=0xTU_PRIVATE_KEY_DE_PRUEBAS    # solo una cuenta de testnet, nunca la personal

cast send $INBOX "depositEth()" --value 0.01ether \
  --private-key $KEY --rpc-url $SEPOLIA_RPC
```

Copia el hash de la transaccion y abrela en [sepolia.etherscan.io](https://sepolia.etherscan.io). Mira la pestaña **Internal Txns**: vas a ver que tus 0.01 ETH pasaron del `Inbox` al contrato **`Bridge`**. Ese es el "lock": tu ETH **no salio de Ethereum**, quedo guardado en una boveda en L1.

```bash
# La boveda guarda el ETH de TODOS los depositos de Arbitrum Sepolia
cast balance $BRIDGE --ether --rpc-url $SEPOLIA_RPC
```

### Paso 3: El ETH aparece en L2 (sin que nada "viaje")

Espera unos 10-15 minutos y vuelve a mirar:

```bash
cast balance $ME --ether --rpc-url $ARB_SEPOLIA_RPC   # ~0.01 -> ETH NATIVO en Arbitrum
cast balance $ME --ether --rpc-url $SEPOLIA_RPC       # ~0.04 -> lo que depositaste + gas ya no esta
```

Lo que paso por dentro fue esto: los nodos de Arbitrum **leen Ethereum**. Encontraron tu mensaje de deposito en L1 y, al procesarlo, sumaron 0.01 al campo `balance` de tu direccion **en el estado de Arbitrum**. En [sepolia.arbiscan.io](https://sepolia.arbiscan.io) la veras como una transaccion de deposito que **tu no firmaste en L2**: la genero el protocolo a partir del mensaje de L1.

| | Ethereum L1 (Sepolia) | Arbitrum L2 |
|---|---|---|
| Tu balance | -0.01 ETH (y el gas) | +0.01 ETH |
| Donde esta "el ETH de verdad" | Bloqueado en el contrato `Bridge` | Es un numero en el estado de L2, respaldado por la boveda |
| Que tipo de activo es | ETH nativo de L1 | ETH nativo de L2 (paga gas; **no** es un ERC-20) |

### Paso 4: Desplegar un contrato en Arbitrum con Remix

1. En [Remix](https://remix.ethereum.org) crea el archivo `ChainProbe.sol` y pega el contenido de [`contracts/ChainProbe.sol`](contracts/ChainProbe.sol).
2. Pestaña **Solidity Compiler**: version `0.8.20` o superior → *Compile*.
3. Pestaña **Deploy & Run Transactions**:
   - *Environment*: **Injected Provider - MetaMask**
   - En MetaMask selecciona **Arbitrum Sepolia**. Debajo del environment, Remix debe mostrar `Custom (421614) network`. **Si ves otro numero, estas desplegando en otra red.**
   - Argumento del constructor: `"hola desde L2"` → *Deploy* → confirma en MetaMask
4. En la ventana de MetaMask fijate que la comision se paga en **ETH de Arbitrum Sepolia**, el mismo que te llego por el bridge.
5. Copia la direccion del contrato desplegado y el hash de la transaccion de deploy:

```bash
export PROBE=0xDIRECCION_DEL_CONTRATO
export DEPLOY_TX=0xHASH_DEL_DEPLOY
```

> Si el deploy falla con un error de opcode invalido, en *Advanced Configurations* del compilador elige EVM version `cancun` y recompila.

### Paso 5: Donde existe este contrato?

```bash
cast code $PROBE --rpc-url $ARB_SEPOLIA_RPC    # 0x6080...  -> existe en Arbitrum
cast code $PROBE --rpc-url $SEPOLIA_RPC        # 0x         -> NO existe en Ethereum
```

El deploy escribio el bytecode en el estado **de Arbitrum**. Ethereum no tiene ninguna cuenta con ese codigo en esa direccion.

Ahora preguntale al propio contrato donde esta (en Remix, boton `whereAmI`, o con cast):

```bash
cast call $PROBE "whereAmI()(uint256,uint256,uint256,bool)" --rpc-url $ARB_SEPOLIA_RPC
# 421614        <- chainId: Arbitrum Sepolia
# 118114xx      <- block.number: fijate en este...
# 3141369xx     <- l2BlockNumber (ArbSys): el bloque real de L2
# true          <- isArbitrum

cast block-number --rpc-url $SEPOLIA_RPC       # 118114xx  <- ...es casi igual al bloque de SEPOLIA!
cast block-number --rpc-url $ARB_SEPOLIA_RPC   # 3141369xx <- el de L2 es otro numero
```

Aqui tienes una prueba de que estas en una L2: dentro de Arbitrum, `block.number` devuelve el bloque aproximado **de L1**, y el bloque propio de L2 hay que pedirselo al precompile `ArbSys`. **Arbitrum vive mirando el reloj de Ethereum.**

**Estado y activo nativo del contrato, solo en L2.** En Remix:

1. Llama a `writeNote("mi primer estado en L2")`.
2. Envia 0.001 ETH al contrato: arriba, en el campo *Value*, escribe `0.001` y elige la unidad `Ether`. Luego, en *Low level interactions* del contrato desplegado, deja *CALLDATA* vacio y haz click en *Transact*. Eso ejecuta `receive()`.

Luego verifica:

```bash
cast call $PROBE "note()(string)" --rpc-url $ARB_SEPOLIA_RPC   # "mi primer estado en L2"
cast balance $PROBE --ether --rpc-url $ARB_SEPOLIA_RPC        # 0.001
cast balance $PROBE --ether --rpc-url $SEPOLIA_RPC            # 0  (esa direccion en L1 no tiene nada)
```

> **Caso real: la misma direccion puede no ser tuya en otra red.** En junio de 2022, la Optimism Foundation envio 20M OP a la direccion de una multisig (Gnosis Safe) de Wintermute. Esa multisig existia en Ethereum, pero **todavia no estaba desplegada en Optimism**. Un atacante reprodujo el despliegue hasta obtener esa misma direccion en Optimism, se quedo como dueño y tomo los tokens. Una direccion de **contrato** solo es "tuya" en las redes donde la desplegaste. Recuerdalo con `cast code`.

Cuando termines, recupera el ETH del contrato con `sweep()` (solo el deployer puede llamarlo).

### Paso 6: Que termino guardado en Ethereum L1?

Tu contrato no existe en L1, pero L1 **si** guarda algo. Vamos a seguirle el rastro a tu transaccion de deploy.

**6.1 El recibo en L2 ya habla de L1**

```bash
cast receipt $DEPLOY_TX --rpc-url $ARB_SEPOLIA_RPC | grep -E "^(blockNumber|l1BlockNumber|gasUsedForL1|contractAddress)"
# blockNumber          314133497      <- bloque de L2
# contractAddress      0x...          <- tu ChainProbe
# gasUsedForL1         3411           <- gas que paga el espacio en L1
# l1BlockNumber        11811386       <- bloque de L1 de referencia
```

- `l1BlockNumber`: el bloque de L1 que el sequencer tenia como referencia.
- `gasUsedForL1`: la parte de tu comision que paga el **costo de publicar tus datos en L1**. En una L2, la comision tiene dos partes: la ejecucion en L2, que es barata, y el espacio en L1.

**6.2 En que batch viajo tu transaccion?**

El sequencer agrupa miles de transacciones de L2, las comprime y las publica en L1 en un **batch**.

```bash
export L2_BLOCK=$(cast receipt $DEPLOY_TX blockNumber --rpc-url $ARB_SEPOLIA_RPC)

cast call $NODE_INTERFACE "findBatchContainingBlock(uint64)(uint64)" $L2_BLOCK --rpc-url $ARB_SEPOLIA_RPC
# ej: 858998   <- numero de batch
# Si revierte: tu bloque todavia no se publico en L1. Espera unos minutos y reintenta.

export BATCH=858998   # el numero que obtuviste
```

**6.3 Encontrar la transaccion de L1 que publico ese batch**

```bash
export L1_REF=11811386   # el l1BlockNumber que viste en 6.1

cast logs --from-block $L1_REF --to-block $(( L1_REF + 1500 )) --address $SEQ_INBOX \
  "SequencerBatchDelivered(uint256 indexed,bytes32 indexed,bytes32 indexed,bytes32,uint256,(uint64,uint64,uint64,uint64),uint8)" \
  $(cast to-uint256 $BATCH) --rpc-url $SEPOLIA_RPC | grep -E "transactionHash|blockNumber"

export BATCH_TX=0x...   # el transactionHash que aparecio
```

Inspecciona esa transaccion **de L1**:

```bash
cast tx $BATCH_TX --rpc-url $SEPOLIA_RPC | grep -E "^(type|from|to)"
# type 3                       <- transaccion con BLOBS (EIP-4844)
# to   0x6c97...be0D           <- SequencerInbox (contrato de Arbitrum en L1)

cast 4byte $(cast tx $BATCH_TX input --rpc-url $SEPOLIA_RPC | cut -c1-10)
# addSequencerL2BatchFromBlobs(uint256,uint256,address,uint256,uint256)
```

Tu transaccion de deploy, **incluido el bytecode de ChainProbe**, esta en algun lugar de esos blobs: comprimida y mezclada con miles de transacciones de otras personas. Fijate en la diferencia entre dos cosas:

- **Los datos** de tu deploy si llegaron a L1, y por eso cualquiera puede reconstruir el estado de Arbitrum.
- **El contrato** no existe en L1: Ethereum no ejecuto tu deploy ni creo una cuenta para el. Solo guardo los datos para que otros puedan verificar.

Los blobs se borran de los nodos de Ethereum despues de ~18 dias. En L1 queda para siempre el **compromiso criptografico** (el `blobVersionedHash`), y los datos completos quedan en los nodos de Arbitrum y en archivadores. Lo importante es que estuvieron disponibles publicamente el tiempo suficiente para que cualquiera pudiera verificarlos o disputarlos.

**6.4 Cuantas confirmaciones de L1 tiene tu bloque?**

```bash
export L2_HASH=$(cast receipt $DEPLOY_TX blockHash --rpc-url $ARB_SEPOLIA_RPC)
cast call $NODE_INTERFACE "getL1Confirmations(bytes32)(uint64)" $L2_HASH --rpc-url $ARB_SEPOLIA_RPC
# ej: 625  <- bloques de L1 construidos encima del batch que contiene tu bloque
```

Mientras ese numero crece, tu deploy es tan dificil de revertir como el bloque de Ethereum donde quedo el batch.

**6.5 La ultima pieza: la assertion (el estado)**

Los batches son **datos** (que transacciones ocurrieron). Por separado, los validadores de Arbitrum publican en el contrato `Rollup` de L1 **assertions**: compromisos sobre el estado resultante de L2 despues de ejecutar esos batches. Cada assertion queda abierta un tiempo (el challenge period) durante el cual cualquiera puede disputarla. Pasado ese tiempo, L1 la acepta como definitiva.

```bash
export ROLLUP=$(cast call $BRIDGE "rollup()(address)" --rpc-url $SEPOLIA_RPC)
cast call $ROLLUP "confirmPeriodBlocks()(uint64)" --rpc-url $SEPOLIA_RPC
# 20     <- en Arbitrum Sepolia, ~4 minutos de L1 (testnet)
# En Arbitrum One el mismo valor es 45818 bloques (~6.4 dias)
```

### Resumen: que quedo en cada capa

| Cosa | Arbitrum L2 | Ethereum L1 |
|------|-------------|-------------|
| Tu balance de ETH en L2 | Si (en el estado de L2) | No. Solo esta el ETH bloqueado en `Bridge` que lo respalda |
| Bytecode de ChainProbe como contrato ejecutable | Si | **No** (`cast code` = `0x`) |
| Storage de ChainProbe (`note`) | Si | No |
| Ejecucion de `writeNote` | Si, la hizo el sequencer | No. L1 no ejecuta nada salvo en una disputa (y solo un paso) |
| Datos comprimidos de tus transacciones | Si | Si, en blobs del batch (temporales, ~18 dias) |
| Compromiso sobre el estado de L2 (assertion) | — | Si, en el contrato `Rollup` |
| Mensaje de tu deposito | Procesado | Si, registrado en el `Inbox`/`Bridge` |

La frase que resume el laboratorio: **L2 ejecuta y guarda el estado; L1 guarda los datos, la boveda y la ultima palabra sobre que estado es valido.** El porque de este diseño esta en [architect/05-scalability, seccion 4.1](../../architect/05-scalability/).

### Explicalo con tus palabras

1. Si mañana Arbitrum apagara todos sus servidores, donde esta tu ETH de L2? Como lo recuperarias en teoria?
2. Por que el deposito tardo minutos y el retiro tardaria ~6.4 dias en Arbitrum One?
3. Un amigo dice: "Arbitrum guarda todo en Ethereum, asi que mi contrato tambien esta en Ethereum". Que parte es correcta y que parte no?
4. Por que en Arbitrum `block.number` se parece al bloque de Sepolia?

<details>
<summary>Respuestas</summary>

1. El ETH "de verdad" esta bloqueado en el contrato `Bridge` de L1. Los datos de todas las transacciones estan (o estuvieron) publicados en L1, asi que cualquiera puede reconstruir el estado de L2, publicar una assertion y retirar por el `Outbox`. Esa es la diferencia con una cadena independiente: alli, si se apagan los validadores, no hay nada en otra red que te respalde.
2. Para acreditar un deposito, L2 solo necesita leer un mensaje que ya esta en L1. Para liberar un retiro, en cambio, **L1** tiene que aceptar como valido un estado de L2, y eso requiere que pase el challenge period sin disputas exitosas.
3. Correcto: los **datos** de su deploy se publicaron en L1. Incorrecto: el contrato no existe en L1, que ni lo ejecuto ni guarda su storage. Compruebalo con `cast code`.
4. Porque Arbitrum expone en `block.number` el bloque de L1 que el sequencer usa como referencia. Muchos contratos usan `block.number` como reloj, y asi se comportan igual que en Ethereum. El bloque de L2 se obtiene con `ArbSys.arbBlockNumber()`.

</details>

### Opcional: retirar de vuelta a L1

Desde [bridge.arbitrum.io](https://bridge.arbitrum.io), en modo testnet, retira una parte de tu ETH de Arbitrum Sepolia a Sepolia. Veras dos transacciones: la de L2 (que quema el ETH con `ArbSys.withdrawEth`) y, cuando la assertion se confirme, la de *Claim* en L1 (que ejecuta el `Outbox` y libera el ETH del `Bridge`). En Arbitrum Sepolia el challenge period es corto; en Arbitrum One tendrias que esperar ~6.4 dias o usar un bridge de terceros (a cambio de otro modelo de confianza).

---

## Vulnerabilidades relevantes

| Vulnerabilidad | Impacto | Ejemplo |
|----------------|---------|---------|
| Stale oracle data | Precios incorrectos, liquidaciones injustas | Multiples protocolos |
| Oracle manipulation via flash loan | Drenaje total del protocolo | bZx, Harvest Finance |
| No validar answer > 0 | Precio 0 o negativo causa estragos | Edge cases |
| Confiar en un solo oracle | Single point of failure | LUNA crash |
| Bridge validator compromise | Robo total de fondos bridgeados | Ronin, Harmony |
| Bridge smart contract bug | Mint infinito de tokens | Wormhole, Nomad |
| Enviar fondos a una direccion de contrato que no existe en esa red | Otra persona puede desplegar en esa direccion y quedarse los fondos | Wintermute / Optimism (2022) |
| Confundir el token bridged con el nativo (mismo simbolo) | Recibir un activo con otro riesgo o sin liquidez | USDC.e vs USDC en Arbitrum |

---

## Recursos

- [Chainlink Price Feeds - Documentacion oficial](https://docs.chain.link/data-feeds/price-feeds)
- [Chainlink VRF - Documentacion oficial](https://docs.chain.link/vrf)
- [Chainlink Data Feeds - Contratos en cada network](https://docs.chain.link/data-feeds/price-feeds/addresses)
- [The Oracle Problem - Chainlink Blog](https://chain.link/education-hub/oracle-problem)
- [samczsun - Oracle Manipulation Attacks](https://samczsun.com/so-you-want-to-use-a-price-oracle/)
- [Rekt - Ronin Bridge Postmortem](https://rekt.news/ronin-rekt/)
- [Rekt - Wormhole Postmortem](https://rekt.news/wormhole-rekt/)
- [L2Beat - Bridge Risk Assessment](https://l2beat.com/bridges/summary)
- [Arbitrum Docs - How the bridge works (deposits & withdrawals)](https://docs.arbitrum.io/how-arbitrum-works/deep-dives/l1-to-l2-messaging)
- [Arbitrum Docs - Solidity differences (block.number, ArbSys)](https://docs.arbitrum.io/build-decentralized-apps/arbitrum-vs-ethereum/solidity-support)
- [Arbitrum Docs - NodeInterface](https://docs.arbitrum.io/build-decentralized-apps/nodeinterface/overview)
- [EIP-4337: Account Abstraction (context for bridge UX)](https://eips.ethereum.org/EIPS/eip-4337)
- [Uniswap TWAP Oracle](https://docs.uniswap.org/concepts/protocol/oracle)

---

## Checkpoint

Antes de continuar al modulo 06, verifica que puedes:

- [ ] Explicar el oracle problem con un diagrama
- [ ] Describir como funciona Chainlink Price Feeds (nodos, aggregator, interface)
- [ ] Implementar una lectura segura de `latestRoundData()` con todas las validaciones
- [ ] Explicar que es Chainlink VRF y cuando usarlo
- [ ] Explicar por que un activo no puede "moverse" de una red a otra y que hace realmente un bridge
- [ ] Describir la diferencia entre lock-and-mint y burn-and-mint bridges
- [ ] Explicar por que el ETH depositado en Arbitrum llega como ETH **nativo** y no como wETH
- [ ] Identificar las trust assumptions de un bridge (canonico vs validadores externos vs emisor)
- [ ] Completar el laboratorio L1 → L2: deposito, deploy con Remix, `cast code` en ambas redes y rastreo del batch en L1
- [ ] Llenar de memoria la tabla "que quedo en cada capa" del laboratorio
- [ ] Explicar como un flash loan puede manipular un oracle on-chain
- [ ] Explicar por que Chainlink es resistente a manipulacion en una sola transaccion
- [ ] Implementar un check de stale price data
- [ ] Pasar todos los tests del modulo: `forge test -vvv`
- [ ] Depositar collateral, borrowear, y liquidar en tu PriceFeedConsumer
