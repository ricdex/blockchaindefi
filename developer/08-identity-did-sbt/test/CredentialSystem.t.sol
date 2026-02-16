// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SoulboundToken} from "../contracts/SoulboundToken.sol";
import {CredentialRegistry} from "../contracts/CredentialRegistry.sol";

contract CredentialSystemTest is Test {
    SoulboundToken public sbt;
    CredentialRegistry public registry;

    address public admin = makeAddr("admin");
    address public mit = makeAddr("mit");          // Issuer: MIT university
    address public consensys = makeAddr("consensys"); // Issuer: Consensys Academy
    address public alice = makeAddr("alice");       // Student
    address public bob = makeAddr("bob");           // Student
    address public unauthorized = makeAddr("unauthorized");

    uint256 public bachelorCSTypeId;
    uint256 public solidityCertTypeId;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy CredentialRegistry first (to get its address for SBT)
        // We need the registry address for SBT, but registry needs SBT address too.
        // Solution: deploy SBT with a placeholder, then deploy registry, then update.
        // Simpler: predict the registry address or use a two-step setup.

        // Deploy SBT with admin as temporary registry
        sbt = new SoulboundToken("Academic Credentials", "ACRED", admin);

        // Deploy CredentialRegistry
        registry = new CredentialRegistry(address(sbt));

        // Now we need to update SBT's registry to the actual registry.
        // Since our SBT doesn't have a setter, we'll deploy again with the correct address.
        vm.stopPrank();

        // Re-deploy with correct registry address
        // First, compute registry address deterministically
        vm.startPrank(admin);

        // Simpler approach: deploy SBT first pointing to where registry will be
        // Since we're in tests, just redeploy in correct order
        uint256 nonce = vm.getNonce(admin);

        // Predict registry address (next deployment after SBT)
        address predictedRegistry = vm.computeCreateAddress(admin, nonce + 1);

        sbt = new SoulboundToken("Academic Credentials", "ACRED", predictedRegistry);
        registry = new CredentialRegistry(address(sbt));

        // Verify prediction was correct
        assertEq(address(registry), predictedRegistry);

        // Register credential types
        bachelorCSTypeId = registry.registerCredentialType(
            "Bachelor of Computer Science",
            "Undergraduate degree in Computer Science"
        );

        solidityCertTypeId = registry.registerCredentialType(
            "Solidity Developer Certification",
            "Professional certification for Solidity smart contract development"
        );

        // Authorize issuers
        registry.authorizeIssuer(bachelorCSTypeId, mit);
        registry.authorizeIssuer(solidityCertTypeId, consensys);

        vm.stopPrank();
    }

    // =========================================================================
    // Credential Type Registration Tests
    // =========================================================================

    function test_RegisterCredentialType() public {
        (string memory name, string memory description, bool active) =
            registry.credentialTypes(bachelorCSTypeId);

        assertEq(name, "Bachelor of Computer Science");
        assertEq(description, "Undergraduate degree in Computer Science");
        assertTrue(active);
    }

    function test_RegisterCredentialType_EmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit CredentialRegistry.CredentialTypeRegistered(2, "PhD Mathematics");

        registry.registerCredentialType("PhD Mathematics", "Doctoral degree in Mathematics");
    }

    function test_RegisterCredentialType_OnlyAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert(CredentialRegistry.OnlyAdmin.selector);
        registry.registerCredentialType("Fake Type", "Should fail");
    }

    // =========================================================================
    // Issuer Authorization Tests
    // =========================================================================

    function test_AuthorizeIssuer() public {
        assertTrue(registry.isAuthorizedIssuer(bachelorCSTypeId, mit));
        assertTrue(registry.isAuthorizedIssuer(solidityCertTypeId, consensys));
    }

    function test_AuthorizeIssuer_EmitsEvent() public {
        address newIssuer = makeAddr("newIssuer");

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit CredentialRegistry.IssuerAuthorized(bachelorCSTypeId, newIssuer);

        registry.authorizeIssuer(bachelorCSTypeId, newIssuer);
    }

    function test_RevokeIssuer() public {
        vm.prank(admin);
        registry.revokeIssuer(bachelorCSTypeId, mit);

        assertFalse(registry.isAuthorizedIssuer(bachelorCSTypeId, mit));
    }

    function test_AuthorizeIssuer_OnlyAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert(CredentialRegistry.OnlyAdmin.selector);
        registry.authorizeIssuer(bachelorCSTypeId, unauthorized);
    }

    // =========================================================================
    // Credential Issuance Tests
    // =========================================================================

    function test_IssueCredential() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice,
            bachelorCSTypeId,
            "ipfs://QmBachelorCS_Alice"
        );

        assertEq(tokenId, 0);
        assertEq(sbt.ownerOf(tokenId), alice);

        // Verify credential data
        (uint256 credTypeId, address issuer, uint256 issuedAt, string memory metadataURI) =
            sbt.credentials(tokenId);
        assertEq(credTypeId, bachelorCSTypeId);
        assertEq(issuer, mit);
        assertTrue(issuedAt > 0);
        assertEq(metadataURI, "ipfs://QmBachelorCS_Alice");
    }

    function test_IssueCredential_EmitsEvents() public {
        vm.prank(mit);
        vm.expectEmit(true, true, true, true);
        emit CredentialRegistry.CredentialIssued(0, alice, bachelorCSTypeId, mit);

        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");
    }

    function test_IssueCredential_MultipleDifferentTypes() public {
        // MIT issues Bachelor CS to Alice
        vm.prank(mit);
        uint256 tokenId1 = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        // Consensys issues Solidity Cert to Alice
        vm.prank(consensys);
        uint256 tokenId2 = registry.issueCredential(
            alice, solidityCertTypeId, "ipfs://QmSolidityCert_Alice"
        );

        assertEq(sbt.ownerOf(tokenId1), alice);
        assertEq(sbt.ownerOf(tokenId2), alice);
        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
    }

    function test_IssueCredential_MultipleRecipients() public {
        vm.startPrank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");
        registry.issueCredential(bob, bachelorCSTypeId, "ipfs://QmBachelorCS_Bob");
        vm.stopPrank();

        assertEq(sbt.ownerOf(0), alice);
        assertEq(sbt.ownerOf(1), bob);
    }

    function test_IssueCredential_CannotDuplicate() public {
        vm.startPrank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        vm.expectRevert(CredentialRegistry.AlreadyHasCredential.selector);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice_v2");
        vm.stopPrank();
    }

    function test_IssueCredential_UnauthorizedIssuer() public {
        vm.prank(unauthorized);
        vm.expectRevert(CredentialRegistry.NotAuthorizedIssuer.selector);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://Qm_fake");
    }

    function test_IssueCredential_WrongTypeForIssuer() public {
        // MIT is authorized for Bachelor CS, not for Solidity Cert
        vm.prank(mit);
        vm.expectRevert(CredentialRegistry.NotAuthorizedIssuer.selector);
        registry.issueCredential(alice, solidityCertTypeId, "ipfs://Qm_wrong_type");
    }

    function test_IssueCredential_InactiveType() public {
        vm.prank(admin);
        registry.deactivateCredentialType(bachelorCSTypeId);

        vm.prank(mit);
        vm.expectRevert(CredentialRegistry.CredentialTypeNotActive.selector);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://Qm_inactive");
    }

    // =========================================================================
    // Verification Tests
    // =========================================================================

    function test_VerifyCredential() public {
        vm.prank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        (bool hasCredential, uint256 tokenId) =
            registry.verifyCredential(alice, bachelorCSTypeId);

        assertTrue(hasCredential);
        assertEq(tokenId, 0);
    }

    function test_VerifyCredential_NoCredential() public {
        (bool hasCredential, uint256 tokenId) =
            registry.verifyCredential(alice, bachelorCSTypeId);

        assertFalse(hasCredential);
        assertEq(tokenId, 0);
    }

    function test_VerifyCredential_AfterRevocation() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        // Revoke
        vm.prank(mit);
        registry.revokeCredential(tokenId);

        (bool hasCredential,) = registry.verifyCredential(alice, bachelorCSTypeId);
        assertFalse(hasCredential);
    }

    // =========================================================================
    // Soulbound (Non-transferable) Tests
    // =========================================================================

    function test_CannotTransferSBT() public {
        vm.prank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        vm.prank(alice);
        vm.expectRevert(SoulboundToken.TransferBlocked.selector);
        sbt.transferFrom(alice, bob, 0);
    }

    function test_CannotSafeTransferSBT() public {
        vm.prank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        vm.prank(alice);
        vm.expectRevert(SoulboundToken.TransferBlocked.selector);
        sbt.safeTransferFrom(alice, bob, 0);
    }

    function test_CannotApproveSBT() public {
        vm.prank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        vm.prank(alice);
        vm.expectRevert(SoulboundToken.TransferBlocked.selector);
        sbt.approve(bob, 0);
    }

    function test_CannotSetApprovalForAllSBT() public {
        vm.prank(alice);
        vm.expectRevert(SoulboundToken.TransferBlocked.selector);
        sbt.setApprovalForAll(bob, true);
    }

    function test_SBT_IsLocked() public {
        vm.prank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        assertTrue(sbt.locked(0));
    }

    // =========================================================================
    // Revocation Tests
    // =========================================================================

    function test_RevokeCredential() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        vm.prank(mit);
        registry.revokeCredential(tokenId);

        // Token should no longer exist
        assertFalse(sbt.exists(tokenId));
        assertTrue(registry.revoked(tokenId));
    }

    function test_RevokeCredential_EmitsEvent() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        vm.prank(mit);
        vm.expectEmit(true, true, true, false);
        emit CredentialRegistry.CredentialRevoked(tokenId, alice, bachelorCSTypeId);

        registry.revokeCredential(tokenId);
    }

    function test_RevokeCredential_OnlyIssuer() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        // Consensys (different issuer) cannot revoke MIT's credential
        vm.prank(consensys);
        vm.expectRevert(CredentialRegistry.NotIssuerOfCredential.selector);
        registry.revokeCredential(tokenId);
    }

    // =========================================================================
    // Holder Burn Tests
    // =========================================================================

    function test_HolderCanBurnOwnSBT() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        // Alice burns her own SBT (right to be forgotten)
        vm.prank(alice);
        sbt.burn(tokenId);

        assertFalse(sbt.exists(tokenId));
    }

    function test_NonHolderCannotBurnSBT() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        // Bob cannot burn Alice's SBT
        vm.prank(bob);
        vm.expectRevert(SoulboundToken.NotTokenHolder.selector);
        sbt.burn(tokenId);
    }

    // =========================================================================
    // Edge Case Tests
    // =========================================================================

    function test_TokenURI() public {
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice"
        );

        assertEq(sbt.tokenURI(tokenId), "ipfs://QmBachelorCS_Alice");
    }

    function test_BalanceOf() public {
        vm.prank(mit);
        registry.issueCredential(alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice");

        vm.prank(consensys);
        registry.issueCredential(alice, solidityCertTypeId, "ipfs://QmSolidityCert_Alice");

        assertEq(sbt.balanceOf(alice), 2);
    }

    function test_ReissueAfterRevocation() public {
        // Issue credential
        vm.prank(mit);
        uint256 tokenId1 = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice_v1"
        );

        // Revoke it
        vm.prank(mit);
        registry.revokeCredential(tokenId1);

        // Re-issue the same type to the same holder
        vm.prank(mit);
        uint256 tokenId2 = registry.issueCredential(
            alice, bachelorCSTypeId, "ipfs://QmBachelorCS_Alice_v2"
        );

        assertFalse(sbt.exists(tokenId1));
        assertTrue(sbt.exists(tokenId2));
        assertEq(sbt.ownerOf(tokenId2), alice);
    }

    // =========================================================================
    // Integration / End-to-End Test
    // =========================================================================

    function test_EndToEnd_FullCredentialLifecycle() public {
        // 1. Admin registers a new credential type
        vm.prank(admin);
        uint256 newTypeId = registry.registerCredentialType(
            "Master of Blockchain Engineering",
            "Graduate degree specializing in blockchain technology"
        );

        // 2. Admin authorizes MIT as issuer for this type
        vm.prank(admin);
        registry.authorizeIssuer(newTypeId, mit);

        // 3. MIT issues credential to Alice
        vm.prank(mit);
        uint256 tokenId = registry.issueCredential(
            alice, newTypeId, "ipfs://QmMasterBlockchain_Alice"
        );

        // 4. Anyone can verify Alice has the credential
        (bool hasCredential, uint256 verifiedTokenId) =
            registry.verifyCredential(alice, newTypeId);
        assertTrue(hasCredential);
        assertEq(verifiedTokenId, tokenId);

        // 5. SBT cannot be transferred
        vm.prank(alice);
        vm.expectRevert(SoulboundToken.TransferBlocked.selector);
        sbt.transferFrom(alice, bob, tokenId);

        // 6. Bob does not have the credential
        (bool bobHas,) = registry.verifyCredential(bob, newTypeId);
        assertFalse(bobHas);

        // 7. MIT revokes Alice's credential
        vm.prank(mit);
        registry.revokeCredential(tokenId);

        // 8. Credential is no longer valid
        (bool stillHas,) = registry.verifyCredential(alice, newTypeId);
        assertFalse(stillHas);

        // 9. Admin revokes MIT's issuer authorization
        vm.prank(admin);
        registry.revokeIssuer(newTypeId, mit);

        // 10. MIT can no longer issue this credential type
        vm.prank(mit);
        vm.expectRevert(CredentialRegistry.NotAuthorizedIssuer.selector);
        registry.issueCredential(alice, newTypeId, "ipfs://QmMasterBlockchain_Alice_v2");
    }
}
