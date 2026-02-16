# Modulo 07: Identity and Compliance

## Objetivo

Al completar este modulo seras capaz de:

- Comprender el problema de identidad en blockchain y por que es fundamental para la adopcion
- Disenar sistemas basados en DID (Decentralized Identifiers) y Verifiable Credentials
- Aplicar Zero-Knowledge Proofs para preservar privacidad en procesos de identidad
- Evaluar estrategias de KYC/AML on-chain que cumplan regulaciones sin sacrificar privacidad
- Analizar el landscape regulatorio (MiCA, Travel Rule, FATF) y su impacto en el diseno
- Disenar un sistema de identidad descentralizado completo para un protocolo DeFi

---

## Prerequisitos

- Conocimiento de criptografia basica (public/private keys, hashing, firmas digitales)
- Entendimiento de smart contracts y almacenamiento on-chain vs off-chain
- Conceptos basicos de Zero-Knowledge Proofs (que demuestran, por que son utiles)
- Familiaridad con estandares de identidad web (OAuth, SAML) como punto de comparacion
- Modulos anteriores del track de arquitecto completados (01-06)

---

## Conceptos clave

### 1. El Problema de Identidad en Blockchain

Blockchain es pseudonimo por defecto. Una address (0x1234...) no dice nada sobre la persona o entidad detras de ella. Esto genera tension entre dos mundos:

```
   TENSION FUNDAMENTAL
   ====================

   Mundo Crypto                          Mundo Regulado
   +------------------------+            +------------------------+
   | - Pseudonimato          |            | - Identidad verificada |
   | - Permissionless        |            | - KYC/AML obligatorio  |
   | - Resistencia a censura |  TENSION   | - Travel Rule          |
   | - Self-sovereignty      | <-------> | - Reportes a autoridades|
   | - Privacidad maxima     |            | - Licencias            |
   | - Codigo es ley         |            | - Responsabilidad legal|
   +------------------------+            +------------------------+

   El reto: Como satisfacer ambos mundos?
   La respuesta: Identidad descentralizada con pruebas selectivas
```

**Por que importa**:
- Sin identidad, DeFi no puede cumplir regulaciones = no adopcion institucional
- Con identidad centralizada, se pierde la propuesta de valor de blockchain
- El balance correcto habilita el crecimiento del ecosistema

```
   ESPECTRO DE IDENTIDAD EN BLOCKCHAIN
   =====================================

   Anonimo         Pseudonimo        Verificado         Full KYC
   completo        (estado actual)   selectivamente     tradicional
   |                    |                 |                  |
   |<------ Crypto -------->|             |<--- TradFi ---->|

   Tornado Cash      Ethereum         Polygon ID          Coinbase
   Zcash             Bitcoin          ENS + VC            Binance

   Objetivo: Moverse al centro - verificado selectivamente
   El usuario controla que informacion revela y a quien
```

---

### 2. DID Architecture (W3C Standard)

#### 2.1 Que es un DID

Un DID (Decentralized Identifier) es un identificador globalmente unico que no depende de una autoridad centralizada.

```
   ANATOMIA DE UN DID
   ===================

   did:ethr:0x1234abcd5678ef90...
   |   |    |
   |   |    +-- Specific Identifier (la address en Ethereum)
   |   +------- DID Method (como resolver este DID)
   +----------- Scheme (siempre "did")

   Otros ejemplos:
   did:web:example.com          (resuelve via HTTPS)
   did:key:z6Mkf5rG...         (clave publica autocontenida)
   did:ion:EiA1234...          (Bitcoin-based, Microsoft)
   did:pkh:eip155:1:0xABC...   (cualquier blockchain address)
```

#### 2.2 DID Document

Cada DID resuelve a un DID Document que contiene la informacion necesaria para interactuar con la identidad.

```json
   {
     "@context": "https://www.w3.org/ns/did/v1",
     "id": "did:ethr:0x1234abcd...",
     "verificationMethod": [
       {
         "id": "did:ethr:0x1234abcd...#keys-1",
         "type": "EcdsaSecp256k1VerificationKey2019",
         "controller": "did:ethr:0x1234abcd...",
         "publicKeyHex": "04ab12cd34..."
       }
     ],
     "authentication": [
       "did:ethr:0x1234abcd...#keys-1"
     ],
     "service": [
       {
         "id": "did:ethr:0x1234abcd...#messaging",
         "type": "MessagingService",
         "serviceEndpoint": "https://example.com/messages"
       }
     ]
   }
```

#### 2.3 DID Resolution Flow

```
   DID RESOLUTION
   ===============

   Aplicacion                  DID Resolver               Blockchain/Registry
   +----------+                +-----------+               +------------------+
   |          |  1. Resolve    |           |  2. Query     |                  |
   |  Quiero  | did:ethr:0x123 |  Determina|  registry     |  ERC-1056        |
   |  verificar+-------------->|  method   +-------------->|  DID Registry    |
   |  a 0x123 |               |  (ethr)   |               |                  |
   |          |  5. DID Doc    |           |  3. Raw data  |  Retorna:        |
   |          |<---------------+  4. Build +<--------------+  - owner         |
   |          |                |  DID Doc  |               |  - delegates     |
   +----------+                +-----------+               |  - attributes    |
                                                           +------------------+

   DID Methods populares:
   +----------+----------------+---------------------------+
   | Method   | Registry       | Caracteristicas           |
   +----------+----------------+---------------------------+
   | did:ethr | ERC-1056       | Cualquier address ETH     |
   | did:web  | DNS + HTTPS    | Facil adopcion, centralizado|
   | did:key  | Ninguno        | Autocontenido, no rotable |
   | did:ion  | Bitcoin        | Descentralizado, lento    |
   | did:pkh  | Blockchain     | Multi-chain, CAIP-10      |
   +----------+----------------+---------------------------+
```

---

### 3. Verifiable Credentials (VC)

Las Verifiable Credentials son el equivalente digital de credenciales fisicas (pasaporte, diploma, licencia) pero verificables criptograficamente.

#### 3.1 El Triangulo de Confianza

```
   VERIFIABLE CREDENTIALS TRUST TRIANGLE
   =======================================

                    +------------------+
                    |     ISSUER       |
                    | (Quien emite)    |
                    | Ej: Universidad, |
                    | Gobierno, KYC    |
                    | Provider         |
                    +--------+---------+
                             |
                    1. Emite VC firmada
                             |
                             v
                    +--------+---------+
                    |     HOLDER       |
                    | (Quien posee)    |
                    | Ej: Usuario,     |
                    | wallet owner     |
                    +--------+---------+
                             |
                    2. Presenta VC (o ZK proof de VC)
                             |
                             v
                    +--------+---------+
                    |    VERIFIER      |
                    | (Quien verifica) |
                    | Ej: DeFi protocol|
                    | exchange, dApp   |
                    +------------------+
                             |
                    3. Verifica firma del Issuer
                       (sin contactar al Issuer)
```

#### 3.2 Estructura de una Verifiable Credential

```
   VERIFIABLE CREDENTIAL
   ======================

   +--------------------------------------------------+
   |  Credential Metadata                              |
   |  - id: "https://example.com/credentials/123"      |
   |  - type: ["VerifiableCredential", "KYCCredential"]|
   |  - issuer: "did:ethr:0xISSUER..."                |
   |  - issuanceDate: "2024-01-15"                     |
   |  - expirationDate: "2025-01-15"                   |
   +--------------------------------------------------+
   |  Claims (Subject)                                 |
   |  - id: "did:ethr:0xUSER..."                       |
   |  - kycStatus: "verified"                          |
   |  - jurisdiction: "EU"                             |
   |  - riskLevel: "low"                               |
   +--------------------------------------------------+
   |  Proof                                            |
   |  - type: "EcdsaSecp256k1Signature2019"            |
   |  - verificationMethod: "did:ethr:0xISSUER#key-1" |
   |  - signature: "0xABCDEF..."                       |
   +--------------------------------------------------+

   Almacenamiento:
   - VC completa: OFF-CHAIN (wallet del usuario, IPFS)
   - Anchor/hash: ON-CHAIN (para revocacion, timestamp)
   - Razon: privacidad + costo de gas
```

#### 3.3 Selective Disclosure

El usuario no necesita revelar toda la credencial. Solo comparte los claims necesarios.

```
   SELECTIVE DISCLOSURE
   =====================

   VC completa contiene:
   - nombre: "Juan Garcia"
   - fecha_nacimiento: "1990-05-15"
   - pais: "Mexico"
   - nivel_riesgo: "bajo"
   - kyc_status: "verificado"

   Escenario 1: DeFi protocol solo necesita saber si es KYC verified
   Usuario comparte: { kyc_status: "verificado" } + proof

   Escenario 2: Protocol restringido por jurisdiccion
   Usuario comparte: { pais: "Mexico", kyc_status: "verificado" } + proof

   Escenario 3: Verificacion de edad para acceder a servicio
   Usuario comparte: { es_mayor_de_18: true } + ZK proof
   (SIN revelar fecha de nacimiento exacta)
```

---

### 4. Privacy con Zero-Knowledge Proofs

#### 4.1 ZK para Identidad

Los ZK proofs permiten demostrar propiedades de datos sin revelar los datos mismos.

```
   ZK-KYC FLOW
   =============

   1. SETUP (una vez)
   +----------+     VC firmada      +----------+
   | KYC      | ------------------> | Usuario  |
   | Provider |  {nombre, pais,     | (Holder) |
   +----------+   edad, risk...}    +-----+----+
                                          |
   2. PROVING (cada vez que necesita)     |
                                          v
   +----------+     ZK Proof        +-----------+
   | Usuario  | ------------------> | DeFi      |
   | genera   |  "Tengo un VC      | Protocol  |
   | proof    |   valido de un      | (Verifier)|
   | local    |   issuer trusted    +-----------+
   +----------+   que dice que           |
                  soy >18 y de EU"       v
                                    Verifica proof
                  NO revela:        en O(1) on-chain
                  - nombre
                  - edad exacta
                  - otros datos personales
```

#### 4.2 Semaphore: Anonymous Group Membership

Semaphore permite probar que perteneces a un grupo sin revelar quien eres dentro del grupo.

```
   SEMAPHORE PROTOCOL
   ===================

   Grupo "KYC Verified Users"
   +------------------------------------------+
   | Identity commitments (hojas del tree):    |
   | [H(s1)] [H(s2)] [H(s3)] ... [H(sN)]    |
   +------------------------------------------+
          |
          v
   Merkle Tree
          +--[Root]--+
         /            \
      [H12]          [H34]
      /    \         /    \
   [H(s1)] [H(s2)] [H(s3)] [H(s4)]

   Para votar/actuar anonimamente:
   1. Usuario genera ZK proof:
      "Conozco un secreto s_i tal que H(s_i) es hoja del tree"
   2. Incluye un nullifier (previene doble uso)
   3. Verifier chequea:
      - Proof valido (es miembro del grupo)
      - Nullifier no usado antes (no doble gasto)
   4. NO sabe CUAL miembro del grupo actuo
```

#### 4.3 ZK Circuits para Verificacion de Credenciales

```
   ZK CREDENTIAL VERIFICATION CIRCUIT
   ====================================

   Inputs privados (solo el prover los conoce):
   - credential_data: {nombre, edad, pais, ...}
   - issuer_signature: firma del VC
   - credential_schema: estructura del VC

   Inputs publicos (el verifier los ve):
   - issuer_public_key: clave publica del issuer
   - merkle_root: root del arbol de issuers validos
   - claim_predicate: "edad >= 18 AND pais IN (EU_countries)"
   - nullifier: para prevenir reutilizacion

   Circuit verifica:
   1. issuer_signature es valida para credential_data
      con issuer_public_key                           --> Credential autentica
   2. issuer_public_key esta en el merkle tree
      de issuers trusted                              --> Issuer autorizado
   3. credential_data satisface claim_predicate       --> Claim verdadero
   4. nullifier derivado correctamente                --> No reutilizable

   Output: proof (valido/invalido)

   El verifier smart contract solo necesita:
   - Verificar el proof (barato en gas)
   - Chequear que el nullifier no se uso antes
   - Chequear que el merkle root es correcto
```

---

### 5. KYC/AML On-Chain

#### 5.1 Approaches

```
   ENFOQUES DE KYC ON-CHAIN
   =========================

   Enfoque 1: On-Chain Attestation
   +------------------------------------------+
   | KYC Provider                              |
   | (Chainalysis, Elliptic, etc.)            |
   |                                           |
   | Escribe directamente on-chain:            |
   | mapping(address => bool) public isKYC;   |
   |                                           |
   | Pro: Simple, composable                   |
   | Con: TODA la chain sabe tu KYC status    |
   +------------------------------------------+

   Enfoque 2: Off-Chain Verification + On-Chain Proof
   +------------------------------------------+
   | 1. Usuario hace KYC off-chain            |
   | 2. Provider emite VC firmada             |
   | 3. Usuario genera ZK proof              |
   | 4. Proof se verifica on-chain            |
   |                                           |
   | Pro: Privacidad preservada               |
   | Con: Mas complejo, mayor costo de setup  |
   +------------------------------------------+

   Enfoque 3: Soul Bound Tokens (SBTs)
   +------------------------------------------+
   | KYC Provider mint un SBT no-transferible |
   | al usuario verificado                     |
   |                                           |
   | El SBT puede contener:                   |
   | - Nivel de verificacion                  |
   | - Jurisdiccion (encriptada)              |
   | - Fecha de expiracion                    |
   |                                           |
   | Pro: On-chain, composable, estandar      |
   | Con: Visible publicamente (metadata)     |
   +------------------------------------------+
```

#### 5.2 Privacy Challenges

```
   EL DILEMA DE PRIVACIDAD
   ========================

   Blockchain publica + KYC on-chain = ???

   Si un protocolo DeFi requiere KYC:

   Opcion A: Whitelist de addresses
   +--------------------------------------------+
   | Protocol Contract                           |
   | mapping(address => bool) public allowed;   |
   |                                             |
   | Problema: TODOS pueden ver quien esta       |
   | en la whitelist. Cualquiera puede linkear   |
   | una address con una persona real.           |
   +--------------------------------------------+

   Opcion B: ZK Attestation
   +--------------------------------------------+
   | Protocol Contract                           |
   | function verify(bytes proof) returns(bool) |
   |                                             |
   | El usuario presenta un ZK proof de que     |
   | tiene KYC valido, sin revelar identidad.   |
   | La address NO esta en una lista publica.   |
   +--------------------------------------------+

   Opcion C: Encrypted Credentials
   +--------------------------------------------+
   | Credencial encriptada on-chain             |
   | Solo descifrable por partes autorizadas    |
   | (ej: regulador con orden judicial)         |
   |                                             |
   | Combina: privacidad + compliance           |
   +--------------------------------------------+
```

---

### 6. Enterprise DID: Redes privadas y consorcio

La mayoria de la documentacion sobre DID asume redes publicas. Pero en contextos enterprise, las organizaciones necesitan sistemas de identidad que funcionen en redes privadas y consorcio, con diferentes trade-offs.

#### 6.1 DID publico vs privado vs hibrido

```
   ESPECTRO DID ENTERPRISE
   =========================

   DID Publico              DID Hibrido              DID Privado
   (Ethereum/L2)            (Privada + Publica)      (Besu consorcio)
   +------------------+     +------------------+     +------------------+
   | - Verificable por|     | - Operaciones en |     | - Solo miembros  |
   |   cualquiera     |     |   red privada    |     |   del consorcio  |
   | - Gas variable   |     | - Verificacion   |     | - Gas cero       |
   | - Transparente   |     |   publica via    |     | - Control total  |
   | - Resistente a   |     |   merkle root    |     | - Compliance     |
   |   censura        |     | - Balance optimo |     |   nativo         |
   +------------------+     +------------------+     +------------------+
```

```
+---------------------+------------------+------------------+------------------+
| Dimension           | DID Publico      | DID Hibrido      | DID Privado      |
+---------------------+------------------+------------------+------------------+
| Resolucion          | Global           | Global (via proof)| Solo consorcio  |
| Costo operativo     | Gas de red       | Minimo (privada) | Cero/nominal    |
| Latencia            | ~12s             | ~2s (privada)    | ~2s             |
| Privacidad          | Minima           | Alta             | Total           |
| Verificacion ext.   | Si               | Si (con proof)   | No              |
| Regulacion          | Dificil          | Configurable     | Total control   |
| Single point fail   | No               | Parcial          | Si (consorcio)  |
| Caso ideal          | Credenciales     | Enterprise con   | Interno de      |
|                     | abiertas         | verificacion ext | organizacion    |
+---------------------+------------------+------------------+------------------+
```

#### 6.2 Patron 1: DID Anchoring Hibrido

La organizacion mantiene un DID Registry completo en su red Besu, y publica periodicamente un merkle root en una red publica (Ethereum L2). Esto permite verificacion externa sin exponer datos.

```
   DID ANCHORING HIBRIDO
   =======================

   Red Privada Besu                      Ethereum L2
   +-------------------------------+     +---------------------------+
   |  DID Registry (completo)      |     |  AnchorContract           |
   |  - DID Documents              |     |  - latestRoot: bytes32    |
   |  - Credential status          |     |  - updateRoot(root)       |
   |  - Revocation bitmap          |     |  - verifyProof(proof,leaf)|
   |  - Service endpoints          |     |                           |
   |                               |     |  Costo: 1 tx/periodo      |
   |  Throughput: ilimitado        |     |  (~$0.01 en L2)           |
   +-------------------------------+     +---------------------------+
              |                                    ^
              |  Cada N minutos/bloques:           |
              |  1. snapshot del state              |
              |  2. build merkle tree               |
              |  3. publish root                    |
              +------------------------------------>+

   Verificacion externa:
   1. Requester pide merkle proof al nodo Besu
   2. Nodo retorna proof + leaf data
   3. Requester verifica proof contra root on-chain (L2)
   4. No necesita acceso a la red Besu
```

#### 6.3 Patron 2: Resolucion DID Federada

Multiples consorcios pueden federar sus DID registries, permitiendo resolucion cross-consorcio sin compartir datos completos.

```
   RESOLUCION FEDERADA
   =====================

   Consorcio A (Banca)           Consorcio B (Seguros)
   +---------------------+       +---------------------+
   | DID Registry A      |       | DID Registry B      |
   | did:besu:consA:0x...|       | did:besu:consB:0x...|
   +----------+----------+       +----------+----------+
              |                              |
              |  Federation Protocol:        |
              |  - Cross-resolve DIDs        |
              |  - Verify credentials        |
              |  - Trust anchors mutuos      |
              +<----------+--------->--------+
                          |
                   +------+------+
                   | Federation  |
                   | Registry    |
                   | (on-chain o |
                   | off-chain)  |
                   +-------------+

   Resolver did:besu:consB:0x123 desde Consorcio A:
   1. Registry A no lo tiene
   2. Consulta Federation Registry
   3. Descubre que consB lo gestiona
   4. Cross-resolve via protocolo federado
   5. Verifica trust anchor de consB
```

#### 6.4 Patron 3: FireFly-Orchestrated DID

FireFly gestiona el ciclo de vida completo de DIDs usando sus capacidades de messaging y data exchange.

```
   FIREFLY DID MANAGEMENT
   ========================

   Org 1 (Issuer)                    Org 2 (Verifier)
   +---------------------+           +---------------------+
   | FireFly Node 1      |           | FireFly Node 2      |
   |                     |           |                     |
   | POST /api/v1/       |           | GET /api/v1/        |
   |   messages/private  |  -------> |   messages          |
   | {                   |  FireFly  | (recibe credential  |
   |   "credential": VC, |  messaging|  firmada)            |
   |   "did": "did:ff:org1"|         |                     |
   | }                   |           | Verifica firma      |
   +---------------------+           | contra DID de Org 1 |
          |                          +---------------------+
          v
   +---------------------+
   | Besu (consorcio)    |
   | - DID anchor        |
   | - Credential hash   |
   | - Revocation status |
   +---------------------+
```

#### 6.5 Implicaciones para el ejercicio de diseno

Al disenar el sistema de identidad del ejercicio principal, considera agregar un componente enterprise:

- **Requisito adicional**: el protocolo DeFi debe soportar credenciales emitidas tanto por KYC providers publicos como por consorcios enterprise (bancos).
- **Pregunta de diseno**: como integras un DID emitido en la red Besu de un consorcio bancario con un DeFi protocol en Ethereum L2?
- **Patron sugerido**: DID Anchoring Hibrido para que las credenciales enterprise sean verificables on-chain publico sin exponer la red privada.

---

### 7. Landscape Regulatorio

#### 7.1 MiCA (Markets in Crypto-Assets) - Union Europea

```
   MiCA FRAMEWORK
   ===============

   Clasificacion de crypto-assets:
   +---------------------------+----------------------------------+
   | Categoria                 | Requisitos                       |
   +---------------------------+----------------------------------+
   | E-Money Tokens (EMTs)     | Respaldo 1:1, licencia EMI,     |
   |  ej: stablecoins EUR      | reservas en bancos EU            |
   +---------------------------+----------------------------------+
   | Asset-Referenced Tokens   | Whitepaper, reservas, gobierno,  |
   |  ej: stablecoins multi    | reportes trimestrales            |
   +---------------------------+----------------------------------+
   | Utility Tokens            | Whitepaper, marketing rules      |
   +---------------------------+----------------------------------+
   | CASPs (Crypto-Asset       | Licencia, capital minimo, KYC,   |
   |  Service Providers)       | AML, segregacion de fondos       |
   +---------------------------+----------------------------------+

   Impacto en arquitectura:
   - Protocolos DeFi que operen en EU necesitan mecanismo de compliance
   - Token transfers pueden requerir verificacion de identidad
   - Stablecoins necesitan mecanismo de reserva auditable
```

#### 7.2 Travel Rule (FATF Recommendation 16)

```
   TRAVEL RULE
   ============

   Para transferencias > umbral (ej: 1000 EUR):

   Originator VASP                         Beneficiary VASP
   +--------------------+                  +--------------------+
   |  Debe enviar:      |  Junto con la    |  Debe verificar:   |
   |  - Nombre sender   |  transferencia   |  - Datos recibidos |
   |  - Address sender  +----------------->|  - Identidad del   |
   |  - Account number  |                  |    beneficiario    |
   |  - Ubicacion       |                  |  - Screening       |
   +--------------------+                  +--------------------+

   Desafio en DeFi:
   - No hay "VASP" en un protocolo descentralizado
   - Smart contracts no tienen identidad
   - Quien es el "originator" en un flash loan?

   Soluciones emergentes:
   - Notabene, Shyft: protocolos de Travel Rule
   - ZK Travel Rule: compartir datos solo cuando necesario
   - On-chain attestations que satisfacen el requisito
```

#### 7.3 FATF Guidelines

```
   FATF CLASSIFICATION
   ====================

   FATF clasifica actores en el ecosistema:

   VASP (Virtual Asset Service Provider):
   - Exchanges centralizados: SI son VASPs
   - Wallets custodiales: SI son VASPs
   - DeFi protocols: "DEPENDS" (caso por caso)
   - Developers: Generalmente NO
   - Validators: Generalmente NO

   El concepto de "control" determina si un protocolo DeFi
   es un VASP o no:
   - Admin keys que pueden pausar/upgrade = mas probabilidad
   - Fully immutable = menos probabilidad (pero no garantia)
   - Governance token con poder real = zona gris

   Implicacion para arquitectos:
   - El grado de descentralizacion tiene consecuencias legales
   - Progressive decentralization como estrategia
   - Disenar con compliance hooks (opcionales, activables)
```

---

## Analisis de casos reales

### ENS (Ethereum Name Service)

```
   ENS COMO CAPA DE IDENTIDAD
   ===========================

   ENS va mas alla de nombres:

   vitalik.eth --> Resuelve a:
   +------------------------------------------+
   | - ETH address: 0xd8dA6BF26964aF9D7eEd9e0 |
   | - BTC address: bc1q...                    |
   | - Avatar: URL o NFT                       |
   | - Email: (opcional)                       |
   | - Twitter: (opcional)                     |
   | - Description                             |
   | - Contenthash (IPFS/Swarm)               |
   +------------------------------------------+

   Como identidad:
   - Human-readable (vitalik.eth vs 0xd8dA...)
   - Self-sovereign (el dueno controla el registro)
   - Extensible (cualquier record type)
   - Interoperable (soportado por wallets, dApps)

   Limitaciones:
   - No es verificado (cualquiera puede poner "Twitter: @vitalik")
   - No es privado (todo on-chain)
   - No soporta selective disclosure
   - Costo de registro (gas + renewal fee)
```

### Worldcoin (Proof of Personhood)

```
   WORLDCOIN ARCHITECTURE
   =======================

   +-------------+      +----------------+      +---------------+
   | Orb Device  | ---> | Iris Scan      | ---> | World ID      |
   | (hardware)  |      | (biometrico)   |      | (ZK credential)|
   +-------------+      +----------------+      +---------------+
        |                      |                       |
        v                      v                       v
   Escaneo           Hash del iris           Semaphore-based
   presencial        (no se guarda          proof que demuestra
                     la imagen)             unicidad sin revelar
                                            identidad

   Controversias:
   - Centralizacion del hardware (Orb)
   - Datos biometricos (aunque se hashean)
   - Distribucion global desigual
   - Incentivos economicos (WLD token)

   Innovacion tecnica:
   - Proof of personhood sin identidad
   - ZK proofs para anonimato
   - Escalabilidad de verificacion
```

### Polygon ID (ZK-Based Identity)

```
   POLYGON ID ARCHITECTURE
   ========================

   Basado en el protocolo Iden3:

   +----------+     VC         +----------+     ZK Proof    +----------+
   | Issuer   | ------------> | Holder   | --------------> | Verifier |
   | (emite   |   off-chain   | (wallet  |   on-chain o    | (smart   |
   | claims)  |               | genera   |   off-chain     | contract)|
   +----------+               | proofs)  |                 +----------+
                              +----------+

   Componentes clave:

   1. Identity State:
      - Cada identidad tiene un Identity State Tree
      - Claims se agregan como hojas del tree
      - State root publicado on-chain periodicamente

   2. Claim Schema:
      - Estructura estandarizada para claims
      - Ej: "KYCAge" schema con campo birthDate

   3. ZK Query Language:
      - El verifier define que quiere verificar
      - Ej: "birthDate < 2006-01-01" (mayor de 18)
      - El holder genera ZK proof que satisface la query
      - Sin revelar birthDate exacta

   4. On-Chain Verification:
      - Smart contract verifica ZK proof
      - Chequea issuer state on-chain
      - Permite/deniega acceso
```

### Sismo (ZK Badges and Attestations)

```
   SISMO ARCHITECTURE
   ===================

   Concepto: "Prove facts about your identity without
              revealing your identity"

   Source Accounts                        Destination Account
   (donde estan                           (donde quieres
   tus credenciales)                      usar los badges)

   +-------------------+                  +-------------------+
   | GitHub: 1000 PRs  |    ZK Proof     |  0xANON...        |
   | Twitter: 10K foll | +------------>  |                   |
   | ENS: nombre.eth   |  "Tengo una     |  Badges:          |
   | Wallet: >100 ETH  |   cuenta con    |  [GitHub Top Dev] |
   +-------------------+   1000+ PRs     |  [Whale]          |
                           en GitHub"     |  [ENS Holder]     |
                                          +-------------------+

   NO se revela la conexion entre source y destination accounts

   Uso en DeFi:
   - Acceso a pools exclusivas sin revelar identidad
   - Reputacion portable y privada
   - Governance power basado en contribuciones verificables
```

---

## Ejercicio de diseno

### Disenar un Sistema de Identidad Descentralizado para DeFi con KYC

**Escenario**: Un protocolo DeFi de lending necesita implementar KYC compliance para operar legalmente en la EU (MiCA), pero quiere preservar la maxima privacidad posible para sus usuarios.

**Requisitos**:
1. Usuarios deben pasar KYC antes de interactuar con el protocolo
2. El protocolo no debe almacenar datos personales
3. Usuarios pueden demostrar compliance sin revelar su identidad a otros usuarios
4. Reguladores autorizados pueden obtener informacion de identidad bajo orden judicial
5. El sistema debe soportar revocacion de credenciales
6. Usuarios pueden recuperar su identidad si pierden acceso a su wallet

**Entregables del ejercicio** (documento de diseno):

1. **Capa de identidad**:
   - DID method elegido y justificacion
   - Estructura del DID Document
   - Almacenamiento on-chain vs off-chain

2. **Emision de credenciales**:
   - Flujo de KYC: donde, como, que datos
   - Estructura del Verifiable Credential
   - Lista de issuers autorizados y como se gestionan
   - Expiracion y renovacion

3. **Flujo de verificacion**:
   - Paso a paso: usuario quiere hacer un deposit
   - ZK circuit: que prueba, que inputs publicos/privados
   - Verificacion on-chain en el smart contract
   - Caching de proofs (para no generar uno nuevo cada transaccion)

4. **Mecanismo de privacidad**:
   - Que informacion se revela y a quien
   - Como se previene el linkeo de transacciones a identidades
   - Nullifier strategy
   - Escrow de datos encriptados para reguladores

5. **Revocacion**:
   - Como se revoca una credencial comprometida
   - Modelo: revocation list vs status list vs accumulator
   - Latencia aceptable entre revocacion y efecto

6. **Recovery**:
   - Social recovery para DIDs
   - Rotacion de claves
   - Migracion de credenciales a nuevo DID

7. **Integracion con el protocolo DeFi**:
   - Hook en transfer/deposit/borrow para verificar identidad
   - Transfer restrictions basadas en jurisdiccion
   - Manejo de compliance en flash loans y composability

---

## Trade-offs y decisiones

### Privacidad vs Regulatory Compliance

```
   +-------------------+-------------------+-------------------+
   |                   | MAX PRIVACIDAD    | MAX COMPLIANCE    |
   +-------------------+-------------------+-------------------+
   | Datos on-chain    | Nada              | Todo (whitelist)  |
   | Verificacion      | ZK proof          | Check directo     |
   | Regulador acceso  | Solo con warrant  | Siempre visible   |
   | Costo usuario     | Alto (generar ZK) | Bajo              |
   | Costo protocolo   | Alto (ZK verifier)| Bajo              |
   +-------------------+-------------------+-------------------+

   Balance optimo: ZK por defecto, escrow encriptado para reguladores
```

### On-Chain vs Off-Chain Storage

```
   On-Chain:
   + Inmutable, siempre disponible, composable
   - Costoso, publico, no se puede borrar (GDPR!)

   Off-Chain:
   + Barato, privado, borrable (GDPR compatible)
   - Requiere disponibilidad del storage, no composable directamente

   Hibrido (recomendado):
   - On-chain: state roots, nullifiers, revocation status
   - Off-chain: VCs completas, datos personales, proofs
```

### Centralized Issuers vs Web of Trust

```
   Centralized Issuers:
   + Simple, reguladores lo entienden, accountability claro
   - Single point of failure, no descentralizado, vendor lock-in

   Web of Trust:
   + Descentralizado, resistente a censura, flexible
   - Dificil de bootstrappear, ataques sybil, complejidad

   Modelo pragmatico:
   - Empezar con issuers autorizados (curated list via governance)
   - Evolucionar hacia web of trust a medida que el ecosistema madura
   - Permitir multiples issuers desde el dia 1 (no vendor lock-in)
```

### User Experience vs Security

```
   Mas seguro (mas friction):              Mas usable (menos seguro):
   - ZK proof por cada transaccion         - Proof una vez, cache largo
   - Hardware wallet para DID              - Browser wallet
   - Multiple credentials required         - Single attestation
   - Frequent re-verification              - Long-lived credentials

   Balance:
   - Session-based proofs (un proof por sesion de uso)
   - Progressive verification (mas credenciales = mas acceso)
   - Recovery sencillo (social recovery, no solo seed phrase)
```

---

## Recursos

### Estandares y especificaciones
- W3C DID Core: w3.org/TR/did-core
- W3C Verifiable Credentials: w3.org/TR/vc-data-model
- ERC-735: Claim Holder (Ethereum identity standard)
- ERC-725: Proxy Account (identity contract)
- ERC-5484: Consensual Soulbound Tokens

### Protocolos y herramientas
- Polygon ID Docs: devs.polygonid.com
- Semaphore Protocol: semaphore.pse.dev
- Iden3 Protocol: docs.iden3.io
- SpruceID: spruceid.dev
- Ceramic Network: ceramic.network (decentralized data storage for identity)

### Papers y research
- "Decentralized Society: Finding Web3's Soul" - Weyl, Ohlhaver, Buterin (2022)
- "SoK: Decentralized Identity" - IEEE EuroS&P
- "Privacy-Preserving KYC on Ethereum" - Semaphore research
- MiCA Regulation Full Text: eur-lex.europa.eu

### Regulacion
- FATF Updated Guidance on Virtual Assets (2021)
- Travel Rule Implementation Guidelines
- EU MiCA Regulation: official text and implementation timeline
- SEC vs Howey Test applicability to identity tokens

### Talks y presentaciones
- "ZK Identity" - Jordi Baylina (Iden3/Polygon ID)
- "The Future of On-Chain Identity" - ENS team
- "Privacy and Compliance in DeFi" - various DeFi conferences

---

## Checkpoint

Antes de avanzar al siguiente modulo, verifica que puedes:

- [ ] Explicar el problema de identidad en blockchain y por que el pseudonimato no es suficiente para adopcion masiva
- [ ] Describir la arquitectura completa de DIDs: identifier, document, resolution, methods
- [ ] Disenar un flujo de Verifiable Credentials end-to-end (emision, presentacion, verificacion)
- [ ] Explicar como ZK proofs permiten verificar identidad sin revelar datos personales
- [ ] Disenar un ZK circuit conceptual para verificacion de credenciales
- [ ] Comparar al menos 3 enfoques de KYC on-chain con sus trade-offs
- [ ] Describir los requisitos de MiCA y Travel Rule y su impacto en arquitectura DeFi
- [ ] Analizar las arquitecturas de Polygon ID, ENS, y Worldcoin
- [ ] Completar el ejercicio de diseno del sistema de identidad con todos los componentes
- [ ] Evaluar trade-offs entre privacidad, compliance, UX y seguridad en un sistema de identidad
- [ ] Comparar DID publico vs privado vs hibrido con criterios claros para cada caso enterprise
- [ ] Disenar un esquema de DID Anchoring Hibrido: red privada para operaciones, red publica para verificacion
- [ ] Explicar como FireFly puede orquestar el ciclo de vida de DIDs en un consorcio
- [ ] Integrar requisitos enterprise (credenciales de consorcio) en el ejercicio de diseno principal
