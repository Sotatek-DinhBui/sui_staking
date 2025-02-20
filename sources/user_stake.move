module sui_staking::user_stake;

use sui::clock::Clock;
use sui_staking::staking_config;

public struct UserStake<phantom StakingWtns: drop> has key, store {
    id: UID,
    amount: u64,
    start_timestamp: u64,
    reward_rate: u64,
}

public fun mint_stake<StakingWtns: drop>(
    _: StakingWtns,
    reward_rate: u64,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): UserStake<StakingWtns> {
    let user_stake: UserStake<StakingWtns> = UserStake {
        id: object::new(ctx),
        amount,
        start_timestamp: clock.timestamp_ms(),
        reward_rate,
    };

    user_stake
}

public fun burn_stake<StakingWtns: drop>(_: StakingWtns, stake: UserStake<StakingWtns>) {
    let UserStake<StakingWtns> { id, .. } = stake;
    id.delete();
}

public fun calculate_reward<StakingWtns: drop>(stake: &UserStake<StakingWtns>, now: u64): u64 {
    let time_elapsed = now - stake.start_timestamp;

    let reward =
        stake.amount * time_elapsed * stake.reward_rate / (staking_config::get_reward_interval() * staking_config::get_reward_rate_precision());

    reward
}

public fun get_stake_id<StakingWtns: drop>(stake: &UserStake<StakingWtns>): address {
    stake.id.to_address()
}

public fun get_stake_amount<StakingWtns: drop>(stake: &UserStake<StakingWtns>): u64 {
    stake.amount
}
