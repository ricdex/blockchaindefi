# Modulo 05: Oracles and Bridges

## Objetivo

Entender como los smart contracts obtienen datos del mundo real (oracles) y como diferentes
blockchains se comunican entre si (bridges). Al finalizar este modulo seras capaz de:

- Explicar el **oracle problem** y por que es fundamental en DeFi
- Integrar **Chainlink Price Feeds** usando `AggregatorV3Interface`
- Entender **Chainlink VRF** para numeros aleatorios verificables
- Comprender la arquitectura de **bridges**: lock-and-mint, burn-and-mint
- Identificar vulnerabilidades en oracles: stale data, oracle manipulation
- Construir un sistema de **collateral + liquidation** usando price feeds

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals
- Modulo 02: Tokens and Standards (ERC-20)
- Modulo 03: DeFi Primitives (lending, collateral)
- Modulo 04: Security Patterns (reentrancy, access control)

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

### 5. Bridges

Los bridges permiten mover activos y datos entre diferentes blockchains.

**Lock-and-Mint**:
```
  Chain A                               Chain B
  +-----------------+                  +-----------------+
  |  Usuario envia  |                  |                 |
  |  10 ETH al      |  Relayer /      |  Bridge minta   |
  |  Bridge (lock)  |  Validator      |  10 wETH al     |
  |                 |  ------------>  |  usuario        |
  |  ETH bloqueado  |                  |  (mint)         |
  +-----------------+                  +-----------------+
```

**Burn-and-Mint**:
```
  Chain A                               Chain B
  +-----------------+                  +-----------------+
  |  Usuario quema  |                  |                 |
  |  10 tokenA      |  Relayer /      |  Bridge minta   |
  |  (burn)         |  Validator      |  10 tokenB      |
  |                 |  ------------>  |  (mint)         |
  +-----------------+                  +-----------------+
```

**Trust assumptions de bridges**:
- Confiar en el relayer / validator set
- Confiar en los smart contracts de ambas chains
- Confiar en que los fondos lockeados no seran robados

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

### Ejecutar tests

```bash
forge test --match-path test/PriceFeedConsumer.t.sol -vvvv

# Todos los tests del modulo
forge test -vvv
```

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
- [EIP-4337: Account Abstraction (context for bridge UX)](https://eips.ethereum.org/EIPS/eip-4337)
- [Uniswap TWAP Oracle](https://docs.uniswap.org/concepts/protocol/oracle)

---

## Checkpoint

Antes de continuar al modulo 06, verifica que puedes:

- [ ] Explicar el oracle problem con un diagrama
- [ ] Describir como funciona Chainlink Price Feeds (nodos, aggregator, interface)
- [ ] Implementar una lectura segura de `latestRoundData()` con todas las validaciones
- [ ] Explicar que es Chainlink VRF y cuando usarlo
- [ ] Describir la diferencia entre lock-and-mint y burn-and-mint bridges
- [ ] Identificar las trust assumptions de un bridge
- [ ] Explicar como un flash loan puede manipular un oracle on-chain
- [ ] Explicar por que Chainlink es resistente a manipulacion en una sola transaccion
- [ ] Implementar un check de stale price data
- [ ] Pasar todos los tests del modulo: `forge test -vvv`
- [ ] Depositar collateral, borrowear, y liquidar en tu PriceFeedConsumer
