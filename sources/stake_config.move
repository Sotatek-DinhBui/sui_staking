module sui_staking::staking_config;

const REWARD_RATE_PRECISION: u64 = 1_000_000_000;
const REWARD_INTERVAL: u64 = 1000*3600*24*30; // 30 days

public struct StakeConfig<phantom StakingWtns: drop> has store {
    reward_rate: u64, // rate for REWARD_INTERVAL
}

public fun new<StakingWtns: drop>(_: StakingWtns, reward_rate: u64): StakeConfig<StakingWtns> {
    StakeConfig {
        reward_rate,
    }
}

public fun get_reward_rate<StakingWtns: drop>(config: &StakeConfig<StakingWtns>): u64 {
    config.reward_rate
}

public fun get_reward_rate_precision(): u64 {
    return REWARD_RATE_PRECISION
}

public fun get_reward_interval(): u64 {
    return REWARD_INTERVAL
}
