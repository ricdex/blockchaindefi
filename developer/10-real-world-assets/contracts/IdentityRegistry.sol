// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IdentityRegistry
 * @notice Manages a whitelist of verified investors for RWA token compliance.
 *         Each investor is associated with a country code, enabling
 *         jurisdiction-based transfer restrictions.
 */
contract IdentityRegistry {
    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error NotAdmin();
    error NotComplianceOfficer();
    error ZeroAddress();
    error InvestorAlreadyRegistered(address investor);
    error InvestorNotRegistered(address investor);
    error CountryAlreadyRestricted(uint16 countryCode);
    error CountryNotRestricted(uint16 countryCode);
    error InvalidCountryCode();

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event InvestorAdded(address indexed investor, uint16 indexed countryCode);
    event InvestorRemoved(address indexed investor);
    event CountryRestricted(uint16 indexed countryCode);
    event CountryUnrestricted(uint16 indexed countryCode);
    event ComplianceOfficerUpdated(address indexed officer, bool status);

    // -----------------------------------------------------------------------
    // Structs
    // -----------------------------------------------------------------------

    struct InvestorInfo {
        bool isVerified;
        uint16 countryCode; // ISO 3166-1 numeric code (e.g., 840 = US, 276 = DE)
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice The admin who can manage compliance officers.
    address public admin;

    /// @notice Addresses authorized to manage the investor whitelist.
    mapping(address => bool) public complianceOfficers;

    /// @notice Investor address to identity information.
    mapping(address => InvestorInfo) public investors;

    /// @notice Country codes that are restricted (blocked from participation).
    mapping(uint16 => bool) public restrictedCountries;

    /// @notice Count of registered investors per country.
    mapping(uint16 => uint256) public investorCountByCountry;

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyComplianceOfficer() {
        if (!complianceOfficers[msg.sender]) revert NotComplianceOfficer();
        _;
    }

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    constructor() {
        admin = msg.sender;
        complianceOfficers[msg.sender] = true;
    }

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Grant or revoke compliance officer status.
     * @param officer The address to update.
     * @param status  True to grant, false to revoke.
     */
    function setComplianceOfficer(address officer, bool status) external onlyAdmin {
        if (officer == address(0)) revert ZeroAddress();
        complianceOfficers[officer] = status;
        emit ComplianceOfficerUpdated(officer, status);
    }

    // -----------------------------------------------------------------------
    // Compliance Officer Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Register a verified investor with their country code.
     * @param investor    The investor address to whitelist.
     * @param countryCode The ISO 3166-1 numeric country code.
     */
    function addInvestor(address investor, uint16 countryCode) external onlyComplianceOfficer {
        if (investor == address(0)) revert ZeroAddress();
        if (investors[investor].isVerified) revert InvestorAlreadyRegistered(investor);
        if (countryCode == 0) revert InvalidCountryCode();

        investors[investor] = InvestorInfo({
            isVerified: true,
            countryCode: countryCode
        });

        investorCountByCountry[countryCode]++;

        emit InvestorAdded(investor, countryCode);
    }

    /**
     * @notice Remove an investor from the whitelist.
     * @param investor The investor address to remove.
     */
    function removeInvestor(address investor) external onlyComplianceOfficer {
        if (!investors[investor].isVerified) revert InvestorNotRegistered(investor);

        uint16 countryCode = investors[investor].countryCode;
        investorCountByCountry[countryCode]--;

        delete investors[investor];

        emit InvestorRemoved(investor);
    }

    /**
     * @notice Restrict a country from participating in token transfers.
     * @param countryCode The ISO 3166-1 numeric country code to restrict.
     */
    function restrictCountry(uint16 countryCode) external onlyComplianceOfficer {
        if (countryCode == 0) revert InvalidCountryCode();
        if (restrictedCountries[countryCode]) revert CountryAlreadyRestricted(countryCode);

        restrictedCountries[countryCode] = true;
        emit CountryRestricted(countryCode);
    }

    /**
     * @notice Remove a country restriction.
     * @param countryCode The ISO 3166-1 numeric country code to unrestrict.
     */
    function unrestrictCountry(uint16 countryCode) external onlyComplianceOfficer {
        if (!restrictedCountries[countryCode]) revert CountryNotRestricted(countryCode);

        restrictedCountries[countryCode] = false;
        emit CountryUnrestricted(countryCode);
    }

    // -----------------------------------------------------------------------
    // View Functions
    // -----------------------------------------------------------------------

    /**
     * @notice Check if an address is a verified investor.
     * @param investor The address to check.
     * @return True if the address is a verified investor.
     */
    function isVerifiedInvestor(address investor) external view returns (bool) {
        return investors[investor].isVerified;
    }

    /**
     * @notice Get the country code of a verified investor.
     * @param investor The address to query.
     * @return The ISO 3166-1 numeric country code.
     */
    function getCountryCode(address investor) external view returns (uint16) {
        return investors[investor].countryCode;
    }

    /**
     * @notice Check if a country is restricted.
     * @param countryCode The ISO 3166-1 numeric country code.
     * @return True if the country is restricted.
     */
    function isCountryRestricted(uint16 countryCode) external view returns (bool) {
        return restrictedCountries[countryCode];
    }

    /**
     * @notice Determine if a transfer between two addresses is compliant.
     * @param from The sender address.
     * @param to   The receiver address.
     * @return True if the transfer passes all compliance checks.
     */
    function isTransferCompliant(address from, address to) external view returns (bool) {
        // Both must be verified
        if (!investors[from].isVerified) return false;
        if (!investors[to].isVerified) return false;

        // Neither country can be restricted
        if (restrictedCountries[investors[from].countryCode]) return false;
        if (restrictedCountries[investors[to].countryCode]) return false;

        return true;
    }
}
