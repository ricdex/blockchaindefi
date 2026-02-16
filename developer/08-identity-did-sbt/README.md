# Modulo 08: Identity, DID and Soulbound Tokens (SBT)

## Objetivo

Al completar este modulo seras capaz de:

- Entender Decentralized Identity (DID) y el estandar W3C
- Comprender el concepto de DID Document: id, authentication methods, service endpoints
- Implementar Soulbound Tokens (SBT): NFTs no-transferibles basados en ERC-5192
- Entender Verifiable Credentials y el triangulo issuer-holder-verifier
- Identificar use cases: credenciales academicas, reputacion, KYC attestation
- Reconocer vulnerabilidades: privacidad on-chain, revocacion, key management
- Construir un sistema de credenciales academicas con SBTs

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (tipos, storage, modifiers, events)
- Modulo 02: Tokens and Standards (ERC-721 basico)
- Modulo 04: Security Patterns (access control)
- Foundry instalado y funcional

---

## Conceptos clave

### 1. El problema de la identidad digital

La identidad digital tradicional depende de autoridades centrales que emiten, controlan y pueden revocar tu identidad:

```
IDENTIDAD CENTRALIZADA:

  +----------+     +------------------+     +----------+
  | Usuario  |---->| Autoridad Central|---->| Servicio |
  | (tu)     |     | (Google, Govt)   |     | (app)    |
  +----------+     +------------------+     +----------+
                          |
                   Problemas:
                   - Single point of failure
                   - Data silos (cada servicio tiene tu data)
                   - Censura (te pueden bloquear)
                   - Privacidad (la autoridad ve todo)
                   - Portabilidad (no puedes mover tu identidad)


IDENTIDAD DESCENTRALIZADA (DID):

  +----------+     +------------------+     +----------+
  | Usuario  |---->| Blockchain /     |---->| Servicio |
  | (tu)     |     | Red P2P          |     | (verifier)|
  +----------+     +------------------+     +----------+
       |                                         |
       |  Tu controlas tus llaves                |
       |  Tu decides que compartir               |
       +--- Self-sovereign identity ---          |
       |                                         |
       +----- Verifiable Credentials ------->----+
              (pruebas criptograficas)
```

### 2. DID (Decentralized Identifier) - W3C Standard

Un DID es un identificador unico y descentralizado que no depende de ninguna autoridad central:

```
FORMATO DID:

  did:ethr:0x1234...5678
  |   |    |
  |   |    +-- Identifier especifico del metodo
  |   +------- DID Method (ethereum, web, key, etc.)
  +----------- Esquema DID (siempre "did")

EJEMPLOS:
  did:ethr:0xf3beac30c498d9e26865f34fcaa57dbb935b0d74
  did:web:example.com
  did:key:z6MkhaXg...
```

### 3. DID Document

El DID Document es un documento JSON-LD que describe al sujeto del DID:

```
DID DOCUMENT (simplificado):

{
  "id": "did:ethr:0x1234...5678",

  "authentication": [
    {
      "type": "EcdsaSecp256k1RecoveryMethod2020",
      "controller": "did:ethr:0x1234...5678",
      "blockchainAccountId": "eip155:1:0x1234...5678"
    }
  ],

  "service": [
    {
      "type": "LinkedDomains",
      "serviceEndpoint": "https://example.com"
    },
    {
      "type": "CredentialRegistry",
      "serviceEndpoint": "https://credentials.example.com"
    }
  ]
}

COMPONENTES:
+---------------------+------------------------------------------+
| Campo               | Descripcion                              |
+---------------------+------------------------------------------+
| id                  | El DID del sujeto                        |
| authentication      | Metodos para autenticarse como el sujeto |
| assertionMethod     | Metodos para emitir claims               |
| service             | Endpoints de servicios asociados         |
| verificationMethod  | Llaves publicas del sujeto               |
+---------------------+------------------------------------------+
```

### 4. Soulbound Tokens (SBT)

Los SBTs son tokens no-transferibles propuestos por Vitalik Buterin en el paper "Decentralized Society" (2022). Representan compromisos, credenciales y afiliaciones.

```
NFT NORMAL vs SOULBOUND TOKEN:

  NFT (ERC-721):
  +--------+    transfer()    +--------+
  | Alice  |----------------->|  Bob   |
  | tokenId|                  | tokenId|
  +--------+                  +--------+
  Transferible, vendible, tradeable

  SBT (Soulbound):
  +--------+    transfer()    +--------+
  | Alice  |-------X--------->|  Bob   |
  | tokenId|    REVERT!       |        |
  +--------+                  +--------+
  No-transferible, bound to the soul (address)


ERC-5192 (Minimal Soulbound NFTs):

  Extiende ERC-721 con:
  - locked(tokenId) -> bool  // siempre true para SBTs
  - event Locked(tokenId)    // emitido al mintear
  - transferFrom() -> REVERT // siempre
  - safeTransferFrom() -> REVERT // siempre
```

```
POR QUE SBTs:

  +----------------------------------------------------------+
  | Use Case              | Como funciona                     |
  +----------------------------------------------------------+
  | Diploma universitario | Universidad mintea SBT al alumno |
  | Certificacion         | Issuer mintea SBT al holder      |
  | Reputacion            | Protocolo mintea SBT por accion  |
  | KYC attestation       | KYC provider mintea SBT          |
  | Membership            | DAO mintea SBT a miembros        |
  | Proof of attendance   | Evento mintea POAP-SBT           |
  +----------------------------------------------------------+
  Ninguno de estos deberia ser vendible o transferible.
```

### 5. Verifiable Credentials

Las Verifiable Credentials (VC) son el estandar W3C para credenciales digitales verificables:

```
TRIANGULO DE VERIFIABLE CREDENTIALS:

          +----------+
          |  Issuer  |  (Universidad, Gobierno, Empresa)
          +----+-----+
               |
               | Emite credencial
               v
          +----------+
          |  Holder  |  (Estudiante, Ciudadano, Empleado)
          +----+-----+
               |
               | Presenta credencial
               v
          +----------+
          | Verifier |  (Empleador, Servicio, DAO)
          +----------+

FLUJO:

  1. ISSUER emite credencial al HOLDER
     - "Alice completo el grado de CS en MIT"
     - Firmada criptograficamente por MIT
     - Almacenada por Alice (no por MIT)

  2. HOLDER presenta credencial al VERIFIER
     - Alice muestra su credencial a un empleador
     - Solo comparte lo necesario (zero-knowledge posible)

  3. VERIFIER verifica la credencial
     - Verifica la firma del issuer
     - Verifica que no esta revocada
     - Verifica que no esta expirada
     - No necesita contactar al issuer


ON-CHAIN CON SBTs:

  +----------+     mintSBT()      +----------+
  |  Issuer  |------------------->|  Holder  |
  | (authzd) |                    | (wallet) |
  +----------+                    +----+-----+
                                       |
  +----------+     verifySBT()         |
  | Verifier |<------------------------+
  | (anyone) |  ownerOf(tokenId) != 0
  +----------+  + credential data on-chain/IPFS
```

### 6. Credential Registry Pattern

```
CREDENTIAL REGISTRY:

  +------------------------------------------------------------------+
  |                     CredentialRegistry                            |
  |                                                                   |
  |  +-------------------+                                            |
  |  | Credential Types  |  "Bachelor CS", "Solidity Cert", etc.     |
  |  | (registered)      |                                            |
  |  +-------------------+                                            |
  |           |                                                       |
  |           v                                                       |
  |  +-------------------+                                            |
  |  | Authorized Issuers|  MIT, Consensys Academy, etc.             |
  |  | (per type)        |  mapping(typeId => mapping(issuer => bool))|
  |  +-------------------+                                            |
  |           |                                                       |
  |           v                                                       |
  |  +-------------------+      +-------------------+                |
  |  | Issue Credential  |----->| SoulboundToken    |                |
  |  | (mint SBT)        |      | (ERC-721 locked)  |                |
  |  +-------------------+      +-------------------+                |
  |           |                                                       |
  |           v                                                       |
  |  +-------------------+                                            |
  |  | Verify / Revoke   |                                            |
  |  +-------------------+                                            |
  +------------------------------------------------------------------+
```

---

## Ejercicio practico: Academic Credential System

### Descripcion

Implementa un sistema de credenciales academicas usando Soulbound Tokens. El sistema tiene dos contratos:
1. **SoulboundToken**: ERC-721 no-transferible que representa una credencial
2. **CredentialRegistry**: Registro que gestiona tipos de credenciales, issuers autorizados, y la emision/revocacion de credenciales

### Arquitectura

```
+-------------------------------------------------------------------+
|                   Academic Credential System                       |
|                                                                    |
|  +------------------+     +----------------------------+           |
|  | CredentialRegistry|     | SoulboundToken (ERC-721)  |           |
|  |                  |     |                            |           |
|  | - credTypes[]    |---->| - Non-transferable         |           |
|  | - issuers[]      |     | - tokenId -> credData      |           |
|  | - issue()        |     | - mint() only by registry  |           |
|  | - revoke()       |     | - burn() by holder/registry|           |
|  | - verify()       |     |                            |           |
|  +------------------+     +----------------------------+           |
+-------------------------------------------------------------------+

FLUJO:

  1. Admin registra tipo de credencial ("Bachelor CS")
  2. Admin autoriza issuer (MIT) para ese tipo
  3. MIT llama issue() -> SBT minteado al estudiante
  4. Cualquiera puede verificar: verify(student, typeId) -> bool
  5. MIT puede revocar: revoke(tokenId) -> SBT quemado
  6. Estudiante puede quemar su propio SBT (derecho al olvido)
```

### Archivos

- `contracts/SoulboundToken.sol` - ERC-721 no-transferible
- `contracts/CredentialRegistry.sol` - Registro de credenciales y issuers
- `test/CredentialSystem.t.sol` - tests completos del sistema

---

## DID en redes privadas vs publicas

Hasta ahora hemos trabajado con DID y SBTs en Anvil (nodo local). Pero en la practica, los sistemas de identidad se despliegan en redes reales — y la eleccion de red tiene implicaciones profundas.

### Comparativa

```
+---------------------+---------------------------+---------------------------+
| Dimension           | Red publica (Sepolia/L2)  | Red privada (Besu)        |
+---------------------+---------------------------+---------------------------+
| Gas cost            | Variable, puede ser alto  | Cero o nominal            |
| Visibilidad datos   | Todo es publico           | Solo participantes autorizados |
| Finality            | ~12s (PoS) + confirmations| ~2s (IBFT 2.0, inmediata) |
| Resistencia censura | Alta (permissionless)     | Depende del consorcio     |
| Resolucion DID      | Cualquiera puede resolver | Solo miembros de la red   |
| Interoperabilidad   | Maxima (ecosistema EVM)   | Limitada al consorcio     |
| Regulacion          | Dificil de cumplir        | Control total             |
| Caso de uso ideal   | Identidad publica,        | Identidad enterprise,     |
|                     | credenciales verificables | KYC interno, compliance   |
|                     | por cualquiera            | regulatorio               |
+---------------------+---------------------------+---------------------------+
```

### Patron: DID Bridge (hibrido)

El patron mas poderoso combina ambos mundos: operaciones frecuentes en red privada, verificacion publica via merkle root.

```
   DID BRIDGE PATTERN
   ====================

   Red privada (Besu)                   Red publica (Sepolia/L2)
   +---------------------------+        +---------------------------+
   | CredentialRegistry        |        | MerkleRootAnchor          |
   | - register types          |        | - anchored merkle root    |
   | - issue credentials       |        | - verifyProof(proof, leaf)|
   | - revoke credentials      |        |                           |
   | - full DID documents      |        | Cualquiera puede verificar|
   +---------------------------+        | sin acceso a red privada  |
              |                         +---------------------------+
              | Periodicamente:                  ^
              | 1. Calcular merkle root          |
              |    de todos los DIDs activos     |
              | 2. Publicar root en red publica  |
              +--------------------------------->+
              |
   Verificacion:
   1. Holder obtiene merkle proof de red privada
   2. Verifier chequea proof contra root en red publica
   3. No necesita acceso a la red privada
```

## Como ejecutar

### Paso 0: Inicializar el proyecto Foundry

Si el proyecto no tiene `foundry.toml` ni `lib/` (estado limpio):

```bash
cd developer/08-identity-did-sbt

cp README.md README.md.bak
forge init --no-git --force
mv README.md.bak README.md
rm -rf src/ script/
rm -f test/Counter.t.sol

git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std
rm -rf lib/forge-std/.git
```

Edita `foundry.toml`:

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
```

### Paso 1: Compilar y testear

```bash
forge build
forge test -vv
```

### Paso 2: Deploy en Anvil

**Terminal 1: Levantar Anvil**

```bash
anvil
```

**Terminal 2: Configurar variables y desplegar**

```bash
export PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export RPC=http://localhost:8545
```

**Desplegar CredentialRegistry primero (para obtener su address):**

```bash
forge create contracts/CredentialRegistry.sol:CredentialRegistry \
  --rpc-url $RPC \
  --private-key $PK \
  --broadcast \
  --constructor-args $ADMIN
```

> Nota: se pasa `$ADMIN` como placeholder del SoulboundToken address. En produccion
> esto se resolveria con un patrón de deploy en dos pasos o prediccion de address.

Desglose del comando:

```
forge create contracts/CredentialRegistry.sol:CredentialRegistry
│            │                                │
│            │                                └─ Nombre del contrato (linea 91 de CredentialRegistry.sol)
│            └─ Ruta al archivo .sol
└─ Comando de Foundry para desplegar

  --broadcast                 Envia la transaccion a la red (sin esto, solo simula)

  --constructor-args $ADMIN
                     │
                     └─ _soulboundToken (linea 91: address _soulboundToken)
                        Ejecuta el constructor que guarda admin = msg.sender (linea 92)
                        y vincula el SoulboundToken (linea 93)
```

Del output, copiar `Deployed to:`:

```bash
export REGISTRY=0x...  # Deployed to del output
```

**Desplegar SoulboundToken apuntando al Registry:**

```bash
forge create contracts/SoulboundToken.sol:SoulboundToken \
  --rpc-url $RPC \
  --private-key $PK \
  --broadcast \
  --constructor-args "Academic Credentials" "ACRED" $REGISTRY
```

Desglose del comando:

```
  --constructor-args "Academic Credentials" "ACRED" $REGISTRY
                     │                      │       │
                     │                      │       └─ _registry (linea 85: address _registry)
                     │                      └─ _symbol (linea 85: string memory _symbol)
                     └─ _name (linea 85: string memory _name)

Ejecuta el constructor (lineas 85-89 de SoulboundToken.sol):
1. Guarda name = "Academic Credentials" (linea 86)
2. Guarda symbol = "ACRED" (linea 87)
3. Guarda registry = address del CredentialRegistry (linea 88)
```

Del output, copiar `Deployed to:`:

```bash
export SBT=0x...  # Deployed to del output
```

### Paso 3: Flujo completo en Anvil

```bash
# Registrar tipo de credencial (linea 102: registerCredentialType)
cast send $REGISTRY "registerCredentialType(string,string)" \
  "Bachelor CS" "Computer Science degree" \
  --private-key $PK --rpc-url $RPC

# Autorizar issuer para ese tipo (typeId = 0)
cast send $REGISTRY "authorizeIssuer(uint256,address)" \
  0 $ADMIN \
  --private-key $PK --rpc-url $RPC

# Emitir credencial al estudiante
export STUDENT=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

cast send $REGISTRY "issueCredential(address,uint256,string)" \
  $STUDENT 0 "ipfs://QmHash..." \
  --private-key $PK --rpc-url $RPC

# Verificar que el estudiante tiene la credencial
cast call $REGISTRY "hasValidCredential(address,uint256)(bool)" \
  $STUDENT 0 --rpc-url $RPC
# true
```

---

### Ejercicio adicional: Deploy en Sepolia y en Besu

Despliega tu `CredentialRegistry` en dos redes diferentes para comparar la experiencia:

**Parte 1: Deploy en Sepolia (red publica)**

Prerequisito: tener SepoliaETH (ver [shared/testnet-setup.md](../../shared/testnet-setup.md))

```bash
source .env  # SEPOLIA_RPC_URL, PRIVATE_KEY

# Mismo flujo que Anvil pero apuntando a Sepolia
forge create contracts/CredentialRegistry.sol:CredentialRegistry \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --constructor-args $PLACEHOLDER_ADDRESS

# Verificar en Sepolia Etherscan
# https://sepolia.etherscan.io/address/TU_CONTRACT_ADDRESS
```

**Parte 2: Deploy en Besu (red privada)**

Prerequisito: red Besu levantada (ver [developer/11-private-networks](../11-private-networks/))

```bash
# Mismo flujo pero apuntando a Besu
forge create contracts/CredentialRegistry.sol:CredentialRegistry \
  --rpc-url http://localhost:8545 \
  --private-key $BESU_PRIVATE_KEY \
  --broadcast \
  --constructor-args $PLACEHOLDER_ADDRESS
```

**Parte 3: Comparar resultados**

Documenta las diferencias que observaste:
- Tiempo de confirmacion (Sepolia ~12s vs Besu ~2s)
- Costo de gas (SepoliaETH vs cero en Besu)
- Visibilidad (Etherscan publico vs solo nodos del consorcio)
- Que implicaciones tiene cada opcion para un sistema de credenciales real?

---

## Vulnerabilidades relevantes

### 1. Privacy Concerns (On-chain Data is Public)

```
PROBLEMA:

  Blockchain es publica y permanente.
  Si minteas un SBT que dice "Alice tiene certificacion de rehabilitacion",
  TODOS pueden verlo.

  +--------+     SBT on-chain      +-----------+
  | Alice  |<----------------------| Publico   |
  | wallet |  "Rehab Certificate"  | (cualquier|
  +--------+                       |  persona) |
                                   +-----------+

  MITIGACIONES:
  - Almacenar solo hashes on-chain, metadata off-chain
  - Zero-knowledge proofs: probar que tienes credencial sin revelarla
  - Credenciales off-chain con verificacion on-chain
  - Uso de direcciones rotativas (new wallet per context)
  - Selective disclosure: revelar solo atributos necesarios

  MEJOR PATRON:
  +--------+     SBT con hash      +-----------+
  | Alice  |<----------------------| On-chain  |
  | wallet |  keccak256(data)      | (solo hash)|
  +--------+                       +-----------+
       |
       |     Metadata real          +-----------+
       +--------------------------->| Off-chain |
              IPFS / encrypted      | (privado) |
                                    +-----------+
```

### 2. Revocation Challenges

```
PROBLEMA:

  Una vez que un SBT existe on-chain, revocarlo no borra la historia.
  En blockchain, "borrar" no existe realmente.

  Bloque 100: SBT minteado (visible en historia)
  Bloque 200: SBT revocado/quemado
  Bloque 300: Alguien lee bloque 100 -> sabe que existio

  MITIGACIONES:
  - Revocation registry: estado actual consultable
  - No confiar en existencia historica, siempre verificar estado actual
  - Credential expiry: SBTs con fecha de expiracion
```

### 3. Key Management

```
PROBLEMA:

  Si pierdes tu private key, pierdes todos tus SBTs.
  Si alguien roba tu key, puede quemar tus SBTs.
  No puedes transferir SBTs a una nueva wallet (son soulbound).

  Key perdida                     Key robada
       |                               |
       v                               v
  SBTs inaccesibles              Atacante quema SBTs
  No puedes probar               Pierdes reputacion/
  tus credenciales               credenciales

  MITIGACIONES:
  - Social recovery: multiples guardians pueden ayudar a recuperar
  - Account abstraction (ERC-4337): recovery mechanisms built-in
  - El issuer puede re-emitir a nueva wallet tras verificacion
  - Community recovery (propuesto en paper de Weyl/Buterin)
```

### 4. Sybil Attacks on Reputation

```
PROBLEMA:

  Si la reputacion se basa en SBTs, un atacante puede:
  1. Crear multiples wallets
  2. Obtener SBTs de reputacion en cada una
  3. Simular ser muchas personas con buena reputacion

  Atacante
  +--------+  wallet_1 -> SBT reputation
  |        |  wallet_2 -> SBT reputation
  | Sybil  |  wallet_3 -> SBT reputation
  |        |  ...
  +--------+  wallet_n -> SBT reputation

  MITIGACIONES:
  - SBTs emitidos por entidades confiables (no self-issuable)
  - Proof of personhood (Worldcoin, Proof of Humanity)
  - Web of trust: SBTs que requieren atestaciones cruzadas
  - Cost to acquire: hacer costoso obtener muchos SBTs
```

---

## Recursos

- [W3C DID Core Specification](https://www.w3.org/TR/did-core/)
- [W3C Verifiable Credentials](https://www.w3.org/TR/vc-data-model/)
- [ERC-5192: Minimal Soulbound NFTs](https://eips.ethereum.org/EIPS/eip-5192)
- [Decentralized Society: Finding Web3's Soul (Weyl, Ohlhaver, Buterin)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4105763)
- [ERC-721: Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [ERC-4337: Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337)
- [Ethereum Name Service (ENS)](https://docs.ens.domains/)
- [Ceramic Network](https://ceramic.network/) - Decentralized data for DIDs

---

## Checkpoint

Antes de avanzar al Modulo 09, verifica que puedes:

- [ ] Explicar que es un DID y como se diferencia de la identidad centralizada
- [ ] Describir los componentes de un DID Document
- [ ] Explicar que son los Soulbound Tokens y por que no son transferibles
- [ ] Describir el triangulo de Verifiable Credentials: issuer, holder, verifier
- [ ] Explicar los riesgos de privacidad de almacenar datos de identidad on-chain
- [ ] Describir el problema de key management con SBTs y posibles soluciones
- [ ] Tu CredentialSystem compila sin errores
- [ ] Todos los tests pasan con `forge test`
- [ ] Puedes explicar el flujo completo: registrar tipo -> autorizar issuer -> emitir -> verificar -> revocar
- [ ] Puedes comparar las implicaciones de desplegar DID en red publica vs privada
- [ ] Entiendes el patron DID Bridge: anchoring en privada, verificacion publica via merkle root
- [ ] (Opcional) Desplegaste CredentialSystem en Sepolia y/o en una red Besu local
