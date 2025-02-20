module sui_staking::sui_staking;

use sui::balance::{Self as balance_mod, Balance};
use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;
use sui::package;
use sui::sui::SUI;
use sui_staking::staking_config::{Self, StakeConfig};
use sui_staking::user_stake::{Self as user_stake_mod, UserStake};

use fun sui::dynamic_field::add as UID.add;
use fun sui::dynamic_field::borrow as UID.borrow;
use fun sui::dynamic_field::borrow_mut as UID.borrow_mut;

public struct SUI_STAKING has drop {}

public struct StakingWtns has drop {}

public struct Staking<phantom StakedToken> has key {
    id: UID,
    balance: Balance<StakedToken>,
}

public struct AdminCap has key, store {
    id: UID,
}

public struct ConfigKey<phantom Config> has copy, drop, store {}

// events
public struct UserStaked has copy, drop {
    user: address,
    amount: u64,
    start_timestamp: u64,
    reward_rate: u64,
    created_stake: address,
}

public struct UserUnstaked has copy, drop {
    user: address,
    used_stake: address,
    amount: u64,
    end_timestamp: u64,
    reward: u64,
}

public struct AdminWithdrawn has copy, drop {
    amount: u64,
}

public struct AdminDeposited has copy, drop {
    amount: u64,
}

public struct RewardRateUpdated has copy, drop {
    old_rate: u64,
    new_rate: u64,
}

// init
fun init(otw: SUI_STAKING, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);

    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());

    let mut staking: Staking<SUI> = Staking {
        id: object::new(ctx),
        balance: balance_mod::zero(),
    };

    let config = staking_config::new(StakingWtns {}, 50_000_000);
    staking.id.add(ConfigKey<StakeConfig<StakingWtns>> {}, config);

    transfer::share_object(staking);
}

// functions
public fun stake<StakedToken>(
    staking: &mut Staking<StakedToken>,
    amount: Coin<StakedToken>,
    clock: &Clock,
    ctx: &mut TxContext,
): UserStake<StakingWtns> {
    let config: &StakeConfig<StakingWtns> = get_config(staking);

    let user_stake: UserStake<StakingWtns> = user_stake_mod::mint_stake(
        StakingWtns {},
        config.get_reward_rate(),
        amount.value(),
        clock,
        ctx,
    );

    event::emit(UserStaked {
        user: ctx.sender(),
        amount: amount.value(),
        start_timestamp: clock.timestamp_ms(),
        reward_rate: config.get_reward_rate(),
        created_stake: user_stake.get_stake_id(),
    });

    staking.balance.join(amount.into_balance());

    user_stake
}

public fun unstake<StakedToken>(
    staking: &mut Staking<StakedToken>,
    user_stake: UserStake<StakingWtns>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<StakedToken> {
    let reward = user_stake_mod::calculate_reward(&user_stake, clock.timestamp_ms());

    event::emit(UserUnstaked {
        user: ctx.sender(),
        used_stake: user_stake.get_stake_id(),
        amount: user_stake.get_stake_amount(),
        end_timestamp: clock.timestamp_ms(),
        reward,
    });

    let reward = staking.balance.split(reward).into_coin(ctx);

    user_stake_mod::burn_stake(StakingWtns {}, user_stake);

    reward
}

public fun withdraw<StakedToken>(
    _: &AdminCap,
    staking: &mut Staking<StakedToken>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<StakedToken> {
    event::emit(AdminWithdrawn { amount });

    let withdrawn_token = staking.balance.split(amount).into_coin(ctx);

    withdrawn_token
}

public fun deposit<StakedToken>(
    _: &AdminCap,
    staking: &mut Staking<StakedToken>,
    amount: Coin<StakedToken>,
) {
    event::emit(AdminDeposited { amount: amount.value() });

    staking.balance.join(amount.into_balance());
}

public fun update_reward_rate<StakedToken>(
    _: &AdminCap,
    self: &mut Staking<StakedToken>,
    new_rate: u64,
) {
    let config: &mut StakeConfig<StakingWtns> = self
        .id
        .borrow_mut(ConfigKey<StakeConfig<StakingWtns>> {});

    let cur_rate = config.get_reward_rate();

    staking_config::update_reward_rate(StakingWtns {}, config, new_rate);

    event::emit(RewardRateUpdated { old_rate: cur_rate, new_rate });
}

public fun get_config<Config: store, StakedToken>(self: &Staking<StakedToken>): &Config {
    self.id.borrow(ConfigKey<Config> {})
}
