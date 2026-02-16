# Modulo 10: Real World Assets (RWA)

## Objetivo

Al completar este modulo seras capaz de:

- Entender que significa tokenizar activos del mundo real (Real World Assets)
- Conocer los tipos de activos tokenizables: real estate, bonds, commodities, art
- Comprender los requisitos de compliance: KYC/AML, investor accreditation, transfer restrictions
- Conocer el concepto del estandar ERC-3643 (T-REX) para tokens regulados
- Implementar fractional ownership dividiendo activos costosos en tokens
- Construir un RWAToken con whitelist, roles de compliance y transfer restrictions
- Identificar vulnerabilidades y riesgos especificos de RWA on-chain

---

## Prerequisitos

- Modulo 01: Solidity Fundamentals (storage, modifiers, events, access control)
- Modulo 02: Tokens and Standards (ERC-20 completo)
- Modulo 04: Security Patterns (reentrancy, role-based access control)
- Modulo 08: Identity, DID & SBT (conceptos de identidad on-chain)
- Foundry instalado y funcional (`forge`, `cast`, `anvil`)

---

## Conceptos clave

### 1. Tokenizacion de Real World Assets

La tokenizacion de RWA consiste en representar la propiedad (o derechos sobre) un activo fisico o financiero tradicional mediante tokens en una blockchain.

```
Mundo Real                          Blockchain
+------------------+                +------------------+
|                  |   Tokenizar    |                  |
|  Edificio        | ------------> |  RWA Token       |
|  Valor: $10M     |                |  Supply: 10,000  |
|  1 propietario   |                |  1 token = $1,000|
|                  |                |  N propietarios  |
+------------------+                +------------------+

Beneficios:
- Fractional ownership (propiedad fraccionada)
- Liquidez para activos iliquidos
- Transferencia 24/7 sin intermediarios
- Transparencia en la cadena de propiedad
- Programabilidad (dividendos automaticos, compliance)
```

### 2. Tipos de activos tokenizables

```
+-------------------+---------------------------------------------------+
| Categoria         | Ejemplos                                          |
+-------------------+---------------------------------------------------+
| Real Estate       | Edificios comerciales, residenciales, terrenos    |
|                   | REITs tokenizados, fracciones de propiedades      |
+-------------------+---------------------------------------------------+
| Fixed Income      | Bonos del tesoro (T-Bills), bonos corporativos    |
|                   | Money market funds tokenizados                    |
+-------------------+---------------------------------------------------+
| Commodities       | Oro (PAXG, tGOLD), plata, petroleo                |
|                   | Carbon credits tokenizados                        |
+-------------------+---------------------------------------------------+
| Art & Collectibles| Obras de arte fraccionadas, vinos finos           |
|                   | Vehiculos de coleccion                            |
+-------------------+---------------------------------------------------+
| Private Equity    | Acciones de empresas privadas                     |
|                   | Venture capital funds tokenizados                 |
+-------------------+---------------------------------------------------+
| Invoices/Receivables | Facturas tokenizadas, trade finance            |
|                   | Supply chain finance                              |
+-------------------+---------------------------------------------------+
```

### 3. Compliance: KYC/AML y Transfer Restrictions

A diferencia de tokens DeFi, los RWA tokens estan sujetos a regulaciones financieras. Esto requiere controles on-chain.

```
Flujo de compliance para RWA:

  Inversor nuevo
       |
       v
  +------------------+
  | KYC/AML Check    |  <- Off-chain: verificacion de identidad,
  | (off-chain)      |     origen de fondos, sanctions screening
  +--------+---------+
           |
           | Aprobado
           v
  +------------------+
  | Compliance       |  <- On-chain: el COMPLIANCE_OFFICER agrega
  | Officer agrega   |     la address al IdentityRegistry
  | a whitelist      |
  +--------+---------+
           |
           v
  +------------------+
  | Inversor puede   |  <- Solo addresses en whitelist pueden
  | comprar/recibir  |     enviar y recibir tokens
  | RWA tokens       |
  +------------------+
```

```
Transfer Restrictions (on-chain):

  sender.transfer(receiver, amount)
       |
       v
  +-----------------------------+
  | 1. sender esta whitelisted? |--NO--> REVERT
  +-------------+---------------+
                |YES
                v
  +-----------------------------+
  | 2. receiver esta whitelisted|--NO--> REVERT
  +-------------+---------------+
                |YES
                v
  +-----------------------------+
  | 3. sender esta frozen?      |--SI--> REVERT
  +-------------+---------------+
                |NO
                v
  +-----------------------------+
  | 4. receiver esta frozen?    |--SI--> REVERT
  +-------------+---------------+
                |NO
                v
  +-----------------------------+
  | 5. transfers estan pausados?|--SI--> REVERT
  +-------------+---------------+
                |NO
                v
  +-----------------------------+
  | 6. pais del receiver        |--SI--> REVERT
  |    esta restringido?        |
  +-------------+---------------+
                |NO
                v
         TRANSFER OK
```

### 4. ERC-3643 (T-REX): Token for Regulated Exchanges

ERC-3643 es un estandar para security tokens que define la arquitectura de un token regulado.

```
Arquitectura ERC-3643 (simplificada):

+-------------------+       +----------------------+
|   Token Contract  | <---> | Identity Registry    |
|   (ERC-20 +       |       | (whitelist +         |
|    restrictions)   |       |  country codes)      |
+-------------------+       +----------------------+
         |                           |
         v                           v
+-------------------+       +----------------------+
| Compliance Module |       | Claim Verifier       |
| (reglas de        |       | (verifica claims     |
|  transferencia)   |       |  de identidad)       |
+-------------------+       +----------------------+

Componentes clave:
- Token: ERC-20 con hooks de compliance en cada transfer
- Identity Registry: mapeo address -> identidad verificada
- Compliance: reglas de negocio (limites, restricciones por pais)
- Claims: attestations sobre el inversor (KYC aprobado, accreditado, etc.)
```

**Nota:** Nuestra implementacion es una version simplificada que captura los conceptos esenciales sin la complejidad completa de ERC-3643.

### 5. Fractional Ownership

```
Activo tradicional:               Activo tokenizado:

+-------------------+             +-------------------+
| Edificio $10M     |             | RWA Token         |
| 1 propietario     |             | 10,000 tokens     |
| Iliquido          |             | $1,000 c/u        |
| Transferencia     |             |                   |
|  lenta y costosa  |             | Alice: 3,000 (30%)|
+-------------------+             | Bob:   2,000 (20%)|
                                  | Carol: 5,000 (50%)|
                                  |                   |
                                  | Transferible 24/7 |
                                  | Dividendos auto.  |
                                  +-------------------+

Ventajas:
- Acceso a inversores minoristas (no necesitas $10M)
- Diversificacion (puedes tener fracciones de multiples activos)
- Liquidez mejorada (trading en mercados secundarios)
- Settlement instantaneo (vs T+2 en mercados tradicionales)
```

### 6. Roles en un sistema RWA

```
+---------------------+---------------------------------------------+
| Rol                 | Responsabilidades                           |
+---------------------+---------------------------------------------+
| ADMIN               | - Asignar y revocar roles                   |
|                     | - Configuracion del contrato                |
+---------------------+---------------------------------------------+
| COMPLIANCE_OFFICER  | - Gestionar whitelist (add/remove)          |
|                     | - Freeze/unfreeze cuentas individuales      |
|                     | - Force transfer (requerimiento regulatorio)|
|                     | - Token recovery (wallets perdidas)         |
+---------------------+---------------------------------------------+
| AGENT               | - Pausar/despausar todas las transferencias |
|                     | - Operaciones de emergencia                 |
+---------------------+---------------------------------------------+
| INVESTOR            | - Transferir tokens (si whitelisted)        |
|                     | - Recibir dividendos                        |
+---------------------+---------------------------------------------+
```

---

## Ejercicio practico: RWA Token con Identity Registry

### Descripcion

Implementa un sistema de tokens regulados compuesto por dos contratos:

1. **IdentityRegistry**: gestion de whitelist e identidad de inversores
2. **RWAToken**: token ERC-20 con transfer restrictions, roles y compliance

### Arquitectura

```
                    +------------------+
                    |     ADMIN        |
                    | (asigna roles)   |
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
              v                             v
  +-------------------+         +-------------------+
  | COMPLIANCE_OFFICER|         |      AGENT        |
  | - whitelist mgmt  |         | - pause/unpause   |
  | - freeze/unfreeze |         +-------------------+
  | - force transfer  |
  | - token recovery  |
  +--------+----------+
           |
           v
  +-------------------+         +-------------------+
  | IdentityRegistry  | <-----> |     RWAToken       |
  | - investors[]     |         | - ERC-20 base      |
  | - countries[]     |         | - transfer checks  |
  | - restrictions[]  |         | - frozen accounts  |
  +-------------------+         | - pausable         |
                                +-------------------+
                                        |
                                        v
                                +-------------------+
                                |    Investors      |
                                | (whitelisted only)|
                                +-------------------+
```

### Archivos

- `contracts/IdentityRegistry.sol` - whitelist e identidad de inversores
- `contracts/RWAToken.sol` - token regulado con compliance
- `test/RWAToken.t.sol` - tests completos

---

## Vulnerabilidades relevantes

### 1. Oracle Dependency para valoracion de activos

Los RWA tokens dependen de oracles para reflejar el valor real del activo subyacente. Si el oraculo falla o es manipulado, el precio on-chain no refleja la realidad.

```
Mundo Real                  Oracle                  Blockchain
+-----------+          +------------+          +------------+
| Edificio  |  $10M    | Price Feed |  $10M    | Token price|
| se vende  | -------> | actualiza  | -------> | = $1,000   |
| a $8M     |          |            |          | por token  |
+-----------+          +------------+          +------------+

Riesgo: Si el oracle no actualiza, el token sigue valuado en $10M
cuando el activo real vale $8M.

Mitigacion:
- Multiples fuentes de precio
- Circuit breakers si el precio cambia drasticamente
- Actualizaciones periodicas con heartbeat verificable
- Fallback a modo de pausa si el oracle no responde
```

### 2. Centralizacion del Compliance

```
Riesgo: El COMPLIANCE_OFFICER tiene poder significativo

Acciones que puede ejecutar:
- Congelar cualquier cuenta (sin aprobacion judicial on-chain)
- Forzar transferencias (mover tokens de cualquier address)
- Agregar/remover de whitelist (controlar quien puede participar)

                    COMPLIANCE_OFFICER
                          |
            +-------------+-------------+
            |             |             |
            v             v             v
         freeze()    forceTransfer()  removeInvestor()
         tu cuenta   tus tokens       tu acceso

Mitigacion:
- Multisig para roles criticos (no una sola persona)
- Timelock para acciones destructivas
- Audit trail on-chain (events para cada accion)
- Governance descentralizada para cambios de politica
- Limites en forceTransfer (cooldown, aprobacion multiple)
```

### 3. Regulatory Risk

```
Jurisdiccion A aprueba el token
Jurisdiccion B lo prohibe

+-------------------+     transfer     +-------------------+
| Inversor en A     | --------------> | Inversor en B     |
| (legal)           |                  | (ilegal)          |
+-------------------+                  +-------------------+

Si el sistema no verifica jurisdiccion en cada transfer:
- Responsabilidad legal para el emisor
- Posible congelamiento de activos
- Multas regulatorias

Mitigacion:
- Country-based restrictions en IdentityRegistry
- Verificacion de jurisdiccion en cada transfer
- Capacidad de actualizar restricciones sin migrar el token
- Compliance module actualizable
```

### 4. Custody Trust Assumptions

```
Pregunta fundamental: Quien custodia el activo real?

Token on-chain <------> Activo off-chain
  (trustless)              (requiere confianza)

+-------------------+         +-------------------+
| 10,000 tokens     |  <-->   | Edificio fisico   |
| en blockchain     |         | en custodia de    |
| (verificable)     |         | empresa X         |
|                   |         | (confianza)       |
+-------------------+         +-------------------+

Riesgos:
- El custodio puede actuar maliciosamente
- El activo puede danarse o perder valor sin notificacion
- Discrepancia entre token supply y activo real
- Quiebra del custodio

Mitigacion:
- Auditorias periodicas por terceros independientes
- Proof of Reserves on-chain
- Seguros sobre el activo custodiado
- Marco legal que vincule token con propiedad real
- SPV (Special Purpose Vehicle) como estructura legal
```

### 5. Token Recovery y Privacy

```solidity
// forceTransfer permite al compliance officer mover tokens de cualquier cuenta
// Esto es necesario para compliance pero es un vector de ataque si el rol
// es comprometido.

// RIESGO: un compliance officer comprometido podria robar tokens
function forceTransfer(address from, address to, uint256 amount) external onlyComplianceOfficer {
    _transfer(from, to, amount);
}

// MITIGACION: agregar timelock + multisig
// En produccion, forceTransfer deberia:
// 1. Requerir multisig (2 de 3 compliance officers)
// 2. Tener un timelock de 48h (permitir que el afectado objete)
// 3. Emitir event detallado con razon
// 4. Tener un limite maximo por periodo
```

---

## Recursos

- [ERC-3643 (T-REX) Specification](https://eips.ethereum.org/EIPS/eip-3643)
- [T-REX Token Standard Repository](https://github.com/TokenySolutions/T-REX)
- [Centrifuge - RWA Protocol](https://docs.centrifuge.io/)
- [MakerDAO RWA Documentation](https://docs.makerdao.com/)
- [Ondo Finance - Tokenized Treasuries](https://ondo.finance/)
- [BlackRock BUIDL Fund](https://securitize.io/learn/blackrock-buidl-fund)
- [Security Token Standard (ERC-1400)](https://eips.ethereum.org/EIPS/eip-1400)
- [RWA.xyz - Real World Asset Dashboard](https://www.rwa.xyz/)
- [OpenZeppelin Access Control](https://docs.openzeppelin.com/contracts/5.x/access-control)

---

## Checkpoint

Antes de considerar completo el track de Developer, verifica que puedes:

- [ ] Explicar que es la tokenizacion de RWA y sus beneficios principales
- [ ] Describir los requisitos de compliance (KYC/AML) para security tokens
- [ ] Explicar el concepto de ERC-3643 y sus componentes principales
- [ ] Describir como funciona fractional ownership con tokens
- [ ] Explicar los roles ADMIN, COMPLIANCE_OFFICER y AGENT y sus permisos
- [ ] Tu IdentityRegistry gestiona whitelist con country codes correctamente
- [ ] Tu RWAToken implementa transfer restrictions que validan whitelist
- [ ] Freeze/unfreeze de cuentas individuales funciona correctamente
- [ ] Pause/unpause bloquea y desbloquea todas las transferencias
- [ ] Force transfer y token recovery funcionan solo con el rol correcto
- [ ] Todos los tests pasan con `forge test`
- [ ] Puedes explicar los riesgos de centralizacion en un sistema RWA
- [ ] Entiendes las trust assumptions de custody off-chain
