// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface IHorizonStaking {
  /**
   * @notice Gets the details of a provision.
   * @param serviceProvider The address of the service provider.
   * @param verifier The address of the verifier.
   * @return The provision details.
   */
  function getProvision(address serviceProvider, address verifier) external view returns (Provision memory);

  /**
   * @notice Deposit tokens on the staking contract.
   * @dev Pulls tokens from the caller.
   *
   * Requirements:
   * - `_tokens` cannot be zero.
   * - Caller must have previously approved this contract to pull tokens from their balance.
   *
   * Emits a {StakeDeposited} event.
   *
   * @param tokens Amount of tokens to stake
   */
  function stake(uint256 tokens) external;

  /**
   * @notice Provision stake to a verifier. The tokens will be locked with a thawing period
   * and will be slashable by the verifier. This is the main mechanism to provision stake to a data
   * service, where the data service is the verifier.
   * This function can be called by the service provider or by an operator authorized by the provider
   * for this specific verifier.
   * @dev Requirements:
   * - `tokens` cannot be zero and must be over the data service minimum required.
   * - Provision parameters must be within the range allowed by the verifier (`maxVerifierCut` and `thawingPeriod`)
   * - The `serviceProvider` must have enough idle stake to cover the tokens to provision.
   *
   * Emits a {ProvisionCreated} event.
   *
   * @param serviceProvider The service provider address
   * @param verifier The verifier address for which the tokens are provisioned (who will be able to slash the tokens)
   * @param tokens The amount of tokens that will be locked and slashable
   * @param maxVerifierCut The maximum cut, expressed in PPM, that a verifier can transfer instead of burning when slashing
   * @param thawingPeriod The period in seconds that the tokens will be thawing before they can be removed from the provision
   */
  function provision(
    address serviceProvider,
    address verifier,
    uint256 tokens,
    uint32 maxVerifierCut,
    uint64 thawingPeriod
  ) external;

  /**
   * @notice Adds tokens from the service provider's idle stake to a provision
   * @dev
   *
   * Requirements:
   * - The `serviceProvider` must have previously provisioned stake to `verifier`.
   * - `tokens` cannot be zero.
   * - The `serviceProvider` must have enough idle stake to cover the tokens to add.
   *
   * Emits a {ProvisionIncreased} event.
   *
   * @param serviceProvider The service provider address
   * @param verifier The verifier address
   * @param tokens The amount of tokens to add to the provision
   */
  function addToProvision(address serviceProvider, address verifier, uint256 tokens) external;

  struct Provision {
    // Service provider tokens in the provision (does not include delegated tokens)
    uint256 tokens;
    // Service provider tokens that are being thawed (and will stop being slashable soon)
    uint256 tokensThawing;
    // Shares representing the thawing tokens
    uint256 sharesThawing;
    // Max amount that can be taken by the verifier when slashing, expressed in parts-per-million of the amount slashed
    uint32 maxVerifierCut;
    // Time, in seconds, tokens must thaw before being withdrawn
    uint64 thawingPeriod;
    // Timestamp when the provision was created
    uint64 createdAt;
    // Pending value for `maxVerifierCut`. Verifier needs to accept it before it becomes active.
    uint32 maxVerifierCutPending;
    // Pending value for `thawingPeriod`. Verifier needs to accept it before it becomes active.
    uint64 thawingPeriodPending;
  }

  /**
   * @notice Start thawing tokens to remove them from a provision.
   * This function can be called by the service provider or by an operator authorized by the provider
   * for this specific verifier.
   *
   * Note that removing tokens from a provision is a two step process:
   * - First the tokens are thawed using this function.
   * - Then after the thawing period, the tokens are removed from the provision using {deprovision}
   *   or {reprovision}.
   *
   * @dev Requirements:
   * - The provision must have enough tokens available to thaw.
   * - `tokens` cannot be zero.
   *
   * Emits {ProvisionThawed} and {ThawRequestCreated} events.
   *
   * @param serviceProvider The service provider address
   * @param verifier The verifier address for which the tokens are provisioned
   * @param tokens The amount of tokens to thaw
   * @return The ID of the thaw request
   */
  function thaw(address serviceProvider, address verifier, uint256 tokens) external returns (bytes32);

  /**
   * @notice Slash a service provider. This can only be called by a verifier to which
   * the provider has provisioned stake, and up to the amount of tokens they have provisioned.
   * If the service provider's stake is not enough, the associated delegation pool might be slashed
   * depending on the value of the global delegation slashing flag.
   *
   * Part of the slashed tokens are sent to the `verifierDestination` as a reward.
   *
   * @dev Requirements:
   * - `tokens` must be less than or equal to the amount of tokens provisioned by the service provider.
   * - `tokensVerifier` must be less than the provision's tokens times the provision's maximum verifier cut.
   *
   * Emits a {ProvisionSlashed} and {VerifierTokensSent} events.
   * Emits a {DelegationSlashed} or {DelegationSlashingSkipped} event depending on the global delegation slashing
   * flag.
   *
   * @param serviceProvider The service provider to slash
   * @param tokens The amount of tokens to slash
   * @param tokensVerifier The amount of tokens to transfer instead of burning
   * @param verifierDestination The address to transfer the verifier cut to
   */
  function slash(address serviceProvider, uint256 tokens, uint256 tokensVerifier, address verifierDestination) external;
}
