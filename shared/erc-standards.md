# Guia de Estandares ERC

Referencia rapida de los principales estandares ERC (Ethereum Request for Comments) organizados por categoria. Cada ERC define una interfaz o convencion que los smart contracts pueden implementar para garantizar interoperabilidad.

> **ERC vs EIP**: Los ERCs son un subconjunto de los EIPs (Ethereum Improvement Proposals) enfocados en estandares de aplicacion (contratos, tokens, interfaces). Los EIPs cubren tambien cambios al protocolo base.

---

## Tokens Fungibles

**ERC-20** — Token Standard
El estandar fundamental para tokens fungibles. Define `transfer`, `approve`, `transferFrom`, `balanceOf`, `totalSupply` y `allowance`. Usado por la gran mayoria de tokens en Ethereum (USDC, DAI, UNI, LINK, etc.).

```
Funciones clave: transfer, approve, transferFrom, balanceOf, totalSupply, allowance
Eventos: Transfer, Approval
```

**ERC-2612** — Permit (Gasless Approvals)
Extension de ERC-20 que permite aprobar tokens via firma off-chain (EIP-712) en lugar de una transaccion on-chain. El usuario firma un mensaje y un tercero ejecuta el `permit`, eliminando la necesidad de una transaccion de `approve` separada.

```
Funcion clave: permit(owner, spender, value, deadline, v, r, s)
Beneficio: Aprobacion en 1 tx en vez de 2 (approve + transferFrom)
```

---

## Tokens No Fungibles (NFTs)

**ERC-721** — Non-Fungible Token Standard
Estandar para tokens unicos (NFTs). Cada token tiene un ID unico y un unico propietario. Incluye mecanismo de safe transfer que verifica si el receptor puede manejar NFTs.

```
Funciones clave: ownerOf, safeTransferFrom, approve, getApproved, setApprovalForAll
Eventos: Transfer, Approval, ApprovalForAll
```

**ERC-1155** — Multi-Token Standard
Estandar multi-token que permite manejar tokens fungibles y no fungibles en un solo contrato. Soporta transferencias batch, reduciendo gas significativamente en operaciones con multiples tokens.

```
Funciones clave: balanceOf, balanceOfBatch, safeTransferFrom, safeBatchTransferFrom
Beneficio: Un contrato para multiples tipos de token
```

---

## Extensiones de Tokens

**ERC-4626** — Tokenized Vault Standard
Interfaz estandar para vaults que aceptan depositos de un token subyacente y emiten shares proporcionales. Facilita composabilidad entre protocolos DeFi (Yearn, Aave, etc.) al unificar la interfaz de deposito/retiro.

```
Funciones clave: deposit, mint, withdraw, redeem, convertToShares, convertToAssets
Patron: deposit(assets) -> shares | redeem(shares) -> assets
```

**ERC-5192** — Minimal Soulbound NFTs
Extension minimal de ERC-721 para tokens no-transferibles (Soulbound Tokens). Agrega una funcion `locked()` que retorna si un token esta bloqueado para transferencia.

```
Funcion clave: locked(tokenId) -> bool
Evento: Locked(tokenId), Unlocked(tokenId)
Uso: Credenciales, reputacion, membresías no-vendibles
```

**ERC-5169** — Client Script URI
Permite asociar un script ejecutable del lado del cliente a un token, habilitando funcionalidad interactiva directamente desde el contrato.

---

## Identidad y Cuentas

**ERC-725** — General Identity
Estandar de identidad basado en proxy que permite almacenar datos key-value y ejecutar acciones a traves de un contrato. Base para identidades on-chain con capacidades extensibles.

```
Componentes: ERC-725X (ejecucion) + ERC-725Y (almacenamiento key-value)
Uso: Identidades auto-soberanas, perfiles on-chain
```

**ERC-1056** — Lightweight Ethereum DID
Registro de identidad DID (Decentralized Identifier) ligero para Ethereum. Permite crear, actualizar y delegar identidades sin desplegar un contrato por usuario.

```
Funcion clave: changeOwner, setAttribute, addDelegate, revokeDelegate
DID method: did:ethr
```

**ERC-4337** — Account Abstraction
Permite que las cuentas de usuario se comporten como smart contracts sin cambiar el protocolo. Habilita recuperacion social de llaves, pagos de gas por terceros (paymasters), y logica de autenticacion personalizada.

```
Componentes clave: UserOperation, EntryPoint, Bundlers, Paymasters
Beneficio: UX de Web2 con seguridad de Web3
```

---

## Infraestructura y Patrones

**ERC-165** — Standard Interface Detection
Permite a un contrato declarar que interfaces soporta. Otros contratos pueden consultar `supportsInterface(bytes4)` antes de llamar funciones.

```
Funcion: supportsInterface(interfaceId) -> bool
Uso: Verificar si un contrato es ERC-721, ERC-1155, etc.
```

**ERC-173** — Contract Ownership Standard
Estandar minimal de ownership. Define `owner()` y `transferOwnership()`. Base de OpenZeppelin `Ownable`.

```
Funciones: owner(), transferOwnership(newOwner)
Evento: OwnershipTransferred
```

**ERC-1967** — Proxy Storage Slots
Define slots de storage estandarizados para contratos proxy, evitando storage collisions entre proxy e implementacion. Usado por Transparent Proxy y UUPS.

```
Slots estandar:
  - Implementation: bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
  - Admin: bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
  - Beacon: bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)
```

**ERC-2535** — Diamond Standard (Multi-Facet Proxy)
Patron de proxy avanzado que permite a un contrato tener multiples implementaciones (facets). Cada facet maneja un subconjunto de funciones, permitiendo contratos modulares y actualizables sin limite de tamano.

```
Componentes: Diamond, DiamondCut, DiamondLoupe, Facets
Beneficio: Supera el limite de 24KB de bytecode
```

**ERC-1271** — Standard Signature Validation for Contracts
Permite que smart contracts (no solo EOAs) validen firmas. Necesario para account abstraction y para que contratos puedan actuar como firmantes.

```
Funcion: isValidSignature(hash, signature) -> bytes4
Uso: Wallets multisig, smart contract wallets, ERC-4337
```

---

## AI Agents

**ERC-8004** — Trustless Agents
Estandar para registrar, evaluar y validar agentes de IA on-chain. Define tres registries independientes que permiten construir un ecosistema de confianza para agentes autonomos.

```
Tres registries:

1. Identity Registry (ERC-721)
   - Registro de agentes como NFTs
   - Metadata key-value extensible
   - Agent wallet con firma EIP-712
   - URI apunta a registration file (JSON)

2. Reputation Registry
   - Feedback de clientes hacia agentes
   - value + decimals + tags para categorizacion
   - Revocacion y responses
   - getSummary con filtro anti-Sybil

3. Validation Registry
   - Requests de validacion a validators independientes
   - Responses con score 0-100
   - Soporta stake, zkML, TEE, etc.
   - Summaries por validator list

Propuesto por: MetaMask, Ethereum Foundation, Google, Coinbase
Estado: Review (2025)
```

---

## Tabla Resumen

| ERC | Nombre | Categoria | Estado | Uso principal |
|-----|--------|-----------|--------|---------------|
| ERC-20 | Token Standard | Tokens fungibles | Final | Tokens intercambiables (USDC, DAI) |
| ERC-165 | Interface Detection | Infraestructura | Final | Detectar interfaces soportadas |
| ERC-173 | Contract Ownership | Infraestructura | Final | Ownership basico de contratos |
| ERC-721 | Non-Fungible Token | NFTs | Final | Tokens unicos (arte, identidad) |
| ERC-725 | General Identity | Identidad | Draft | Identidad on-chain extensible |
| ERC-1056 | Lightweight DID | Identidad | Draft | DID sin deploy por usuario |
| ERC-1155 | Multi-Token | NFTs | Final | Multiples tokens en un contrato |
| ERC-1271 | Signature Validation | Infraestructura | Final | Firmas de smart contracts |
| ERC-1967 | Proxy Storage Slots | Infraestructura | Final | Slots estandar para proxies |
| ERC-2535 | Diamond Standard | Infraestructura | Final | Proxy multi-facet modular |
| ERC-2612 | Permit | Tokens fungibles | Final | Approvals gasless con firma |
| ERC-4337 | Account Abstraction | Identidad/Cuentas | Draft | Smart contract wallets, UX |
| ERC-4626 | Tokenized Vault | Extensiones | Final | Vaults DeFi estandarizados |
| ERC-5169 | Client Script URI | Extensiones | Draft | Scripts del lado cliente |
| ERC-5192 | Minimal Soulbound | Extensiones | Final | NFTs no-transferibles |
| ERC-8004 | Trustless Agents | AI Agents | Review | Agentes IA registrados on-chain |

---

## Como se relacionan

```
COMPOSABILIDAD DE ERCs:

  ERC-20 ──────────────> ERC-2612 (permit)
     |                      |
     v                      v
  ERC-4626 (vaults) ──> Protocolos DeFi (Aave, Yearn, etc.)


  ERC-721 ──────────────> ERC-5192 (soulbound)
     |                      |
     v                      v
  ERC-1155 (multi)      Identidad (SBTs, credenciales)
                            |
                            v
  ERC-725 + ERC-1056 ──> ERC-4337 (account abstraction)
                            |
                            v
                        ERC-8004 (AI agents)
                        Usa ERC-721 como base de identidad
                        + Reputation + Validation registries


  ERC-165 ──> Deteccion de interfaces (usado por todos)
  ERC-173 ──> Ownership (base de access control)
  ERC-1967 ──> Proxies (upgradability)
  ERC-2535 ──> Diamond (modularidad avanzada)
  ERC-1271 ──> Firmas de contratos (account abstraction)
```

---

## Recursos

- [Ethereum EIPs Repository](https://eips.ethereum.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) — Implementaciones auditadas de la mayoria de estos estandares
- [ERC-8004 Spec](https://eips.ethereum.org/EIPS/eip-8004) — Trustless Agents
